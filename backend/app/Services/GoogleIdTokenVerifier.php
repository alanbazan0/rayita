<?php

namespace App\Services;

use App\Exceptions\GoogleLoginException;
use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Verifica un ID token de Google Sign-In con las claves públicas de Google (JWKS).
 * No usa client secret: comprueba firma, emisor, audiencia (nuestros client IDs),
 * vigencia y que el correo esté verificado. Si algo falla, lanza; nunca "asume válido".
 */
class GoogleIdTokenVerifier
{
    private const JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';

    /** Margen de reloj (segundos) para exp/iat. */
    private const LEEWAY = 30;

    /**
     * @return array{sub: string, email: string, name: ?string, picture: ?string}
     *
     * @throws GoogleLoginException
     */
    public function verify(string $idToken): array
    {
        $audiences = $this->audiences();
        if ($audiences === []) {
            throw GoogleLoginException::notConfigured();
        }

        JWT::$leeway = self::LEEWAY;

        try {
            $payload = (array) JWT::decode($idToken, JWK::parseKeySet($this->jwks()));
        } catch (\Throwable $e) {
            throw GoogleLoginException::invalidToken($e->getMessage(), $e);
        }

        if (! in_array($payload['aud'] ?? null, $audiences, true)) {
            throw GoogleLoginException::invalidToken('audiencia no válida');
        }

        if (! in_array($payload['iss'] ?? null, ['accounts.google.com', 'https://accounts.google.com'], true)) {
            throw GoogleLoginException::invalidToken('emisor no válido');
        }

        $verified = $payload['email_verified'] ?? false;
        if (empty($payload['email']) || ! ($verified === true || $verified === 'true')) {
            throw GoogleLoginException::invalidToken('correo no verificado');
        }

        return [
            'sub' => (string) $payload['sub'],
            'email' => strtolower((string) $payload['email']),
            'name' => isset($payload['name']) ? (string) $payload['name'] : null,
            'picture' => isset($payload['picture']) ? (string) $payload['picture'] : null,
        ];
    }

    /** Client IDs aceptados como audiencia: el web (también usado como serverClientId) y el de iOS. */
    public function audiences(): array
    {
        return array_values(array_filter([
            config('services.google.client_id'),
            config('services.google.ios_client_id'),
        ], fn ($id) => filled($id)));
    }

    /** Las claves de Google rotan poco: se guardan 1 hora para no consultarlas en cada login. */
    private function jwks(): array
    {
        return Cache::remember('google_jwks', 3600, function () {
            $response = Http::timeout(5)->get(self::JWKS_URL);
            $response->throw();

            return $response->json();
        });
    }
}
