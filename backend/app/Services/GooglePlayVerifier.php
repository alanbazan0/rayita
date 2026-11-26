<?php

namespace App\Services;

use App\Exceptions\PurchaseException;
use Firebase\JWT\JWT;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Comprueba con la API de Google Play Developer que una compra de un producto
 * (no consumible) existe y está pagada. Sin esto, cualquiera podría mandar un
 * token inventado y quitarse los anuncios gratis.
 *
 * Usa una cuenta de servicio con permiso en Play Console. Nunca "asume válido":
 * si no se puede confirmar, lanza.
 */
class GooglePlayVerifier
{
    private const TOKEN_URL = 'https://oauth2.googleapis.com/token';

    private const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

    private const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';

    /** purchaseState de Google: 0 comprada, 1 cancelada, 2 pendiente. */
    private const PURCHASED = 0;

    /**
     * @return array{order_id: ?string, purchased_at: ?Carbon}
     *
     * @throws PurchaseException
     */
    public function verifyProduct(string $productId, string $purchaseToken): array
    {
        $package = (string) config('services.google_play.package');
        $url = sprintf('%s/%s/purchases/products/%s/tokens/%s', self::API, $package, rawurlencode($productId), rawurlencode($purchaseToken));

        try {
            $response = Http::withToken($this->accessToken())->timeout(10)->get($url);
        } catch (PurchaseException $e) {
            throw $e;
        } catch (\Throwable $e) {
            throw PurchaseException::unavailable($e->getMessage(), $e);
        }

        // 400/404/410: Google no conoce ese token (inventado, de otra app o ya reembolsado).
        if (in_array($response->status(), [400, 404, 410], true)) {
            throw PurchaseException::invalid('Google no reconoce la compra');
        }
        if ($response->failed()) {
            // 401/403 = la cuenta de servicio no tiene permisos; 5xx = Google caído.
            throw PurchaseException::unavailable('respuesta '.$response->status());
        }

        $data = $response->json();
        if (($data['purchaseState'] ?? null) !== self::PURCHASED) {
            throw PurchaseException::invalid('la compra está cancelada o pendiente');
        }

        // La app ya confirma (acknowledge) la compra, pero si no lo hizo Google la
        // reembolsa sola a los 3 días: se confirma aquí por si acaso (sin fallar).
        if (($data['acknowledgementState'] ?? 0) === 0) {
            Http::withToken($this->accessToken())->timeout(10)->post($url.':acknowledge', (object) []);
        }

        $millis = $data['purchaseTimeMillis'] ?? null;

        return [
            'order_id' => $data['orderId'] ?? null,
            'purchased_at' => $millis ? Carbon::createFromTimestampMs((int) $millis) : null,
        ];
    }

    /** Credenciales de la cuenta de servicio (JSON en base64 dentro del .env). */
    private function credentials(): array
    {
        $raw = (string) config('services.google_play.service_account_b64');
        $json = $raw === '' ? null : json_decode((string) base64_decode($raw, true), true);

        if (! is_array($json) || empty($json['client_email']) || empty($json['private_key'])) {
            throw PurchaseException::notConfigured();
        }

        return $json;
    }

    /** Token OAuth de la cuenta de servicio; dura 1 hora y se guarda 50 minutos. */
    private function accessToken(): string
    {
        $credentials = $this->credentials();

        return Cache::remember('google_play_access_token', 3000, function () use ($credentials) {
            $now = time();
            $assertion = JWT::encode([
                'iss' => $credentials['client_email'],
                'scope' => self::SCOPE,
                'aud' => self::TOKEN_URL,
                'iat' => $now,
                'exp' => $now + 3600,
            ], $credentials['private_key'], 'RS256');

            $response = Http::asForm()->timeout(10)->post(self::TOKEN_URL, [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ]);
            if ($response->failed() || empty($response->json('access_token'))) {
                throw PurchaseException::unavailable('no se obtuvo el token de acceso ('.$response->status().')');
            }

            return $response->json('access_token');
        });
    }
}
