import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/locale.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/ui.dart';
import '../widgets/welcome_scene.dart';

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
    const navy = WelcomeColors.navy;

    return Scaffold(
      backgroundColor: WelcomeColors.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: PlainLanguageButton(),
                  ),
                  const Center(
                    child: SizedBox(width: 220, child: WelcomeScene()),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    child: Column(
                      children: [
                        Text(
                          l.verifyTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.verifySubtitle(widget.user.email),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: navy.withValues(alpha: 0.75),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 12,
                      color: navy,
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
                        color: navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  NavyButton(
                    label: l.verifyButton,
                    busy: _busy,
                    onPressed: _busy ? null : _verify,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: canResend ? _resend : null,
                    style: TextButton.styleFrom(
                      foregroundColor: navy,
                      disabledForegroundColor: navy.withValues(alpha: 0.5),
                    ),
                    child: Text(
                      _cooldown > 0 ? l.resendIn(_cooldown) : l.resendCode,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    l.checkSpam,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: navy.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: InkWell(
                      onTap: _busy
                          ? null
                          : () => ref.read(authProvider.notifier).logout(),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Text(
                          l.useAnotherAccount,
                          style: const TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
