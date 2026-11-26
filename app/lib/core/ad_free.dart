import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'providers.dart';

/// Producto de Google Play (no consumible) que quita los anuncios. Hay que
/// crearlo con este mismo ID en Play Console → Monetizar → Productos.
const removeAdsProductId = 'remove_ads';

enum PurchaseOutcome { purchased, cancelled, unavailable, failed }

/// Resultado de una compra: si salió bien trae el token que el servidor
/// valida con Google Play.
class PurchaseResult {
  const PurchaseResult(this.outcome, [this.token]);

  final PurchaseOutcome outcome;
  final String? token;
}

/// Compra de "quitar anuncios". Se sustituye en los tests.
abstract class AdFreeStore {
  /// Precio con la moneda del usuario, o null si el producto no está disponible.
  Future<String?> price();

  Future<PurchaseResult> buy();

  /// Token de una compra anterior de esta cuenta de Google Play, o null.
  Future<String?> restore();
}

class PlayAdFreeStore implements AdFreeStore {
  PlayAdFreeStore([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  Future<ProductDetails?> _product() async {
    if (!await _iap.isAvailable()) return null;
    final response = await _iap.queryProductDetails({removeAdsProductId});
    return response.productDetails.firstOrNull;
  }

  @override
  Future<String?> price() async {
    try {
      return (await _product())?.price;
    } catch (_) {
      return null;
    }
  }

  /// Espera el primer resultado de nuestro producto en el flujo de compras.
  Future<PurchaseDetails?> _firstResult(
    Future<void> Function() start, {
    required Duration timeout,
  }) async {
    final done = Completer<PurchaseDetails?>();
    final sub = _iap.purchaseStream.listen(
      (purchases) async {
        for (final p in purchases) {
          if (p.productID != removeAdsProductId) continue;
          if (p.status == PurchaseStatus.pending) continue;
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          if (!done.isCompleted) done.complete(p);
        }
      },
      onError: (_) {
        if (!done.isCompleted) done.complete(null);
      },
    );
    try {
      await start();
      return await done.future.timeout(timeout, onTimeout: () => null);
    } finally {
      await sub.cancel();
    }
  }

  static bool _paid(PurchaseDetails? p) =>
      p != null &&
      (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored);

  @override
  Future<PurchaseResult> buy() async {
    try {
      final product = await _product();
      if (product == null) {
        return const PurchaseResult(PurchaseOutcome.unavailable);
      }
      final result = await _firstResult(() async {
        await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: product),
        );
      }, timeout: const Duration(minutes: 5));
      if (_paid(result)) {
        return PurchaseResult(
          PurchaseOutcome.purchased,
          result!.verificationData.serverVerificationData,
        );
      }
      return PurchaseResult(
        result?.status == PurchaseStatus.canceled
            ? PurchaseOutcome.cancelled
            : PurchaseOutcome.failed,
      );
    } catch (_) {
      return const PurchaseResult(PurchaseOutcome.failed);
    }
  }

  @override
  Future<String?> restore() async {
    try {
      final result = await _firstResult(
        _iap.restorePurchases,
        timeout: const Duration(seconds: 8),
      );
      return _paid(result)
          ? result!.verificationData.serverVerificationData
          : null;
    } catch (_) {
      return null;
    }
  }
}

final adFreeStoreProvider = Provider<AdFreeStore>((ref) => PlayAdFreeStore());

/// Precio que se muestra en el botón (null mientras carga o si no hay producto).
final adFreePriceProvider = FutureProvider<String?>(
  (ref) => ref.watch(adFreeStoreProvider).price(),
);

/// Si la cuenta ya quitó los anuncios. Lo dice el servidor (que validó la
/// compra con Google Play), así sigue a la cuenta en cualquier dispositivo y
/// no sirve de nada falsificar el estado en el teléfono.
final adsRemovedProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).value?.adsRemoved ?? false,
);
