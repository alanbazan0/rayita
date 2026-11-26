import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/ad_free.dart';
import '../core/ads.dart';
import '../core/api.dart';
import '../core/links.dart';
import '../core/locale.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// Perfil de la cuenta: avatar, nombre y correo, enlaces legales, cerrar sesión
/// y, al final, la eliminación de la cuenta.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const _danger = Color(0xFFB3261E);

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.couldNotOpenLink;
    try {
      final ok = await ref.read(linkOpenerProvider)(uri);
      if (!ok) messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider.notifier);
    // La pantalla principal de la app cambia sola al quedar sin sesión; esta
    // ruta empujada hay que cerrarla antes.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.logout();
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final auth = ref.read(authProvider.notifier);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(email: email),
    );
    if (ok != true) return;
    try {
      await auth.deleteAccount(email);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e, l))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(authProvider).value;
    final habits = ref.watch(habitsProvider).value;
    final lang = resolveLanguage(Localizations.localeOf(context).languageCode);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                RoundAction(
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  l.account,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (user != null)
              FadeSlideIn(
                child: _ProfileCard(user: user, habitCount: habits?.length),
              ),
            if (ref.watch(adsSupportedProvider)) ...[
              const SizedBox(height: 22),
              _SectionLabel(l.adsSection),
              const SizedBox(height: 8),
              const FadeSlideIn(index: 1, child: _RemoveAdsCard()),
            ],
            const SizedBox(height: 22),
            _SectionLabel(l.legalSection),
            const SizedBox(height: 8),
            FadeSlideIn(
              index: 1,
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _LinkTile(
                      icon: Icons.privacy_tip_outlined,
                      label: l.privacyPolicy,
                      onTap: () => _open(context, ref, privacyUri(lang)),
                    ),
                    const Divider(height: 1, indent: 56),
                    _LinkTile(
                      icon: Icons.description_outlined,
                      label: l.termsOfService,
                      onTap: () => _open(context, ref, termsUri(lang)),
                    ),
                    const Divider(height: 1, indent: 56),
                    _LinkTile(
                      icon: Icons.mail_outline,
                      label: l.contactSupport,
                      onTap: () => _open(context, ref, supportUri()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              index: 2,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout),
                label: Text(l.logout),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.line, width: 1.5),
                  backgroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            if (user != null) ...[
              const SizedBox(height: 32),
              _SectionLabel(l.dangerZone, color: _danger),
              const SizedBox(height: 8),
              FadeSlideIn(
                index: 3,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _danger.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _danger.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.deleteAccountHint,
                        style: const TextStyle(height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _delete(context, ref, user.email),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: Text(l.deleteAccount),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _danger,
                          side: const BorderSide(color: _danger, width: 1.5),
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, this.habitCount});

  final User user;
  final int? habitCount;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final initial = user.name.trim().isEmpty
        ? user.email.characters.first.toUpperCase()
        : user.name.trim().characters.first.toUpperCase();

    Widget chip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(60),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: softShadow(0.1),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (user.emailVerified)
                chip(Icons.verified_outlined, l.verifiedEmail),
              if (habitCount != null)
                chip(Icons.checklist_rounded, l.habitsCount(habitCount!)),
              if (user.createdAt != null)
                chip(
                  Icons.calendar_today_outlined,
                  l.memberSince(
                    toBeginningOfSentenceCase(
                      DateFormat.yMMMM(locale).format(user.createdAt!),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compra única para quitar el banner (Google Play). Solo en Android.
class _RemoveAdsCard extends ConsumerStatefulWidget {
  const _RemoveAdsCard();

  @override
  ConsumerState<_RemoveAdsCard> createState() => _RemoveAdsCardState();
}

class _RemoveAdsCardState extends ConsumerState<_RemoveAdsCard> {
  bool _busy = false;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Manda el token de Google Play al servidor, que lo valida con Google; solo
  /// entonces la cuenta queda sin anuncios.
  Future<bool> _confirm(String token, AppLocalizations l) async {
    try {
      await ref
          .read(authProvider.notifier)
          .verifyPurchase(removeAdsProductId, token);
      return true;
    } catch (e) {
      _say(errorMessage(e, l));
      return false;
    }
  }

  Future<void> _buy() async {
    final l = context.l10n;
    setState(() => _busy = true);
    final result = await ref.read(adFreeStoreProvider).buy();
    if (result.outcome == PurchaseOutcome.purchased && result.token != null) {
      if (await _confirm(result.token!, l)) _say(l.purchaseDone);
    } else {
      switch (result.outcome) {
        case PurchaseOutcome.cancelled:
          break;
        case PurchaseOutcome.unavailable:
          _say(l.purchaseUnavailable);
        default:
          _say(l.purchaseFailed);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    final l = context.l10n;
    setState(() => _busy = true);
    final token = await ref.read(adFreeStoreProvider).restore();
    if (token == null) {
      _say(l.purchaseNothingToRestore);
    } else if (await _confirm(token, l)) {
      _say(l.purchaseRestored);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final removed = ref.watch(adsRemovedProvider);
    final price = ref.watch(adFreePriceProvider).value;

    if (removed) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.adsRemovedThanks,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.removeAds,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (price != null)
                Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.removeAdsHint,
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _busy ? null : _buy,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.removeAds),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _restore,
              child: Text(l.restorePurchase),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.color = AppColors.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.muted),
      onTap: onTap,
    );
  }
}

/// Confirmación para eliminar la cuenta: hay que escribir el correo de la cuenta.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.email});

  final String email;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  bool get _matches =>
      _controller.text.trim().toLowerCase() == widget.email.toLowerCase();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.deleteAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.deleteAccountBody),
          const SizedBox(height: 16),
          // Visible completo (el campo cortaría un correo largo en pantallas angostas).
          Text(
            l.deleteAccountConfirm(widget.email),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l.email),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AccountScreen._danger),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(l.deleteAccountButton),
        ),
      ],
    );
  }
}
