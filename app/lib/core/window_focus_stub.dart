import 'dart:ui' show VoidCallback;

/// Fuera de web no hay "foco de ventana": la app móvil ya avisa al volver a
/// primer plano (AppLifecycleState.resumed).
VoidCallback listenWindowFocus(VoidCallback onFocus) => () {};
