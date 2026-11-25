<?php

namespace Tests\Feature;

use App\Exceptions\GoogleLoginException;
use App\Models\User;
use App\Services\GoogleIdTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class GoogleLoginTest extends TestCase
{
    use RefreshDatabase;

    private function claims(array $override = []): array
    {
        return ['sub' => 'g-123', 'email' => 'ana@example.com', 'name' => 'Ana Pérez', 'picture' => null, ...$override];
    }

    /** Sustituye al verificador: aquí se prueba el endpoint, no la criptografía. */
    private function fakeVerifier(array|\Throwable $result, array $audiences = ['web.apps.googleusercontent.com']): void
    {
        $this->mock(GoogleIdTokenVerifier::class, function ($mock) use ($result, $audiences) {
            $expectation = $mock->shouldReceive('verify');
            $result instanceof \Throwable ? $expectation->andThrow($result) : $expectation->andReturn($result);
            $mock->shouldReceive('audiences')->andReturn($audiences);
        });
    }

    private function login(array $extra = [], array $headers = []): TestResponse
    {
        return $this->postJson('/api/google', ['id_token' => 'token-de-google', ...$extra], $headers);
    }

    public function test_cuenta_nueva_se_crea_verificada_y_con_sesion(): void
    {
        config(['registration.invite_code' => null]);
        $this->fakeVerifier($this->claims());

        $this->login()
            ->assertCreated()
            ->assertJsonPath('user.email', 'ana@example.com')
            ->assertJsonPath('user.name', 'Ana Pérez')
            ->assertJsonStructure(['user', 'token'])
            ->assertJsonMissingPath('user.google_id');

        $user = User::firstWhere('email', 'ana@example.com');
        $this->assertSame('g-123', $user->google_id);
        $this->assertTrue($user->hasVerifiedEmail());
    }

    public function test_el_token_devuelto_sirve_sin_verificar_el_correo_por_codigo(): void
    {
        config(['registration.invite_code' => null]);
        $this->fakeVerifier($this->claims());
        $token = $this->login()->json('token');

        $this->getJson('/api/habits', ['Authorization' => "Bearer $token"])->assertOk();
    }

    public function test_sin_nombre_usa_la_parte_local_del_correo(): void
    {
        config(['registration.invite_code' => null]);
        $this->fakeVerifier($this->claims(['name' => null, 'email' => 'luis@example.com']));

        $this->login()->assertCreated()->assertJsonPath('user.name', 'luis');
    }

    public function test_cuenta_existente_por_correo_se_vincula_y_queda_verificada(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);
        $user = User::factory()->unverified()->create(['email' => 'ana@example.com']);
        $this->fakeVerifier($this->claims());

        // Una cuenta que ya existe no necesita código de invitación.
        $this->login()->assertOk()->assertJsonPath('user.id', $user->id);

        $user->refresh();
        $this->assertSame('g-123', $user->google_id);
        $this->assertTrue($user->hasVerifiedEmail());
        $this->assertDatabaseCount('users', 1);
    }

    public function test_cuenta_existente_por_google_id_aunque_cambie_el_correo(): void
    {
        $user = User::factory()->create(['email' => 'viejo@example.com', 'google_id' => 'g-123']);
        $this->fakeVerifier($this->claims(['email' => 'nuevo@example.com']));

        $this->login()->assertOk()->assertJsonPath('user.id', $user->id);
        $this->assertDatabaseCount('users', 1);
    }

    public function test_cuenta_nueva_exige_codigo_de_invitacion_si_esta_configurado(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);
        $this->fakeVerifier($this->claims());

        $this->login([], ['Accept-Language' => 'es'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.invite_code.0', 'El código de invitación es obligatorio.');
        $this->assertDatabaseCount('users', 0);
    }

    public function test_codigo_de_invitacion_incorrecto_se_rechaza(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);
        $this->fakeVerifier($this->claims());

        $this->login(['invite_code' => 'otro'], ['Accept-Language' => 'es'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.invite_code.0', 'El código de invitación no es válido.');
        $this->assertDatabaseCount('users', 0);
    }

    public function test_codigo_de_invitacion_correcto_crea_la_cuenta(): void
    {
        config(['registration.invite_code' => 'PRUEBAS']);
        $this->fakeVerifier($this->claims());

        $this->login(['invite_code' => ' PRUEBAS '])->assertCreated();
        $this->assertDatabaseHas('users', ['email' => 'ana@example.com']);
    }

    public function test_token_invalido_devuelve_422_sin_crear_nada(): void
    {
        $this->fakeVerifier(GoogleLoginException::invalidToken('firma'));

        $this->login([], ['Accept-Language' => 'es'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.id_token.0', 'No se pudo verificar tu cuenta de Google.');
        $this->assertDatabaseCount('users', 0);
    }

    public function test_sin_google_configurado_responde_503(): void
    {
        $this->fakeVerifier(GoogleLoginException::notConfigured(), audiences: []);

        $this->login([], ['Accept-Language' => 'es'])
            ->assertStatus(503)
            ->assertJsonPath('message', 'El inicio de sesión con Google no está disponible.');
    }

    public function test_exige_el_token(): void
    {
        $this->postJson('/api/google', [])->assertUnprocessable()->assertJsonValidationErrors('id_token');
    }

    public function test_la_cuenta_de_google_no_entra_con_contrasena(): void
    {
        config(['registration.invite_code' => null]);
        $this->fakeVerifier($this->claims());
        $this->login()->assertCreated();

        $this->postJson('/api/login', ['email' => 'ana@example.com', 'password' => 'cualquiera123'])
            ->assertUnprocessable();
    }

    public function test_config_publica_los_client_ids_de_google(): void
    {
        config(['services.google.client_id' => 'web.apps.googleusercontent.com', 'services.google.ios_client_id' => 'ios.apps.googleusercontent.com']);

        $this->getJson('/api/config')
            ->assertOk()
            ->assertJsonPath('google.enabled', true)
            ->assertJsonPath('google.web_client_id', 'web.apps.googleusercontent.com')
            ->assertJsonPath('google.ios_client_id', 'ios.apps.googleusercontent.com');
    }

    public function test_config_sin_google_lo_marca_desactivado(): void
    {
        config(['services.google.client_id' => null, 'services.google.ios_client_id' => null]);

        $this->getJson('/api/config')
            ->assertJsonPath('google.enabled', false)
            ->assertJsonPath('google.web_client_id', null);
    }
}
