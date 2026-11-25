<?php
/*
 * Extractor de despliegue de Rayita (HostGator compartido, sin SSH).
 *
 * El CI lo sube junto con la web como `rayita_app/deploy.php`, reemplazando el
 * marcador __DEPLOY_TOKEN__ por el secreto DEPLOY_TOKEN. No ejecuta comandos de
 * shell: solo descomprime el zip de la API y llama a artisan por el kernel de Laravel.
 *
 * Estructura en el servidor (relativa a /public_html/projects/):
 *   rayita_app/      web de Flutter + este archivo (deploy.php)
 *   rayita_api/      API Laravel (su Document Root es rayita_api/public)
 *   rayita_deploy/   api.zip subido por FTP (se borra al extraer)
 *
 * Todas las acciones exigen el token, de preferencia en el encabezado
 * `X-Deploy-Token` (también se acepta `?token=`).
 *
 *   (sin action)       extrae rayita_deploy/api.zip en rayita_api/ y lo borra
 *   action=write-env   POST con el contenido completo del .env de producción
 *   action=optimize    limpia y regenera la caché de config, rutas y vistas
 *   action=migrate     php artisan migrate --force
 *   action=migrate-status
 *   action=logs        últimas N líneas de storage/logs (?lines=200)
 *   action=diag        pide GET /api/config al kernel y muestra el resultado
 *   action=set-env     POST name=INVITE_CODE&value=... (solo variables permitidas)
 */

$token = '__DEPLOY_TOKEN__';

// Rutas; se pueden sobrescribir por variable de entorno (útil para probar en local).
$apiDir = getenv('RAYITA_API_DIR') ?: __DIR__ . '/../rayita_api';
$zipPath = getenv('RAYITA_ZIP') ?: __DIR__ . '/../rayita_deploy/api.zip';

header('Content-Type: text/plain; charset=utf-8');
header('X-Robots-Tag: noindex, nofollow');
set_time_limit(180);

$sent = (string) ($_SERVER['HTTP_X_DEPLOY_TOKEN'] ?? $_GET['token'] ?? '');
if (strlen($token) < 16 || str_starts_with($token, '__') || !hash_equals($token, $sent)) {
    http_response_code(403);
    exit('forbidden');
}

