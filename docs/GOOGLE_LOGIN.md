# Inicio de sesión con Google

Funciona igual que en Noxa: la app obtiene un **ID token** de Google y lo manda a la API
(`POST /api/google`), que lo verifica **sin client secret** contra las claves públicas de Google
(JWKS) y responde con su propia sesión (token de Sanctum).

```
App (web / Android / iOS) ──ID token──▶ API /google ──verifica firma, audiencia, vigencia──▶ sesión
```

- La cuenta se crea (o se vincula por correo) ya **verificada**: no pide el código por correo.
- Si el servidor tiene `INVITE_CODE`, una cuenta **nueva** pide el código de invitación (la app abre un
  diálogo y reintenta con el mismo token). Las cuentas que ya existen no lo necesitan.
- El botón solo aparece si el servidor tiene `GOOGLE_CLIENT_ID` configurado (`GET /api/config`).
- El correo y la contraseña siguen funcionando.

## Configuración en Google Cloud

1. **Proyecto**: console.cloud.google.com → usa el de Noxa o crea "Rayita".
2. **Google Auth Platform → Branding**: nombre "Rayita", correo de soporte, dominio autorizado
   `alanbazan.com.mx`. **Acceso a datos**: solo `openid`, `email`, `profile`. **Público → En producción**.
3. **Clientes → Crear cliente → Aplicación web** ("Rayita Web"):
   - Orígenes de JavaScript autorizados: `https://rayita.alanbazan.com.mx`, `http://localhost:8080`, `http://localhost`.
   - Sin URI de redirección.
   - Copia el **ID de cliente** (`…apps.googleusercontent.com`). Es el `GOOGLE_CLIENT_ID`: lo usan la
     web, la verificación de la API y Android (como `serverClientId`).
4. **Clientes → Crear cliente → Android**: paquete `com.rayita.app` y la huella **SHA-1**.
   - Debug: `keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | grep SHA1`
   - Producción: la SHA-1 de *Play Console → Integridad de la app → Firma de apps* (otro cliente Android).
5. **Clientes → Crear cliente → iOS**: Bundle ID `com.rayita.app`. Copia el **ID de cliente de iOS**
   (`GOOGLE_IOS_CLIENT_ID`) y su valor invertido (ver abajo).

## Activarlo en el servidor

Los IDs de cliente son públicos. Tres formas, de menos a más trabajo:

- **Sin redesplegar**: GitHub → Actions → *Operación del servidor* → `set-google-client-id` (y
  `set-google-ios-client-id`), con el ID en el campo *value*.
- **En el despliegue** (lo que usamos): el ID web está en el `env:` de `.github/workflows/deploy-api.yml` y
  el de iOS, cuando exista, va como secreto `GOOGLE_IOS_CLIENT_ID`. Cada despliegue reescribe el `.env`
  del servidor, así que lo puesto con `set-google-client-id` se pierde en el siguiente despliegue.
- **En local**: `GOOGLE_CLIENT_ID=…` en `backend/.env`.

## iOS: esquema de URL (una vez, con el ID de iOS)

En `app/ios/Runner/Info.plist` agrega el ID invertido como esquema de URL. Si el ID es
`123-abc.apps.googleusercontent.com`, el esquema es `com.googleusercontent.apps.123-abc`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>com.googleusercontent.apps.123-abc</string></array>
  </dict>
</array>
```

## Probar en local (web)

1. `GOOGLE_CLIENT_ID` en `backend/.env` y `php artisan serve`.
2. `flutter run -d chrome --web-port 8080` (el origen `http://localhost:8080` debe estar autorizado).

## Si falla

| Síntoma | Causa probable |
| --- | --- |
| `origin_mismatch` en web | Falta el origen en el cliente web (incluye puerto) |
| Android: `ApiException: 10` / `DEVELOPER_ERROR` | SHA-1 o nombre de paquete no coinciden con el cliente Android |
| Android: el token llega vacío | Falta el cliente web (`serverClientId`) |
| "Acceso bloqueado" | La pantalla de consentimiento sigue en *Pruebas* y la cuenta no es de prueba |
| 503 `/google` | El servidor no tiene `GOOGLE_CLIENT_ID` |
| 422 `id_token` | Token de otra aplicación (audiencia distinta), vencido o con correo sin verificar |

## Qué es JWKS

**JSON Web Key Set**: la lista de **claves públicas** con las que Google firma sus tokens, publicada en
`https://www.googleapis.com/oauth2/v3/certs`. Para validar un ID token, la API descarga esa lista
(y la guarda 1 hora), busca la clave por el `kid` del token y comprueba la firma. No necesita ningún
secreto: cualquiera puede verificar, pero solo Google puede firmar.
