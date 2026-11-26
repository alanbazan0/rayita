# Despliegue de Rayita en HostGator (sin SSH)

Sigue el mismo esquema que Noxa: GitHub Actions sube un `api.zip` por FTP y un archivo
`deploy.php` (ver `deploy/extract.php`) lo descomprime y corre artisan por HTTPS, protegido por
un token. No se ejecuta ningún comando de shell en el servidor.

## Estructura en el servidor

Rutas relativas al inicio del FTP, que es `/public_html/projects/`:

| Carpeta | Subdominio | Contenido |
| --- | --- | --- |
| `rayita_app/` | `rayita.alanbazan.com.mx` | Web de pruebas de Flutter + `deploy.php` |
| `rayita_api/` | `api.rayita.alanbazan.com.mx` | API Laravel. Document Root: `rayita_api/public` |
| `rayita_deploy/` | — | `api.zip` de paso; se borra al extraer |

La web se publica solo para pruebas: lleva `noindex` (meta, `robots.txt` y cabecera
`X-Robots-Tag`), pero **no es privada**, así que el registro se protege con un código de invitación.

## Secretos de GitHub

Solo son secretos las credenciales. Las URL, las carpetas (`rayita_app/`, `rayita_deploy/`) y el
puerto FTP (21) no lo son y están escritos en los workflows (`env:` al inicio de cada archivo).

| Secreto | Valor |
| --- | --- |
| `FTP_SERVER` | Hostname real del servidor FTP (no el dominio), tipo `gator1234.hostgator.com` |
| `FTP_USER` / `FTP_PASS` | Cuenta FTP con acceso a `/public_html/projects` |
| `DEPLOY_TOKEN` | Cadena aleatoria larga (`openssl rand -hex 32`); protege `deploy.php` |
| `APP_KEY` | `cd backend && php artisan key:generate --show` |
| `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` | Base MySQL creada en cPanel (HostGator antepone el usuario de cPanel) |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD` | **Opcionales.** Solo si usas SMTP. Sin `MAIL_HOST`, el correo sale por el `sendmail` del servidor |
| `INVITE_CODE` | **Ya no es un secreto**: está en el `env:` de `deploy-api.yml` y hoy va vacío (registro abierto) |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_B64` | **Opcional hasta vender "Quitar anuncios".** El JSON de la cuenta de servicio de Google Cloud, en base64 de una sola línea: `base64 -i cuenta.json \| tr -d '\n'`. Ver abajo |

Se pueden crear a mano en *Settings → Secrets and variables → Actions*, o cargar todos de una
vez desde `.env.deploy` con `deploy/set-github-secrets.sh`.

## Compra de "Quitar anuncios" (validación en el servidor)

La app manda el token de la compra a `POST /api/purchases/verify` y el servidor lo valida con la API
de Google Play Developer. Solo entonces la cuenta queda con `ads_removed: true`. Hace falta una
cuenta de servicio, creada una sola vez:

1. **Google Cloud** (proyecto `rayita-515805`): habilita la *Google Play Android Developer API*,
   crea una cuenta de servicio (sin roles de proyecto) y descarga su llave en JSON.
2. **Play Console → Usuarios y permisos → Invitar usuarios**: invita el correo de esa cuenta de
   servicio con el permiso *Ver información financiera, pedidos y respuestas de encuestas de
   cancelación* y *Administrar pedidos y suscripciones*, para la app Rayita. Puede tardar un rato
   en aplicarse (hasta unas horas).
3. Codifica el JSON y guárdalo como secreto `GOOGLE_PLAY_SERVICE_ACCOUNT_B64` (sin pegarlo en ningún chat):
   `base64 -i cuenta.json | tr -d '\n' | pbcopy`
4. Vuelve a desplegar la API (el workflow escribe el valor en el `.env` del servidor).
5. Crea el producto **`remove_ads`** (no consumible, 49 MXN) en Play Console → *Monetizar con Play*
   → *Productos* → *Productos integrados*. Necesita que la app esté subida a una pista.

Sin el secreto, el endpoint responde 503 ("No se pudo validar la compra ahora") y nadie queda sin
anuncios: es el comportamiento seguro. Para probar compras reales sin cobrarte, agrega tu correo en
Play Console → *Configuración → Pruebas de licencia*.

## Correo de los códigos de verificación

Por defecto se envía con el `sendmail` del servidor desde `support@alanbazan.com.mx`
(`MAIL_FROM_ADDRESS`, en el `env:` de `deploy-api.yml`). No necesita contraseña. Para que los
mensajes no caigan en spam, en cPanel → **Email Deliverability** deja el dominio con SPF y DKIM
válidos. Si luego creas una cuenta propia, carga los secretos `MAIL_HOST`, `MAIL_PORT`,
`MAIL_USERNAME` y `MAIL_PASSWORD` y el despliegue cambia solo a SMTP.

## Primer despliegue

1. En cPanel: crea la base MySQL, su usuario (con todos los privilegios) y la cuenta de correo
   `no-reply@…`. Confirma que `api.rayita…` tenga SSL (AutoSSL).
2. `cp .env.deploy.example .env.deploy` y llénalo (ese archivo nunca se sube al repo).
3. Cargar los secretos (a mano en GitHub o con `deploy/set-github-secrets.sh`).
4. Ejecuta primero **Deploy Web** (sube `deploy.php`) y luego **Deploy API**, desde la pestaña
   Actions (*Run workflow*). Después, cada push a `main` despliega lo que cambió.
5. Comprueba `https://api.rayita.alanbazan.com.mx/api/config`: debe responder 200.

## Qué hace cada flujo

- **Deploy API**: pruebas del backend → `composer install --no-dev` → `api.zip` (código + vendor,
  un solo archivo) → FTP a `rayita_deploy/` → `deploy.php` extrae → sube el `.env` de producción
  **por HTTPS** (no por FTP) → `migrate` → cachés de config/rutas/vistas **en el servidor** → `diag`.
- **Deploy Web**: `flutter analyze` y `flutter test` → `flutter build web --pwa-strategy=none` con la
  URL de la API → agrega `deploy.php` con el token → FTP a `rayita_app/`.
- **Operación del servidor** (Actions → *Run workflow*): `diag`, `migrate-status`, `migrate`,
  `optimize`, `logs` y `set-invite-code` (cambiar el código sin redesplegar).

## Despliegue manual

`./deploy.sh [all|api|web]` hace lo mismo desde tu máquina (requiere php 8.3, composer, zip,
lftp, curl y flutter) usando `.env.deploy`.

## Reglas que salieron de Noxa

- Un solo paso de FTP por destino: dos pasos sobre la misma carpeta se borran entre sí.
- FTP plano (`ftp`); `ftps` falla por TLS con HostGator.
- El `.htaccess` de la web no lleva reglas de `/api` (causó un 500). Sí lleva cabeceras *no-store*.
- No generar cachés de config en el CI: guardan rutas absolutas del runner. Se hacen en el servidor.
- Contraseñas con comilla simple (`'`) no son compatibles con el `.env` generado.

## Si algo falla

Actions → **Operación del servidor** → `logs` muestra el final de `storage/logs`, y `diag`
prueba que la API responde. Si ves `forbidden`, el token del secreto no coincide con el que
subió el último despliegue web.
