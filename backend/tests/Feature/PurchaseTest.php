<?php

namespace Tests\Feature;

use App\Exceptions\PurchaseException;
use App\Models\Purchase;
use App\Models\User;
use App\Services\GooglePlayVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PurchaseTest extends TestCase
{
    use RefreshDatabase;

    private function verifier(array|\Throwable|null $result): void
    {
        $this->mock(GooglePlayVerifier::class, function ($mock) use ($result) {
            if ($result === null) {
                $mock->shouldNotReceive('verifyProduct');

                return;
            }
            $expectation = $mock->shouldReceive('verifyProduct');
            $result instanceof \Throwable ? $expectation->andThrow($result) : $expectation->andReturn($result);
        });
    }

    private function info(): array
    {
        return ['order_id' => 'GPA.1234', 'purchased_at' => Carbon::parse('2026-11-26 10:00:00')];
    }

    private function verify(array $override = []): TestResponse
    {
        return $this->postJson('/api/purchases/verify', [
            'product_id' => 'remove_ads',
            'purchase_token' => 'token-abc',
            ...$override,
        ], ['Accept-Language' => 'es']);
    }

    public function test_requiere_sesion(): void
    {
        $this->verifier(null);
        $this->verify()->assertUnauthorized();
    }

    public function test_requiere_correo_verificado(): void
    {
        $this->verifier(null);
        Sanctum::actingAs(User::factory()->unverified()->create());
        $this->verify()->assertForbidden();
    }

    public function test_compra_valida_quita_los_anuncios(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->assertFalse($user->ads_removed);
        $this->verifier($this->info());

        $this->verify()
            ->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('user.ads_removed', true);

        $this->assertDatabaseHas('purchases', [
            'user_id' => $user->id,
            'product_id' => 'remove_ads',
            'purchase_token' => 'token-abc',
            'order_id' => 'GPA.1234',
        ]);
    }

    public function test_repetir_la_misma_compra_es_idempotente_y_no_vuelve_a_llamar_a_google(): void
    {
        $user = User::factory()->create();
        Purchase::create(['user_id' => $user->id, 'product_id' => 'remove_ads', 'purchase_token' => 'token-abc']);
        Sanctum::actingAs($user);
        $this->verifier(null); // si llamara a Google, el mock fallaría

        $this->verify()->assertOk()->assertJsonPath('user.ads_removed', true);
        $this->assertDatabaseCount('purchases', 1);
    }

    public function test_una_compra_no_se_puede_ligar_a_dos_cuentas(): void
    {
        $owner = User::factory()->create();
        Purchase::create(['user_id' => $owner->id, 'product_id' => 'remove_ads', 'purchase_token' => 'token-abc']);
        $other = User::factory()->create();
        Sanctum::actingAs($other);
        $this->verifier(null);

        $this->verify(['purchase_token' => 'token-abc'])
            ->assertStatus(409)
            ->assertJsonPath('message', 'Esta compra ya está ligada a otra cuenta.');

        $this->assertFalse($other->fresh()->ads_removed);
    }

    public function test_compra_rechazada_por_google_no_quita_los_anuncios(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->verifier(PurchaseException::invalid('cancelada'));

        $this->verify()->assertStatus(422);

        $this->assertDatabaseCount('purchases', 0);
        $this->assertFalse($user->fresh()->ads_removed);
    }

    public function test_si_no_se_puede_consultar_a_google_responde_503_y_no_quita_anuncios(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        foreach ([PurchaseException::unavailable('caído'), PurchaseException::notConfigured()] as $error) {
            $this->verifier($error);
            $this->verify()->assertStatus(503);
        }

        $this->assertDatabaseCount('purchases', 0);
    }

    public function test_valida_los_campos(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->verifier(null);

        $this->verify(['product_id' => 'otro_producto'])->assertStatus(422)->assertJsonValidationErrors('product_id');
        $this->verify(['purchase_token' => ''])->assertStatus(422)->assertJsonValidationErrors('purchase_token');
        $this->verify(['purchase_token' => str_repeat('a', 513)])->assertStatus(422)->assertJsonValidationErrors('purchase_token');
    }

    public function test_me_informa_si_ya_quito_los_anuncios(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->getJson('/api/me')->assertOk()->assertJsonPath('user.ads_removed', false);

        Purchase::create(['user_id' => $user->id, 'product_id' => 'remove_ads', 'purchase_token' => 't1']);

        $this->getJson('/api/me')->assertOk()->assertJsonPath('user.ads_removed', true);
    }

    public function test_una_compra_de_otro_producto_no_quita_anuncios(): void
    {
        $user = User::factory()->create();
        Purchase::create(['user_id' => $user->id, 'product_id' => 'otra_cosa', 'purchase_token' => 't1']);

        $this->assertFalse($user->fresh()->ads_removed);
    }

    public function test_eliminar_la_cuenta_borra_sus_compras(): void
    {
        $user = User::factory()->create(['email' => 'ana@example.com']);
        Purchase::create(['user_id' => $user->id, 'product_id' => 'remove_ads', 'purchase_token' => 't1']);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/me', ['email' => 'ana@example.com'])->assertOk();

        $this->assertDatabaseCount('purchases', 0);
    }

    public function test_mensajes_en_ingles(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->verifier(PurchaseException::invalid('x'));

        $this->postJson('/api/purchases/verify', ['product_id' => 'remove_ads', 'purchase_token' => 't'], ['Accept-Language' => 'en'])
            ->assertStatus(422)
            ->assertJsonPath('message', "We couldn't confirm the purchase with Google Play.");
    }
}