$action = (string) ($_GET['action'] ?? '');
$isPost = ($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST';

/** Variables de .env que set-env puede cambiar (nunca claves ni credenciales). */
const ALLOWED_ENV = ['INVITE_CODE'];

function fail(int $code, string $message): never
{
    http_response_code($code);
    exit($message);
}

/** Crea las carpetas que Laravel necesita escribir y que el zip no incluye. */
function ensureWritableDirs(string $apiDir): void
{
    foreach ([
        'storage/logs',
        'storage/framework/cache/data',
        'storage/framework/sessions',
        'storage/framework/views',
        'storage/app/public',
        'bootstrap/cache',
    ] as $dir) {
        $path = $apiDir . '/' . $dir;
        if (!is_dir($path) && !mkdir($path, 0775, true) && !is_dir($path)) {
            fail(500, 'no se pudo crear ' . $dir);
        }
    }
}

/** Arranca Laravel y devuelve el kernel de consola. */
function artisanKernel(string $apiDir): Illuminate\Contracts\Console\Kernel
{
    require_once $apiDir . '/vendor/autoload.php';
    $app = require $apiDir . '/bootstrap/app.php';

    return $app->make(Illuminate\Contracts\Console\Kernel::class);
}

/** Ejecuta un comando artisan e imprime su salida. */
function runArtisan(Illuminate\Contracts\Console\Kernel $kernel, string $command, array $args = []): int
{
    $status = $kernel->call($command, $args);
    echo "$ php artisan $command (exit $status)\n" . trim($kernel->output()) . "\n\n";

    return $status;
}

try {
    switch ($action) {
        case '':
            if (!class_exists('ZipArchive')) {
                fail(500, 'falta la extensión zip');
            }
            if (!is_file($zipPath)) {
                fail(404, 'api.zip no encontrado');
            }
            $zip = new ZipArchive();
            if ($zip->open($zipPath) !== true) {
                fail(500, 'no se pudo abrir el zip');
            }
            if (!is_dir($apiDir) && !mkdir($apiDir, 0775, true)) {
                fail(500, 'no se pudo crear ' . basename($apiDir));
            }
            $zip->extractTo($apiDir);
            $zip->close();
            unlink($zipPath);
            ensureWritableDirs($apiDir);
            echo 'ok';
            break;

        case 'write-env':
            if (!$isPost) {
                fail(405, 'usa POST con el contenido del .env en el cuerpo');
            }
            $body = (string) file_get_contents('php://input');
            if ($body === '' || strlen($body) > 20000) {
                fail(422, 'cuerpo vacío o demasiado grande');
            }
            if (!preg_match('/^APP_KEY=base64:.{20,}$/m', $body)) {
                fail(422, 'el .env debe incluir APP_KEY=base64:...');
            }
            if (!is_dir($apiDir)) {
                fail(404, 'la carpeta de la API aún no existe');
            }
            $tmp = $apiDir . '/.env.tmp';
            if (file_put_contents($tmp, rtrim($body) . "\n") === false) {
                fail(500, 'no se pudo escribir el .env');
            }
            chmod($tmp, 0600);
            rename($tmp, $apiDir . '/.env');
            echo 'ok: .env actualizado';
            break;

        case 'optimize':
            $kernel = artisanKernel($apiDir);
            runArtisan($kernel, 'optimize:clear');
            runArtisan($kernel, 'config:cache');
            runArtisan($kernel, 'route:cache');
            runArtisan($kernel, 'view:cache');
            break;

        case 'migrate':
            runArtisan(artisanKernel($apiDir), 'migrate', ['--force' => true]);
            break;

        case 'migrate-status':
            runArtisan(artisanKernel($apiDir), 'migrate:status');
            break;

        case 'logs':
            $logs = glob($apiDir . '/storage/logs/*.log') ?: [];
            if ($logs === []) {
                exit('sin logs todavía');
            }
            usort($logs, fn ($a, $b) => filemtime($b) <=> filemtime($a));
            $lines = max(1, min(1000, (int) ($_GET['lines'] ?? 200)));
            echo basename($logs[0]) . "\n";
            echo implode("\n", array_slice(file($logs[0], FILE_IGNORE_NEW_LINES) ?: [], -$lines));
            break;

        case 'diag':
            require_once $apiDir . '/vendor/autoload.php';
            $app = require $apiDir . '/bootstrap/app.php';
            $http = $app->make(Illuminate\Contracts\Http\Kernel::class);
            $response = $http->handle(Illuminate\Http\Request::create(
                '/api/config', 'GET', [], [], [], ['HTTP_ACCEPT' => 'application/json']
            ));
            echo $response->getStatusCode() . "\n" . substr((string) $response->getContent(), 0, 2000);
            break;

        case 'set-env':
            if (!$isPost) {
                fail(405, 'usa POST con name y value');
            }
            $name = (string) ($_POST['name'] ?? '');
            $value = (string) ($_POST['value'] ?? '');
            if (!in_array($name, ALLOWED_ENV, true)) {
                fail(422, 'variable no permitida: ' . $name);
            }
            if (!preg_match('/^[A-Za-z0-9._\-]{0,64}$/', $value)) {
                fail(422, 'valor inválido (solo letras, números, . _ -; máx. 64)');
            }
            $envPath = $apiDir . '/.env';
            if (!is_file($envPath)) {
                fail(404, '.env no encontrado');
            }
            $lines = file($envPath, FILE_IGNORE_NEW_LINES) ?: [];
            $found = false;
            foreach ($lines as $i => $line) {
                if (str_starts_with($line, $name . '=')) {
                    $lines[$i] = $name . '=' . $value;
                    $found = true;
                    break;
                }
            }
            if (!$found) {
                $lines[] = $name . '=' . $value;
            }
            file_put_contents($envPath, implode("\n", $lines) . "\n");
            echo "ok: $name actualizado\n";
            runArtisan(artisanKernel($apiDir), 'config:cache');
            break;

        default:
            fail(400, 'acción desconocida');
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo get_class($e) . ': ' . $e->getMessage() . "\n" . $e->getFile() . ':' . $e->getLine();
}
