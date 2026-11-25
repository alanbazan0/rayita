import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/locale.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../widgets/language_button.dart';
import '../widgets/ui.dart';

/// Pantalla de código de 6 dígitos: se muestra hasta que el correo se verifica.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.user});

  final User user;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _cooldown = 0;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  bool _sentNotice = false;

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown - 1);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.length != 6) {
      setState(() => _error = context.l10n.validationCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Al verificarse, el estado de sesión cambia y la app pasa a la lista.
      await ref.read(authProvider.notifier).verifyEmail(_code.text);
    } catch (e) {
      if (mounted) {
        setState(() => _error = errorMessage(e, context.l10n));
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _sentNotice = false;
    });
    try {
      final wait = await ref.read(apiProvider).resendVerification();
      if (!mounted) return;
      _code.clear();
      setState(() => _sentNotice = wait == 0);
      _startCooldown(wait > 0 ? wait : 60);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final canResend = _cooldown <= 0 && !_resending && !_busy;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: primaryGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(40),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: RoundAction(child: LanguageButton()),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: softShadow(0.2),
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 44,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l.verifyTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.verifySubtitle(widget.user.email),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeSlideIn(
                  child: AppCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _code,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          autofillHints: const [AutofillHints.oneTimeCode],
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 12,
                          ),
                          decoration: InputDecoration(
                            labelText: l.codeLabel,
                            counterText: '',
                          ),
                          onChanged: (v) {
                            if (_error != null) setState(() => _error = null);
                            if (v.length == 6) _verify();
                          },
                          onSubmitted: (_) => _verify(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ] else if (_sentNotice) ...[
                          const SizedBox(height: 12),
                          Text(
                            l.codeSent,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: _busy ? null : _verify,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l.verifyButton),
                        ),
                        TextButton(
                          onPressed: canResend ? _resend : null,
                          child: Text(
                            _cooldown > 0
                                ? l.resendIn(_cooldown)
                                : l.resendCode,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.checkSpam,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Divider(height: 28),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => ref.read(authProvider.notifier).logout(),
                          child: Text(l.useAnotherAccount),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
