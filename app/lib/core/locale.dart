import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

const _prefsKey = 'locale';

/// Idioma elegido por el usuario; null = seguir el idioma del dispositivo.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final code = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (code != null && _isSupported(code)) state = Locale(code);
    } catch (_) {
      // Sin almacenamiento: se queda en automático.
    }
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, locale.languageCode);
      }
    } catch (_) {
      // El cambio aplica en esta sesión aunque no se pueda guardar.
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

bool _isSupported(String code) =>
    AppLocalizations.supportedLocales.any((l) => l.languageCode == code);

/// Regla del modo automático: español si el sistema está en español y, para
/// cualquier otro idioma, inglés.
String resolveLanguage(String? deviceLanguageCode) =>
    deviceLanguageCode?.toLowerCase() == 'es' ? 'es' : 'en';

/// Resolución del idioma de la app cuando el usuario no eligió uno.
Locale resolveSystemLocale(Locale? device) =>
    Locale(resolveLanguage(device?.languageCode));

/// Código de idioma efectivo (para el header Accept-Language de la API).
String effectiveLanguageCode(Locale? override) {
  if (override != null) return override.languageCode;
  return resolveLanguage(ui.PlatformDispatcher.instance.locale.languageCode);
}
