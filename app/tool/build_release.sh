#!/bin/bash
# Compila Rayita para Android en modo release, con el código Dart OFUSCADO y R8 activo.
#
# Uso:  tool/build_release.sh [apk|appbundle]      (por defecto: appbundle, el que pide Google Play)
#       API_URL=https://...  tool/build_release.sh apk
#       ADS=false tool/build_release.sh apk      (APK personal sin anuncios ni opción de compra)
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
VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr '+' '_')"
SYMBOLS="build/symbols/$VERSION"
mkdir -p "$SYMBOLS"

flutter build "$TARGET" --release \
  --obfuscate --split-debug-info="$SYMBOLS" \
  --dart-define=API_URL="$API_URL" \
  --dart-define=ADS="$ADS"

echo
echo "Símbolos de Dart:   $SYMBOLS"
echo "Mapa de R8:         build/app/outputs/mapping/release/mapping.txt"
case "$TARGET" in
  apk)       echo "APK:                build/app/outputs/flutter-apk/app-release.apk" ;;
  appbundle) echo "App Bundle:         build/app/outputs/bundle/release/app-release.aab" ;;
esac
