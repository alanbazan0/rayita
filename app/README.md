# Rayita (app)

App Flutter (Android, con web para pruebas; iOS descartado por ahora) de Rayita, un rastreador de hábitos con
calendario mensual, rachas y conteo con palitos. Usa Riverpod, Dio y
`flutter_secure_storage`. Idiomas: español e inglés.

## Desarrollo

```bash
flutter pub get
flutter run -d chrome          # API en http://localhost:8000/api
flutter test
flutter analyze
```

La URL de la API se cambia con `--dart-define=API_URL=https://tu-dominio/api`.

## Textos (idiomas)

Los textos viven en `lib/l10n/app_es.arb` y `lib/l10n/app_en.arb`. Tras editarlos:

```bash
flutter gen-l10n
```

## Ícono de la app

La imagen se genera con Pillow y se aplica a Android, iOS y Web:

```bash
python3 tool/make_icon.py
dart run flutter_launcher_icons
```
