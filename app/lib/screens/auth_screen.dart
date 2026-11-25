import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/locale.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../widgets/google_login_section.dart';
import '../widgets/language_button.dart';
import '../widgets/welcome_scene.dart';
import '../widgets/ui.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _invite = TextEditingController();
  bool _inviteNeeded =
      false; // el servidor lo pidió aunque no se pudo consultar
  bool _registering = false;
  bool _showForm = false; // false = pantalla de bienvenida
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      if (_registering) {
        await auth.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
          _confirm.text,
          inviteCode: _invite.text,
        );
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorMessage(e, context.l10n);
          // Si el servidor rechazó el código, se muestra el campo.
          if (_mentionsInviteCode(e)) _inviteNeeded = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _mentionsInviteCode(Object e) {
    if (e is! DioException) return false;
    final data = e.response?.data;
    return data is Map &&
        data['errors'] is Map &&
        (data['errors'] as Map).containsKey('invite_code');
  }

  /// Entra con Google. Si la cuenta es nueva y el servidor exige invitación,
  /// pide el código en un diálogo y reintenta con el mismo token.
  Future<void> _googleLogin(String idToken) async {
    String? code;
    while (true) {
      try {
        await ref
            .read(authProvider.notifier)
            .loginWithGoogle(idToken, inviteCode: code);
        return;
      } catch (e) {
        if (!_mentionsInviteCode(e) || !mounted) rethrow;
        final retry = code != null ? errorMessage(e, context.l10n) : null;
        code = await showDialog<String>(
          context: context,
          builder: (_) => _InviteCodeDialog(error: retry),
        );
        if (code == null || code.isEmpty) return; // canceló
      }
    }
  }

  void _googleError(Object e) {
    if (!mounted) return;
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e is DioException ? errorMessage(e, l) : l.googleFailed),
      ),
    );
  }

  /// "o" + botón de Google; solo si el servidor tiene Google configurado.
  List<Widget> _googleBlock() {
    final config = ref.watch(appConfigProvider).value ?? AppConfig.empty;
    if (!config.googleEnabled) return const [];
    return [
      const SizedBox(height: 18),
      GoogleLoginSection(
        config: config,
        onIdToken: _googleLogin,
        onError: _googleError,
      ),
    ];
  }

  void _open({required bool registering}) => setState(() {
    _registering = registering;
    _showForm = true;
    _confirm.clear();
    if (registering) ref.invalidate(appConfigProvider);
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WelcomeColors.cream,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _showForm
              ? KeyedSubtree(
                  key: const ValueKey('form'),
                  child: _buildForm(context),
                )
              : KeyedSubtree(
                  key: const ValueKey('welcome'),
                  child: _buildWelcome(context),
                ),
        ),
      ),
    );
  }

  /// Pantalla de bienvenida: ilustración, título y botón grande.
  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: _PlainLanguageButton(),
              ),
              const FadeSlideIn(child: WelcomeScene()),
              const SizedBox(height: 20),
              FadeSlideIn(
                index: 1,
                child: Column(
                  children: [
                    Text(
                      l.welcome,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: WelcomeColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.welcomeSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: WelcomeColors.navy.withValues(alpha: 0.75),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              FadeSlideIn(
                index: 2,
                child: _NavyButton(
                  label: l.createAccount,
                  onPressed: () => _open(registering: true),
                ),
              ),
              ..._googleBlock(),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 3,
                child: _SwitchLine(
                  question: l.haveAccountQuestion,
                  action: l.enter,
                  onTap: () => _open(registering: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formulario de inicio de sesión o registro.
  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    // El código solo se pide al registrarse, y solo si el servidor lo exige.
    final inviteRequired =
        _registering &&
        (_inviteNeeded ||
            (ref.watch(appConfigProvider).value?.requiresInviteCode ?? false));
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: WelcomeColors.navy,
                      ),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _showForm = false),
                    ),
                    const Spacer(),
                    const _PlainLanguageButton(),
                  ],
                ),
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(width: 240, child: WelcomeScene()),
                ),
                const SizedBox(height: 12),
                Text(
                  _registering ? l.createYourAccount : l.signIn,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: WelcomeColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                if (_registering) ...[
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: l.name,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l.validationName
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: l.email,
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? l.validationEmail
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: l.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 8) ? l.validationPassword : null,
                  onFieldSubmitted: (_) => _registering ? null : _submit(),
                ),
                if (_registering) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_reset),
                    ),
                    validator: (v) =>
                        v != _password.text ? l.validationPasswordMatch : null,
                    onFieldSubmitted: (_) => inviteRequired ? null : _submit(),
                  ),
                  if (inviteRequired) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _invite,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        labelText: l.inviteCode,
                        prefixIcon: const Icon(Icons.key_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l.validationInviteCode
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 22),
                _NavyButton(
                  label: _registering ? l.register : l.enter,
                  busy: _busy,
                  onPressed: _busy ? null : _submit,
                ),
                ..._googleBlock(),
                const SizedBox(height: 14),
                _SwitchLine(
                  question: _registering
                      ? l.haveAccountQuestion
                      : l.noAccountQuestion,
                  action: _registering ? l.enter : l.createAccount,
                  onTap: _busy ? null : () => _open(registering: !_registering),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón oscuro con la etiqueta a la izquierda y una flecha a la derecha.
class _NavyButton extends StatelessWidget {
  const _NavyButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: WelcomeColors.navy,
        foregroundColor: Colors.white,
        disabledBackgroundColor: WelcomeColors.navy.withValues(alpha: 0.7),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_forward),
        ],
      ),
    );
  }
}

/// "¿Ya tienes cuenta? **Entrar**".
class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: WelcomeColors.navy.withValues(alpha: 0.7),
      fontSize: 14,
    );
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text.rich(
            TextSpan(
              text: '$question ',
              style: base,
              children: [
                TextSpan(
                  text: action,
                  style: const TextStyle(
                    color: WelcomeColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector de idioma sin el círculo blanco, para el fondo crema.
class _PlainLanguageButton extends StatelessWidget {
  const _PlainLanguageButton();

  @override
  Widget build(BuildContext context) {
    return const IconTheme(
      data: IconThemeData(color: WelcomeColors.navy),
      child: LanguageButton(),
    );
  }
}

/// Pide el código de invitación cuando una cuenta nueva entra con Google.
class _InviteCodeDialog extends StatefulWidget {
  const _InviteCodeDialog({this.error});

  final String? error;

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.inviteCode),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.googleInviteBody),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: l.inviteCode,
              errorText: widget.error,
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l.continueLabel),
        ),
      ],
    );
  }
}
