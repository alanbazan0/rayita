#!/bin/bash
# Carga los secretos de GitHub Actions del repo a partir de .env.deploy (sin pasar
# contraseñas por ningún chat). Requiere la CLI `gh` con sesión iniciada.
#
# Uso:  deploy/set-github-secrets.sh [owner/repo]
set -e
cd "$(dirname "$0")/.."
source .env.deploy

REPO="${1:-alanbazan0/rayita}"

set_secret() {  # set_secret <NOMBRE_EN_GITHUB> <valor>
  if [ -z "$2" ]; then
    echo "  (omitido, vacío) $1"
    return
  fi
  printf '%s' "$2" | gh secret set "$1" --repo "$REPO"
}

echo "Cargando secretos en $REPO ..."
set_secret FTP_HOST        "$FTP_SERVER"
set_secret FTP_PORT        "${FTP_PORT:-21}"
set_secret FTP_USER        "$FTP_USER"
set_secret FTP_PASSWORD    "$FTP_PASS"
set_secret APP_DIR         "${APP_DIR:-rayita_app/}"
set_secret DEPLOY_DIR      "${DEPLOY_DIR:-rayita_deploy/}"
set_secret WEB_URL         "$APP_URL"
set_secret API_URL         "$API_URL"
set_secret API_BASE_URL    "$API_URL/api"
set_secret DEPLOY_TOKEN    "$MIGRATE_TOKEN"
set_secret APP_KEY         "$APP_KEY"
set_secret DB_DATABASE     "$DB_DATABASE"
set_secret DB_USERNAME     "$DB_USERNAME"
set_secret DB_PASSWORD     "$DB_PASSWORD"
set_secret MAIL_HOST       "$MAIL_HOST"
set_secret MAIL_PORT       "${MAIL_PORT:-465}"
set_secret MAIL_USERNAME   "$MAIL_USERNAME"
set_secret MAIL_PASSWORD   "$MAIL_PASSWORD"
set_secret MAIL_FROM_ADDRESS "$MAIL_FROM_ADDRESS"
set_secret INVITE_CODE     "$INVITE_CODE"
echo "Listo."
