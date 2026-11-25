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
 *   action=optimize    limpia y regenera la caché de config y rutas
 *   action=migrate     php artisan migrate --force
 *   action=migrate-status
 *   action=logs        últimas N líneas de storage/logs (?lines=200)
 *   action=diag        pide GET /api/config al kernel y muestra el resultado
 *   action=set-env     POST name=INVITE_CODE|GOOGLE_CLIENT_ID|GOOGLE_IOS_CLIENT_ID&value=...
 *   action=mail-test   ?to=correo@dominio.com envía un correo de prueba con el mailer de producción
 *   action=stats       cifras agregadas de uso (usuarios, hábitos, marcas); sin datos personales
 */

$token = '__DEPLOY_TOKEN__';

// Rutas; se pueden sobrescribir por variable de entorno (útil para probar en local).
$apiDir = getenv('RAYITA_API_DIR') ?: __DIR__ . '/../rayita_api';
$zipPath = getenv('RAYITA_ZIP') ?: __DIR__ . '/../rayita_deploy/api.zip';

ob_start(); // si algo falla tras imprimir, aún se puede responder con código 500
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
const ALLOWED_ENV = ['INVITE_CODE', 'GOOGLE_CLIENT_ID', 'GOOGLE_IOS_CLIENT_ID'];

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
            // Sin view:cache: la API no tiene vistas Blade (el correo usa HTML en línea).
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
            if (!preg_match('/^[A-Za-z0-9._\-]{0,128}$/', $value)) {
                fail(422, 'valor inválido (solo letras, números, . _ -; máx. 128)');
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

        case 'mail-test':
            $to = (string) ($_GET['to'] ?? '');
            if (!filter_var($to, FILTER_VALIDATE_EMAIL)) {
                fail(422, 'indica ?to= con un correo válido');
            }
            artisanKernel($apiDir)->bootstrap();
            echo 'mailer: ' . config('mail.default') . "\n";
            echo 'remitente: ' . config('mail.from.address') . "\n";
            \Illuminate\Support\Facades\Mail::raw(
                "Correo de prueba de Rayita.\nSi lo ves, el servidor puede enviar mensajes.",
                fn ($message) => $message->to($to)->subject('Prueba de correo de Rayita')
            );
            echo "enviado al mailer sin errores a $to (revisa también spam)\n";
            break;

        case 'stats':
            artisanKernel($apiDir)->bootstrap();
            $db = fn (string $table) => \Illuminate\Support\Facades\DB::table($table);
            $since = fn (int $days) => now()->subDays($days);
            $activeUsers = fn (int $days) => $db('habit_logs')
                ->join('habits', 'habits.id', '=', 'habit_logs.habit_id')
                ->where('habit_logs.created_at', '>=', $since($days))
                ->distinct()->count('habits.user_id');

            echo "== Usuarios ==\n";
            echo 'total:                 ' . $db('users')->count() . "\n";
            echo 'con correo verificado: ' . $db('users')->whereNotNull('email_verified_at')->count() . "\n";
            echo 'entran con Google:     ' . $db('users')->whereNotNull('google_id')->count() . "\n";
            echo 'nuevos hoy:            ' . $db('users')->where('created_at', '>=', now()->startOfDay())->count() . "\n";
            echo 'nuevos últimos 7 días: ' . $db('users')->where('created_at', '>=', $since(7))->count() . "\n";
            echo 'nuevos últimos 30 días:' . ' ' . $db('users')->where('created_at', '>=', $since(30))->count() . "\n";
            echo "\n== Actividad (usuarios que marcaron algún día) ==\n";
            echo 'últimas 24 horas:      ' . $activeUsers(1) . "\n";
            echo 'últimos 7 días:        ' . $activeUsers(7) . "\n";
            echo 'últimos 30 días:       ' . $activeUsers(30) . "\n";
            echo "\n== Contenido ==\n";
            echo 'hábitos creados:       ' . $db('habits')->count() . "\n";
            echo 'marcas registradas:    ' . $db('habit_logs')->count() . "\n";
            echo "\n== Registros por día (últimos 14 días, UTC) ==\n";
            $perDay = $db('users')->selectRaw('DATE(created_at) as d, COUNT(*) as n')
                ->where('created_at', '>=', $since(14))->groupBy('d')->orderBy('d')->get();
            foreach ($perDay as $row) {
                echo $row->d . '  ' . str_repeat('#', min(40, (int) $row->n)) . ' ' . $row->n . "\n";
            }
            if ($perDay->isEmpty()) {
                echo "(sin registros nuevos)\n";
            }
            break;

        default:
            fail(400, 'acción desconocida');
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo get_class($e) . ': ' . $e->getMessage() . "\n" . $e->getFile() . ':' . $e->getLine();
}
