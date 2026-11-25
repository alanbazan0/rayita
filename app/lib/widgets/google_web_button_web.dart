import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget buildGoogleWebButton({
  required String clientId,
  required void Function(String idToken) onIdToken,
  required void Function(Object error) onError,
}) => _GoogleWebButton(
  clientId: clientId,
  onIdToken: onIdToken,
  onError: onError,
);

String? _initializedFor;

class _GoogleWebButton extends StatefulWidget {
  const _GoogleWebButton({
    required this.clientId,
    required this.onIdToken,
    required this.onError,
  });

  final String clientId;
  final void Function(String idToken) onIdToken;
  final void Function(Object error) onError;

  @override
  State<_GoogleWebButton> createState() => _GoogleWebButtonState();
}

class _GoogleWebButtonState extends State<_GoogleWebButton> {
  StreamSubscription<GoogleSignInUserData?>? _subscription;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final platform = GoogleSignInPlatform.instance;
      // El client ID llega de la API (no de una meta etiqueta), así que se
      // inicializa el plugin aquí, una sola vez por client ID.
      if (_initializedFor != widget.clientId) {
        await platform.initWithParams(
          SignInInitParameters(
            clientId: widget.clientId,
            scopes: const ['email', 'profile'],
          ),
        );
        _initializedFor = widget.clientId;
      }
      // No se llama signInSilently(): lanzaría el prompt "One Tap", que Google
      // aborta si nadie lo toca y deja al plugin en un estado inconsistente.
      _subscription = platform.userDataEvents?.listen((data) {
        final token = data?.idToken;
        if (token != null) widget.onIdToken(token);
      }, onError: widget.onError);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      widget.onError(e);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: _ready
          ? web.renderButton(
              configuration: web.GSIButtonConfiguration(
                theme: web.GSIButtonTheme.outline,
                size: web.GSIButtonSize.large,
                text: web.GSIButtonText.continueWith,
                shape: web.GSIButtonShape.pill,
              ),
            )
          : null,
    );
  }
}
