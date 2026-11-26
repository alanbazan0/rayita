import 'dart:js_interop';
import 'dart:ui' show VoidCallback;

import 'package:web/web.dart' as web;

/// Avisa cuando la ventana del navegador recupera el foco. Devuelve la función
/// que deja de escuchar.
VoidCallback listenWindowFocus(VoidCallback onFocus) {
  final listener = ((web.Event _) => onFocus()).toJS;
  web.window.addEventListener('focus', listener);
  return () => web.window.removeEventListener('focus', listener);
}
