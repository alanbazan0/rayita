<?php

namespace Tests\Feature;

use App\Exceptions\GoogleLoginException;
use App\Services\GoogleIdTokenVerifier;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GoogleIdTokenVerifierTest extends TestCase
{
    private const WEB = 'web-client.apps.googleusercontent.com';

    private const IOS = 'ios-client.apps.googleusercontent.com';

    private const JWKS = 'https://www.googleapis.com/oauth2/v3/certs';

    /** @var array{private: string, jwk: array<string, string>} */
    private array $key;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.google.client_id' => self::WEB, 'services.google.ios_client_id' => self::IOS]);
        Cache::forget('google_jwks');
        $this->key = $this->newKey('k1');
        Http::fake([self::JWKS => Http::response(['keys' => [$this->key['jwk']]])]);
    }

    /** Par de claves RSA de verdad, con su JWK público como lo publica Google. */
    private function newKey(string $kid): array
    {
        $res = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
        openssl_pkey_export($res, $private);
        $rsa = openssl_pkey_get_details($res)['rsa'];
        $b64 = fn (string $bin) => rtrim(strtr(base64_encode($bin), '+/', '-_'), '=');

        return [
            'private' => $private,
            'jwk' => ['kty' => 'RSA', 'alg' => 'RS256', 'use' => 'sig', 'kid' => $kid, 'n' => $b64($rsa['n']), 'e' => $b64($rsa['e'])],
        ];
    }

    private function token(array $override = [], ?array $key = null, string $kid = 'k1'): string
    {
        $claims = [
            'iss' => 'https://accounts.google.com',
            'aud' => self::WEB,
            'sub' => '1234567890',
            'email' => 'Ana@Example.com',
            'email_verified' => true,
            'name' => 'Ana Pérez',
            'picture' => 'https://example.com/a.png',
            'iat' => time() - 10,
            'exp' => time() + 3600,
            ...$override,
        ];

        return JWT::encode($claims, ($key ?? $this->key)['private'], 'RS256', $kid);
    }

    private function verify(string $token): array
    {
        return app(GoogleIdTokenVerifier::class)->verify($token);
    }

    public function test_token_valido_devuelve_los_datos_de_la_cuenta(): void
    {
        $this->assertSame([
            'sub' => '1234567890',
            'email' => 'ana@example.com', // en minúsculas
            'name' => 'Ana Pérez',
            'picture' => 'https://example.com/a.png',
        ], $this->verify($this->token()));
    }

    public function test_acepta_la_audiencia_de_ios(): void
    {
        $this->assertSame('1234567890', $this->verify($this->token(['aud' => self::IOS]))['sub']);
    }

    public function test_acepta_email_verified_como_texto_true(): void
    {
        $this->assertSame('ana@example.com', $this->verify($this->token(['email_verified' => 'true']))['email']);
    }

    public function test_rechaza_otra_audiencia(): void
    {
        $this->expectException(GoogleLoginException::class);
        $this->verify($this->token(['aud' => 'otra-app.apps.googleusercontent.com']));
    }

    public function test_rechaza_token_vencido(): void
    {
        $this->expectException(GoogleLoginException::class);
        $this->verify($this->token(['iat' => time() - 7200, 'exp' => time() - 3600]));
    }

    public function test_rechaza_otro_emisor(): void
    {
        $this->expectException(GoogleLoginException::class);
        $this->verify($this->token(['iss' => 'https://evil.example.com']));
    }

    public function test_rechaza_correo_no_verificado(): void
    {
        $this->expectException(GoogleLoginException::class);
        $this->verify($this->token(['email_verified' => false]));
    }

    public function test_rechaza_token_sin_correo(): void
    {
        $this->expectException(GoogleLoginException::class);
        $this->verify($this->token(['email' => '']));
    }

    public function test_rechaza_firma_de_otra_llave(): void
    {
        $this->expectException(GoogleLoginException::class);
        // Firmado con una llave distinta pero presentándose como "k1".
        $this->verify($this->token([], $this->newKey('k1')));
    }

    public function test_rechaza_kid_desconocido(): void
    {
        $this->expectException(GoogleLoginException::class);
        $this->verify($this->token([], null, 'otro-kid'));
    }

    public function test_rechaza_basura(): void
    {
        $this->expectException(GoogleLoginException::class);
        $this->verify('esto.no.es-un-jwt');
    }

    public function test_sin_client_id_configurado_falla_en_vez_de_aceptar(): void
    {
        config(['services.google.client_id' => null, 'services.google.ios_client_id' => null]);

        $this->expectException(GoogleLoginException::class);
        $this->expectExceptionMessage('no está configurado');
        $this->verify($this->token());
    }

    public function test_las_claves_de_google_se_guardan_en_cache(): void
    {
        $this->verify($this->token());
        $this->verify($this->token());

        Http::assertSentCount(1);
    }
}
