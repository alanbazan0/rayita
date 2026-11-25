# Publicar Rayita en Google Play

## 1. Llave de subida (upload key)

El `.aab` se firma con una llave propia, creada una sola vez:

| Qué | Dónde |
| --- | --- |
| Llave | `~/.android/rayita-upload/upload-keystore.jks` (alias `upload`) |
| Datos y contraseña | `app/android/key.properties` (en `.gitignore`, permisos 600) |

- **Nada de esto va al repositorio.** `android/.gitignore` ignora `key.properties`, `*.jks` y `*.keystore`.
- **Haz copia de seguridad hoy**: guarda el `.jks` y la contraseña (de `key.properties`) en un gestor de
  contraseñas o en una memoria cifrada. Si los pierdes hay que pedirle a Google que restablezca la llave
  de subida (trámite con soporte de Play).
- En otra computadora o en CI no existe `key.properties`: el build cae a la llave de depuración, que sirve
  para probar pero Google Play rechaza. `tool/build_release.sh appbundle` se niega a generar un `.aab` así.

## 2. Versión

En `app/pubspec.yaml`: `version: 1.0.0+1`. Lo que va tras el `+` es el *versionCode*: **cada subida a Play
necesita uno mayor** (`+2`, `+3`…). La parte `1.0.0` es la que ve la gente.

## 3. Compilar

```bash
app/tool/build_release.sh appbundle     # .aab para Google Play (ofuscado, con R8)
app/tool/build_release.sh apk           # APK para instalar directo en un teléfono
```

Salidas: `app/build/app/outputs/bundle/release/app-release.aab`, símbolos de Dart en
`app/build/symbols/<versión>/` y el mapa de R8 en `app/build/app/outputs/mapping/release/mapping.txt`.
Conserva símbolos y mapa de cada versión publicada.

## 4. Google Play Console

1. **Cuenta de desarrollador** (pago único de unos 25 USD, con verificación de identidad). Si es una cuenta
   personal nueva, Google suele pedir una **prueba cerrada con unos 12 testers durante 14 días** antes de
   poder publicar en producción. Confírmalo en tu consola, porque las cifras cambian.
2. **Crear la app**: nombre *Rayita*, idioma predeterminado, tipo *App*, gratuita.
3. **Play App Signing**: al subir el primer `.aab` acepta que Google administre la llave final. Tu llave de
   subida solo identifica tus subidas.
4. **Ficha de la tienda** (español e inglés):
   - Nombre: `Rayita: Hábitos día a día` / `Rayita: Habit Tracker`.
   - Descripción breve (80 caracteres): `Registra hábitos y rachas con rayitas, un día a la vez.` /
     `Track habits and streaks with tally marks, one day at a time.`
   - Ícono de 512 × 512, gráfico de funciones de 1024 × 500 y al menos 2 capturas de teléfono
     (hay ejemplos en `docs/screenshots/`).
5. **Política de privacidad**: `https://rayita.alanbazan.com.mx/privacidad`.
6. **Seguridad de los datos**: recopila nombre, correo, identificador de usuario y contenido del usuario
   (hábitos y marcas); se cifra en tránsito (HTTPS); no se comparte con terceros; no hay publicidad.
7. **Clasificación de contenido**, **público objetivo** (no dirigida a menores de 13) y **anuncios: no**.
8. **Eliminación de cuenta** *(bloqueante, aún no implementada)*: Play exige que la app permita eliminar la
   cuenta **dentro de la app** y un enlace web para pedirlo. Hoy solo se puede por correo.
9. Probar primero en **prueba interna**, luego **cerrada** y al final **producción**.

## 5. Inicio de sesión con Google en la versión publicada

Cada llave de firma tiene su huella SHA-1 y necesita su propio cliente Android en Google Cloud
(proyecto `rayita-515805`, paquete `com.rayita.app`):

| Para | Huella |
| --- | --- |
| APK de depuración (pruebas en tu teléfono, ya creada) | `~/.android/debug.keystore` |
| APK firmado con la llave de subida (instalar sin Play) | la de `upload-keystore.jks` |
| **Versión de Google Play** | Play Console → *Integridad de la app* → *Firma de apps* → certificado de firma |

Sin el cliente de la huella de Play, Google funcionaría en tu teléfono y **fallaría en la tienda**.

## 6. Después de publicar

- Sube a Play Console el `mapping.txt` y los símbolos de la versión, para leer los fallos ofuscados.
- Cada actualización: sube el `+N` de `pubspec.yaml`, compila el `.aab` y súbelo.
