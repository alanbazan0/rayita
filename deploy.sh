#!/bin/bash
# Despliegue manual de Rayita a HostGator (sin SSH). Hace lo mismo que los workflows
# de GitHub Actions (.github/workflows/deploy-*.yml).
#
# Uso:  ./deploy.sh [all|api|web]     (por defecto: all)
#
# Requiere: php 8.3, composer, zip, lftp, curl y (para la web) flutter.
set -e
cd "$(dirname "$0")"

# Variables desde .env.deploy (nunca hardcodear credenciales)
source .env.deploy

TARGET="${1:-all}"
STAGING="$(pwd)/staging"
TOKEN_HEADER="X-Deploy-Token: $MIGRATE_TOKEN"

: "${FTP_SERVER:?falta FTP_SERVER en .env.deploy}"
: "${FTP_USER:?falta FTP_USER}"
: "${FTP_PASS:?falta FTP_PASS}"
: "${APP_URL:?falta APP_URL}"
: "${MIGRATE_TOKEN:?falta MIGRATE_TOKEN}"
FTP_PORT="${FTP_PORT:-21}"
MAIL_FROM_ADDRESS="${MAIL_FROM_ADDRESS:-rayita@alanbazan.com.mx}"
APP_DIR="${APP_DIR:-rayita_app/}"
DEPLOY_DIR="${DEPLOY_DIR:-rayita_deploy/}"

# FTP plano (no ftps) para HostGator compartido.
ftp_run() {
  lftp -u "$FTP_USER,$FTP_PASS" -p "$FTP_PORT" "ftp://$FTP_SERVER" \
    -e "set ftp:ssl-allow no; set net:max-retries 3; set net:timeout 30; $1; bye"
}

call() {  # call <action> [curl args...]
  local action="$1"; shift
  curl -fsS -H "$TOKEN_HEADER" "$@" "$APP_URL/deploy.php${action:+?action=$action}"
  echo
}

deploy_web() {
  echo "==> Compilando la web de Flutter"
  (cd app && flutter pub get && flutter build web --release --pwa-strategy=none \
    --base-href / --dart-define=API_URL="$API_URL/api")
  # Se agrega deploy.php con el token (el marcador se reemplaza solo en la copia).
  sed "s|__DEPLOY_TOKEN__|$MIGRATE_TOKEN|" deploy/extract.php > app/build/web/deploy.php

  echo "==> Subiendo la web a $APP_DIR"
  ftp_run "mkdir -p $APP_DIR; mirror -R --delete --parallel=4 app/build/web/ $APP_DIR"
  rm -f app/build/web/deploy.php
}

deploy_api() {
  echo "==> 1. composer install --no-dev"
  (cd backend && composer install --no-dev --optimize-autoloader --no-interaction)

  echo "==> 2. Generando el .env de producción"
  scheme=smtp; [ "$MAIL_PORT" = "465" ] && scheme=smtps
  ENV_FILE="$(mktemp)"
  trap 'rm -f "$ENV_FILE"' EXIT
  {
    echo "APP_NAME=Rayita"
    echo "APP_ENV=production"
    echo "APP_KEY=$APP_KEY"
    echo "APP_DEBUG=false"
    echo "APP_URL=$API_URL"
    echo "APP_LOCALE=es"
    echo "APP_FALLBACK_LOCALE=en"
    echo "LOG_CHANNEL=single"
    echo "LOG_LEVEL=warning"
    echo "DB_CONNECTION=mysql"
    echo "DB_HOST=localhost"
    echo "DB_PORT=3306"
    printf "DB_DATABASE='%s'\n" "$DB_DATABASE"
    printf "DB_USERNAME='%s'\n" "$DB_USERNAME"
    printf "DB_PASSWORD='%s'\n" "$DB_PASSWORD"
    echo "SESSION_DRIVER=file"
    echo "CACHE_STORE=file"
    echo "QUEUE_CONNECTION=sync"
    if [ -n "$MAIL_HOST" ]; then
      echo "MAIL_MAILER=smtp"
      echo "MAIL_SCHEME=$scheme"
      printf "MAIL_HOST='%s'\n" "$MAIL_HOST"
      echo "MAIL_PORT=$MAIL_PORT"
      printf "MAIL_USERNAME='%s'\n" "$MAIL_USERNAME"
      printf "MAIL_PASSWORD='%s'\n" "$MAIL_PASSWORD"
    else
      # Sin SMTP configurado: se envía con el sendmail del propio servidor.
      echo "MAIL_MAILER=sendmail"
    fi
    printf "MAIL_FROM_ADDRESS='%s'\n" "$MAIL_FROM_ADDRESS"
    echo 'MAIL_FROM_NAME="Rayita"'
    printf "INVITE_CODE='%s'\n" "$INVITE_CODE"
  } > "$ENV_FILE"

  # Las cachés de config/rutas/vistas se generan EN el servidor (paso "optimize"):
  # si se generaran aquí guardarían rutas absolutas de esta máquina y romperían el sitio.

  echo "==> 3. Comprimiendo api.zip (código + vendor en un solo archivo)"
  rm -rf "$STAGING" && mkdir -p "$STAGING"
  (cd backend && zip -rq "$STAGING/api.zip" . \
    -x '.env' '.env.*' '.git*' 'tests/*' 'node_modules/*' 'database/*.sqlite' \
       'storage/logs/*' 'storage/framework/cache/data/*' \
       'storage/framework/sessions/*' 'storage/framework/views/*')

  echo "==> 4. Subiendo por FTP a $DEPLOY_DIR (sin tocar vendor/ archivo por archivo)"
  ftp_run "mkdir -p $DEPLOY_DIR; put -O $DEPLOY_DIR $STAGING/api.zip"

  echo "==> 5. Descomprimiendo en el servidor"
  out="$(call '')"; echo "$out"; [ "$out" = "ok" ]

  echo "==> 6. Subiendo el .env por HTTPS"
  call write-env -X POST --data-binary "@$ENV_FILE"

  echo "==> 7. Migraciones"
  call migrate

  echo "==> 8. Cachés de config, rutas y vistas"
  call optimize

  echo "==> 9. Verificando"
  out="$(call diag)"; echo "$out"; echo "$out" | head -1 | grep -qx 200
  rm -rf "$STAGING"
}

case "$TARGET" in
  web) deploy_web ;;
  api) deploy_api ;;
  all) deploy_web; deploy_api ;;   # la web primero: sube deploy.php, que la API necesita
  *)   echo "Uso: $0 [all|api|web]"; exit 1 ;;
esac
echo "Listo."
