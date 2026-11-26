import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_free.dart';

/// ID del bloque de banner. Por defecto es el de PRUEBA de Google: con IDs
/// reales en desarrollo se arriesga la suspensión de la cuenta de AdMob.
/// En el build de producción: --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXX/YYYY
const adBannerUnitId = String.fromEnvironment(
  'ADMOB_BANNER_ID',
  defaultValue: 'ca-app-pub-3940256099942544/6300978111',
);

/// Compilación sin anuncios (uso personal): --dart-define=ADS=false. Quita el
/// banner y también la opción de comprar "quitar anuncios".
const adsBuild = bool.fromEnvironment('ADS', defaultValue: true);

/// Los anuncios solo existen en Android (la web de pruebas no lleva).
bool get platformSupportsAds =>
    adsBuild && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Si esta plataforma admite anuncios (y por tanto la compra para quitarlos).
/// Se sustituye en los tests.
final adsSupportedProvider = Provider<bool>((ref) => platformSupportsAds);

/// Si se muestran anuncios: plataforma compatible y sin la compra de quitarlos.
/// Se sustituye en los tests.
final adsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(adsSupportedProvider) && !ref.watch(adsRemovedProvider),
);

/// Pide el consentimiento (obligatorio en la UE y el Reino Unido) y arranca el
/// SDK. Devuelve si ya se pueden pedir anuncios. Nunca lanza: sin anuncios la
/// app funciona igual.
Future<bool> prepareAds() async {
  try {
    final consent = ConsentInformation.instance;
    final updated = Completer<void>();
    consent.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      updated.complete,
      (_) => updated.complete(),
    );
    await updated.future;
    final shown = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((_) => shown.complete());
    await shown.future;
    if (!await consent.canRequestAds()) return false;
    await MobileAds.instance.initialize();
    return true;
  } catch (_) {
    return false;
  }
}

/// Se sustituye en los tests para no tocar el SDK.
final adsPreparerProvider = Provider<Future<bool> Function()>(
  (ref) => prepareAds,
);
