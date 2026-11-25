import 'package:google_sign_in/google_sign_in.dart';

import 'models.dart';

/// Obtiene el ID token de Google en Android e iOS. En web no se usa: allí el
/// único flujo que entrega un ID token es el botón oficial de Google.
class GoogleAuthService {
  const GoogleAuthService();

  /// Devuelve el ID token, o null si la persona canceló.
  Future<String?> signIn(AppConfig config) async {
    final google = GoogleSignIn(
      scopes: const ['email', 'profile'],
      // El client ID "web" es la audiencia del token: sin él, Android no da idToken.
      serverClientId: config.googleWebClientId,
      // Solo lo usa iOS.
      clientId: config.googleIosClientId,
    );
    final account = await google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Sin plugin o sin sesión de Google: no hay nada que cerrar.
    }
  }
}
