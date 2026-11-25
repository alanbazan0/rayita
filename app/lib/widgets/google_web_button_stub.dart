import 'package:flutter/widgets.dart';

/// Fuera de web no existe el botón oficial: Android/iOS usan el botón propio.
Widget buildGoogleWebButton({
  required String clientId,
  required void Function(String idToken) onIdToken,
  required void Function(Object error) onError,
}) => const SizedBox.shrink();
