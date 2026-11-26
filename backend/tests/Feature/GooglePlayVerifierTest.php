<?php

namespace Tests\Feature;

use App\Exceptions\PurchaseException;
use App\Services\GooglePlayVerifier;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GooglePlayVerifierTest extends TestCase
{
    private const PRODUCT_URL = 'androidpublisher.googleapis.com/androidpublisher/v3/applications/com.rayita.app/purchases/products/remove_ads/tokens/*';

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();

        // Cuenta de servicio de mentira con una llave RSA real (para firmar el JWT).
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
        openssl_pkey_export($key, $pem);
        config(['services.google_play.service_account_b64' => base64_encode(json_encode([
            'client_email' => 'play@rayita.iam.gserviceaccount.com',
            'private_key' => $pem,
        ]))]);
    }

    private function fakeGoogle(array|int $product, array $extra = []): void
    {
        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'at-123', 'expires_in' => 3600]),
            self::PRODUCT_URL.':acknowledge' => Http::response([]),
            self::PRODUCT_URL => is_int($product) ? Http::response([], $product) : Http::response($product),
            ...$extra,
        ]);
    }

    public function test_compra_pagada_devuelve_pedido_y_fecha(): void
    {
        $this->fakeGoogle([
            'purchaseState' => 0,
            'acknowledgementState' => 1,
            'orderId' => 'GPA.3333-1111',
            'purchaseTimeMillis' => '1795000000000',
        ]);

        $info = (new GooglePlayVerifier)->verifyProduct('remove_ads', 'tok');

        $this->assertSame('GPA.3333-1111', $info['order_id']);
        $this->assertSame(1795000000, $info['purchased_at']->timestamp);

        // Usó el token OAuth y la llamada incluye el JWT firmado con RS256.
        Http::assertSent(fn (Request $r) => str_contains($r->url(), '/tokens/tok') && $r->hasHeader('Authorization', 'Bearer at-123'));
        Http::assertSent(function (Request $r) {
            if ($r->url() !== 'https://oauth2.googleapis.com/token') {
                return false;
            }
            $jwt = explode('.', $r['assertion']);

            return $r['grant_type'] === 'urn:ietf:params:oauth:grant-type:jwt-bearer'
                && count($jwt) === 3
                && json_decode(base64_decode(strtr($jwt[1], '-_', '+/')), true)['iss'] === 'play@rayita.iam.gserviceaccount.com';
        });
    }

    public function test_confirma_la_compra_si_nadie_lo_hizo(): void
    {
        $this->fakeGoogle(['purchaseState' => 0, 'acknowledgementState' => 0]);

        (new GooglePlayVerifier)->verifyProduct('remove_ads', 'tok');

        Http::assertSent(fn (Request $r) => str_ends_with($r->url(), ':acknowledge'));
    }

    public function test_no_confirma_de_nuevo_si_ya_estaba_confirmada(): void
    {
        $this->fakeGoogle(['purchaseState' => 0, 'acknowledgementState' => 1]);

        (new GooglePlayVerifier)->verifyProduct('remove_ads', 'tok');

        Http::assertNotSent(fn (Request $r) => str_ends_with($r->url(), ':acknowledge'));
    }

    public function test_compra_cancelada_o_pendiente_es_invalida(): void
    {
        foreach ([1, 2] as $state) {
            $this->fakeGoogle(['purchaseState' => $state]);

            try {
                (new GooglePlayVerifier)->verifyProduct('remove_ads', 'tok');
                $this->fail('Debió lanzar');
            } catch (PurchaseException $e) {
                $this->assertSame(PurchaseException::INVALID, $e->reason);
            }
        }
    }

    public function test_token_desconocido_para_google_es_invalido(): void
    {
        foreach ([400, 404, 410] as $status) {
            $this->fakeGoogle($status);

            try {
                (new GooglePlayVerifier)->verifyProduct('remove_ads', 'inventado');
                $this->fail('Debió lanzar');
            } catch (PurchaseException $e) {
                $this->assertSame(PurchaseException::INVALID, $e->reason);
            }
        }
    }

    public function test_errores_de_google_o_permisos_no_dan_por_valida_la_compra(): void
    {
        foreach ([401, 403, 500] as $status) {
            $this->fakeGoogle($status);

            try {
                (new GooglePlayVerifier)->verifyProduct('remove_ads', 'tok');
                $this->fail('Debió lanzar');
            } catch (PurchaseException $e) {
                $this->assertSame(PurchaseException::UNAVAILABLE, $e->reason);
            }
        }
    }

    public function test_si_falla_el_token_oauth_no_da_por_valida_la_compra(): void
    {
        Http::fake(['oauth2.googleapis.com/token' => Http::response(['error' => 'invalid_grant'], 400)]);

        $this->expectException(PurchaseException::class);
        (new GooglePlayVerifier)->verifyProduct('remove_ads', 'tok');
    }

    public function test_sin_cuenta_de_servicio_lanza_no_configurado(): void
    {
        config(['services.google_play.service_account_b64' => null]);
        Http::fake();

        try {
            (new GooglePlayVerifier)->verifyProduct('remove_ads', 'tok');
            $this->fail('Debió lanzar');
        } catch (PurchaseException $e) {
            $this->assertSame(PurchaseException::NOT_CONFIGURED, $e->reason);
        }
        Http::assertNothingSent();
    }

    public function test_cuenta_de_servicio_corrupta_lanza_no_configurado(): void
    {
        config(['services.google_play.service_account_b64' => base64_encode('{"no":"sirve"}')]);

        $this->expectException(PurchaseException::class);
        (new GooglePlayVerifier)->verifyProduct('remove_ads', 'tok');
    }

    public function test_reutiliza_el_token_oauth_entre_llamadas(): void
    {
        $this->fakeGoogle(['purchaseState' => 0, 'acknowledgementState' => 1]);

        $verifier = new GooglePlayVerifier;
        $verifier->verifyProduct('remove_ads', 'a');
        $verifier->verifyProduct('remove_ads', 'b');

        Http::assertSentCount(3); // 1 token OAuth + 2 consultas
    }
}
