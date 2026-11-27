<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\GoogleIdTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/** La foto de perfil de Google se guarda (solo la URL) y se expone en el usuario. */
class GoogleAvatarTest extends TestCase
{
    use RefreshDatabase;

    private const PHOTO = 'https://lh3.googleusercontent.com/a/abc123=s96-c';

    private function login(?string $picture): TestResponse
    {
        config(['registration.invite_code' => null]);
        $this->mock(GoogleIdTokenVerifier::class, function ($mock) use ($picture) {
            $mock->shouldReceive('verify')->andReturn([
                'sub' => 'g-123', 'email' => 'ana@example.com', 'name' => 'Ana', 'picture' => $picture,
            ]);
            $mock->shouldReceive('audiences')->andReturn(['web.apps.googleusercontent.com']);
        });

        return $this->postJson('/api/google', ['id_token' => 'token']);
    }

    public function test_cuenta_nueva_guarda_la_foto_y_la_devuelve(): void
    {
        $this->login(self::PHOTO)
            ->assertCreated()
            ->assertJsonPath('user.avatar_url', self::PHOTO);

        $this->assertSame(self::PHOTO, User::firstWhere('email', 'ana@example.com')->avatar_url);
    }

    public function test_me_incluye_la_foto(): void
    {
        $token = $this->login(self::PHOTO)->json('token');

        $this->getJson('/api/me', ['Authorization' => "Bearer $token"])
            ->assertJsonPath('user.avatar_url', self::PHOTO);
    }

    public function test_se_refresca_si_la_foto_cambia(): void
    {
        $this->login(self::PHOTO)->assertCreated();
        $new = 'https://lh3.googleusercontent.com/a/nueva=s96-c';

        $this->login($new)->assertOk()->assertJsonPath('user.avatar_url', $new);
    }

    public function test_si_google_no_envia_foto_no_se_borra_la_que_ya_habia(): void
    {
        $this->login(self::PHOTO)->assertCreated();

        $this->login(null)->assertOk()->assertJsonPath('user.avatar_url', self::PHOTO);
    }

    public function test_una_cuenta_nueva_sin_foto_queda_sin_ella(): void
    {
        $this->login(null)->assertCreated()->assertJsonPath('user.avatar_url', null);
    }

    public function test_solo_acepta_urls_https_de_googleusercontent(): void
    {
        foreach ([
            'http://lh3.googleusercontent.com/a/x',
            'https://evil.example.com/pixel.png',
            'https://googleusercontent.com.evil.com/a.png',
            'javascript:alert(1)',
            'https://lh3.googleusercontent.com/'.str_repeat('a', 600),
        ] as $bad) {
            User::query()->delete();
            $this->login($bad)->assertCreated()->assertJsonPath('user.avatar_url', null);
        }
    }

    public function test_una_cuenta_de_correo_que_entra_con_google_recibe_la_foto(): void
    {
        User::factory()->create(['email' => 'ana@example.com']);

        $this->login(self::PHOTO)->assertOk()->assertJsonPath('user.avatar_url', self::PHOTO);
    }

    public function test_el_registro_normal_no_trae_foto(): void
    {
        config(['registration.invite_code' => null]);

        $this->postJson('/api/register', [
            'name' => 'Beto', 'email' => 'beto@example.com',
            'password' => 'secreto123', 'password_confirmation' => 'secreto123',
        ])->assertCreated()->assertJsonPath('user.avatar_url', null);
    }
}
