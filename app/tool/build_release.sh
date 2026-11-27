#!/bin/bash
# Compila Rayita para Android en modo release, con el código Dart OFUSCADO y R8 activo.
#
# Uso:  tool/build_release.sh [apk|appbundle]      (por defecto: appbundle, el que pide Google Play)
#       API_URL=https://...  tool/build_release.sh apk
#       ADS=false tool/build_release.sh apk      (APK personal sin anuncios ni opción de compra)
#
# Anuncios reales de AdMob (los dos IDs son públicos, no son secretos):
#       ADMOB_APP_ID=ca-app-pub-XXXX~YYYY ADMOB_BANNER_ID=ca-app-pub-XXXX/ZZZZ tool/build_release.sh appbundle
# Sin ellos se usan los IDs de PRUEBA de Google y un .aab se niega a generarse, salvo que
# pongas ALLOW_TEST_ADS=1 (para una prueba interna en Play).
#
# Guarda los símbolos en build/symbols/<versión>/: sin ellos no se pueden leer los
# fallos de una versión ofuscada. Conserva esa carpeta (y el mapping.txt de R8) de
# cada versión que publiques; NO se suben al repositorio.
set -e
cd "$(dirname "$0")/.."

TARGET="${1:-appbundle}"

# Un .aab para Google Play debe ir firmado con la llave de subida, nunca con la de depuración.
if [ "$TARGET" = "appbundle" ] && [ ! -f android/key.properties ]; then
  echo "Falta android/key.properties (la llave de subida): no se genera un .aab firmado con la llave de depuración." >&2
  echo "Ver docs/RELEASE_ANDROID.md." >&2
  exit 1
fi
API_URL="${API_URL:-https://api.rayita.alanbazan.com.mx/api}"
ADS="${ADS:-true}"
# Un .aab para Google Play siempre lleva anuncios: es la versión pública.
if [ "$TARGET" = "appbundle" ] && [ "$ADS" != "true" ]; then
  echo "ADS=false es solo para un APK personal; el .aab de Play debe llevar anuncios." >&2
  exit 1
fi
# IDs de AdMob: o los dos reales o los de prueba; mezclar uno de cada es un error seguro.
TEST_APP_ID="ca-app-pub-3940256099942544~3347511713"
TEST_BANNER_ID="ca-app-pub-3940256099942544/6300978111"
ADMOB_APP_ID="${ADMOB_APP_ID:-}"
ADMOB_BANNER_ID="${ADMOB_BANNER_ID:-}"
if [ -n "$ADMOB_APP_ID" ] || [ -n "$ADMOB_BANNER_ID" ]; then
  if [ -z "$ADMOB_APP_ID" ] || [ -z "$ADMOB_BANNER_ID" ]; then
    echo "Pasa los dos: ADMOB_APP_ID (con ~) y ADMOB_BANNER_ID (con /)." >&2
    exit 1
  fi
  case "$ADMOB_APP_ID" in ca-app-pub-*~*) ;; *) echo "ADMOB_APP_ID debe tener la forma ca-app-pub-XXXX~YYYY." >&2; exit 1 ;; esac
  case "$ADMOB_BANNER_ID" in ca-app-pub-*/*) ;; *) echo "ADMOB_BANNER_ID debe tener la forma ca-app-pub-XXXX/ZZZZ." >&2; exit 1 ;; esac
  if [ "$ADMOB_APP_ID" = "$TEST_APP_ID" ] || [ "$ADMOB_BANNER_ID" = "$TEST_BANNER_ID" ]; then
    echo "Esos son los IDs de PRUEBA de Google, no los tuyos." >&2
    exit 1
  fi
  # Las dos mitades deben ser del mismo publicador (el número tras "ca-app-pub-").
  app_pub="${ADMOB_APP_ID#ca-app-pub-}"; app_pub="${app_pub%%~*}"
  banner_pub="${ADMOB_BANNER_ID#ca-app-pub-}"; banner_pub="${banner_pub%%/*}"
  if [ "$app_pub" != "$banner_pub" ]; then
    echo "El App ID y el ID del banner son de publicadores distintos ($app_pub y $banner_pub)." >&2
    exit 1
  fi
elif [ "$TARGET" = "appbundle" ] && [ "$ADS" = "true" ] && [ "${ALLOW_TEST_ADS:-}" != "1" ]; then
  echo "Este .aab llevaría los anuncios de PRUEBA de Google (sin ingresos)." >&2
  echo "Pasa ADMOB_APP_ID y ADMOB_BANNER_ID, o ALLOW_TEST_ADS=1 si es solo una prueba interna." >&2
  exit 1
fi
export ADMOB_APP_ID

VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr '+' '_')"
SYMBOLS="build/symbols/$VERSION"
mkdir -p "$SYMBOLS"

flutter build "$TARGET" --release \
  --obfuscate --split-debug-info="$SYMBOLS" \
  --dart-define=API_URL="$API_URL" \
  --dart-define=ADS="$ADS" \
  ${ADMOB_BANNER_ID:+--dart-define=ADMOB_BANNER_ID="$ADMOB_BANNER_ID"}

echo
echo "Símbolos de Dart:   $SYMBOLS"
echo "Mapa de R8:         build/app/outputs/mapping/release/mapping.txt"
case "$TARGET" in
  apk)       echo "APK:                build/app/outputs/flutter-apk/app-release.apk" ;;
  appbundle) echo "App Bundle:         build/app/outputs/bundle/release/app-release.aab" ;;
esac
