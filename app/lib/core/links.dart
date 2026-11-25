/// Direcciones públicas de Rayita.
const siteUrl = 'https://rayita.alanbazan.com.mx';
const supportEmail = 'support@alanbazan.com.mx';

/// Política de privacidad en el idioma pedido ('es' o cualquier otro = inglés).
Uri privacyUri(String languageCode) =>
    Uri.parse('$siteUrl/${languageCode == 'es' ? 'privacidad' : 'privacy'}');

Uri termsUri(String languageCode) =>
    Uri.parse('$siteUrl/${languageCode == 'es' ? 'terminos' : 'terms'}');

Uri supportUri() => Uri(scheme: 'mailto', path: supportEmail);
