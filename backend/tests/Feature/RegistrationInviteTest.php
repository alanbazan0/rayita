<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegistrationInviteTest extends TestCase
{
    use RefreshDatabase;

    private function payload(array $extra = []): array
    {
        return [
            'name' => 'Ana',
            'email' => 'ana@example.com',
            'password' => 'secreto123',
            'password_confirmation' => 'secreto123',
            ...$extra,
        ];
    }

    public function test_config_indica_que_no_hay_codigo_si_no_esta_configurado(): void
    {
        config(['registration.invite_code' => null]);

        $this->getJson('/api/config')
            ->assertOk()
            ->assertExactJson(['registration' => ['requires_invite_code' => false]]);
    }

    public function test_config_indica_que_hay_codigo_si_esta_configurado(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);

        $this->getJson('/api/config')
            ->assertOk()
            ->assertJsonPath('registration.requires_invite_code', true);
    }

    public function test_config_no_revela_el_codigo(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);

        $this->assertStringNotContainsString('PRUEBAS', $this->getJson('/api/config')->getContent());
    }

    public function test_registro_abierto_sin_codigo_configurado(): void
    {
        config(['registration.invite_code' => '']);

        $this->postJson('/api/register', $this->payload())->assertCreated();
        $this->assertDatabaseHas('users', ['email' => 'ana@example.com']);
    }

    public function test_codigo_configurado_exige_el_codigo(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);

        $this->postJson('/api/register', $this->payload(), ['Accept-Language' => 'es'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('invite_code')
            ->assertJsonPath('errors.invite_code.0', 'El código de invitación es obligatorio.');
        $this->assertDatabaseCount('users', 0);
    }

    public function test_codigo_incorrecto_se_rechaza(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);

        $this->postJson('/api/register', $this->payload(['invite_code' => 'otro']), ['Accept-Language' => 'en'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.invite_code.0', 'The invitation code is not valid.');
        $this->assertDatabaseCount('users', 0);
    }

    public function test_codigo_correcto_permite_registrarse_y_no_se_guarda(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);

        $this->postJson('/api/register', $this->payload(['invite_code' => 'PRUEBAS']))
            ->assertCreated()
            ->assertJsonStructure(['user', 'token']);

        $this->assertDatabaseHas('users', ['email' => 'ana@example.com']);
        $this->assertArrayNotHasKey('invite_code', User::first()->getAttributes());
    }

    public function test_codigo_correcto_tolera_espacios_alrededor(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);

        $this->postJson('/api/register', $this->payload(['invite_code' => '  PRUEBAS ']))->assertCreated();
    }

    public function test_codigo_distingue_mayusculas(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);

        $this->postJson('/api/register', $this->payload(['invite_code' => 'pruebas']))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('invite_code');
    }

    public function test_el_codigo_no_afecta_al_inicio_de_sesion(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);
        User::factory()->create(['email' => 'ana@example.com', 'password' => 'secreto123']);

        $this->postJson('/api/login', ['email' => 'ana@example.com', 'password' => 'secreto123'])->assertOk();
    }
}
