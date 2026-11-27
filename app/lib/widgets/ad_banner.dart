import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads.dart';

/// Construye el banner real, con el hueco inferior que pide la pantalla.
/// Se sustituye en los tests.
final adBannerBuilderProvider = Provider<Widget Function(double bottomGap)>(
  (ref) =>
      (bottomGap) => _AdaptiveBanner(bottomGap: bottomGap),
);

/// Espacio del banner al pie de una pantalla (principal y detalle del hábito): no
/// ocupa nada si no hay anuncios (web, compra de "quitar anuncios" o sin consentimiento).
///
/// Va siempre fuera de la zona que se desplaza y lejos de botones y días del
/// calendario, para evitar toques accidentales (AdMob los penaliza).
class AdBannerSlot extends ConsumerStatefulWidget {
  const AdBannerSlot({super.key, this.bottomGap = 0});

  /// Hueco bajo el anuncio, por si algo flota encima (el botón "+" de la principal).
  final double bottomGap;

  @override
  ConsumerState<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends ConsumerState<AdBannerSlot> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(adsEnabledProvider)) _prepare();
  }

  Future<void> _prepare() async {
    final ok = await ref.read(adsPreparerProvider)();
    if (mounted && ok) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsEnabledProvider) || !_ready) {
      return const SizedBox.shrink();
    }
    return ref.read(adBannerBuilderProvider)(widget.bottomGap);
  }
}

/// Banner adaptable al ancho de la pantalla. Reserva su alto solo cuando el
/// anuncio ya cargó, para que la pantalla no salte ni quede un hueco vacío.
class _AdaptiveBanner extends StatefulWidget {
  const _AdaptiveBanner({required this.bottomGap});

  final double bottomGap;

  @override
  State<_AdaptiveBanner> createState() => _AdaptiveBannerState();
}

class _AdaptiveBannerState extends State<_AdaptiveBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _load(int width) async {
    _width = width;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    _ad?.dispose();
    setState(() => _loaded = false);
    final ad = BannerAd(
      adUnitId: adBannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (_width != width) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(width);
      });
    }
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomGap),
      child: Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: ad.size.height.toDouble(),
        color: Colors.white,
        child: AdWidget(ad: ad),
      ),
    );
  }
}
