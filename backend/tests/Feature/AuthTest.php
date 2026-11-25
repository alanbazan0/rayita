<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_registro_exitoso_devuelve_token(): void
    {
        $res = $this->postJson('/api/register', [
            'name' => 'Ana', 'email' => 'ana@example.com', 'password' => 'secreto123', 'password_confirmation' => 'secreto123',
        ]);

        $res->assertCreated()->assertJsonStructure(['user' => ['id', 'name', 'email'], 'token'])
            ->assertJsonMissingPath('user.password');
        $this->assertDatabaseHas('users', ['email' => 'ana@example.com']);
    }

    public function test_registro_valida_campos(): void
    {
        $this->postJson('/api/register', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['name', 'email', 'password']);
    }

    public function test_registro_rechaza_correo_duplicado_y_password_corta(): void
    {
        User::factory()->create(['email' => 'ana@example.com']);

        $this->postJson('/api/register', [
            'name' => 'Ana', 'email' => 'ana@example.com', 'password' => 'corta', 'password_confirmation' => 'corta',
        ])->assertUnprocessable()->assertJsonValidationErrors(['email', 'password']);
    }

    public function test_registro_exige_confirmacion_de_contrasena(): void
    {
        $base = ['name' => 'Ana', 'email' => 'ana@example.com', 'password' => 'secreto123'];

        // Sin confirmación.
        $this->postJson('/api/register', $base)
            ->assertUnprocessable()->assertJsonValidationErrors('password');

        // Confirmación distinta.
        $this->postJson('/api/register', $base + ['password_confirmation' => 'otra-cosa-123'], ['Accept-Language' => 'es'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.password.0', 'Las contraseñas no coinciden.');

        $this->assertDatabaseMissing('users', ['email' => 'ana@example.com']);
    }

    public function test_confirmacion_distinta_se_traduce_al_ingles(): void
    {
        $this->postJson('/api/register', [
            'name' => 'Ana', 'email' => 'ana@example.com', 'password' => 'secreto123', 'password_confirmation' => 'x',
        ], ['Accept-Language' => 'en'])
            ->assertJsonPath('errors.password.0', "Passwords don't match.");
    }

    public function test_login_correcto(): void
    {
        User::factory()->create(['email' => 'ana@example.com', 'password' => 'secreto123']);

        $this->postJson('/api/login', ['email' => 'ana@example.com', 'password' => 'secreto123'])
            ->assertOk()->assertJsonStructure(['user', 'token']);
    }

    public function test_login_con_credenciales_incorrectas(): void
    {
        User::factory()->create(['email' => 'ana@example.com', 'password' => 'secreto123']);

        $this->postJson('/api/login', ['email' => 'ana@example.com', 'password' => 'mala'], ['Accept-Language' => 'es'])
            ->assertUnprocessable()
            ->assertJson(['message' => 'Correo o contraseña incorrectos.']);
    }

    public function test_me_requiere_token(): void
    {
        $this->getJson('/api/me')->assertUnauthorized();
    }

    public function test_me_y_logout_con_token(): void
    {
        $token = User::factory()->create()->createToken('t')->plainTextToken;

        $this->withToken($token)->getJson('/api/me')->assertOk()->assertJsonStructure(['user' => ['id']]);
        $this->withToken($token)->postJson('/api/logout')->assertOk();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }
}
