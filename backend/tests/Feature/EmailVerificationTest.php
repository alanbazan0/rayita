<?php

namespace Tests\Feature;

use App\Mail\VerificationCodeMail;
use App\Models\Habit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EmailVerificationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // El cliente de pruebas manda en-us por defecto; se fija español.
        $this->withHeader('Accept-Language', 'es');
    }

    private function register(array $headers = ['Accept-Language' => 'es']): string
    {
        $res = $this->postJson('/api/register', [
            'name' => 'Ana', 'email' => 'ana@example.com',
            'password' => 'secreto123', 'password_confirmation' => 'secreto123',
        ], $headers)->assertCreated();

        return $res->json('token');
    }

    private function lastCode(): string
    {
        $code = null;
        Mail::assertSent(VerificationCodeMail::class, function ($mail) use (&$code) {
            $code = $mail->code;

            return true;
        });

        return $code;
    }

    public function test_registro_envia_el_codigo_y_deja_la_cuenta_sin_verificar(): void
    {
        Mail::fake();
        $this->register();

        Mail::assertSent(VerificationCodeMail::class, fn ($m) => $m->hasTo('ana@example.com'));
        $this->assertNull(User::first()->email_verified_at);
    }

    public function test_la_respuesta_no_expone_datos_del_codigo(): void
    {
        Mail::fake();
        $res = $this->postJson('/api/register', [
            'name' => 'Ana', 'email' => 'ana@example.com',
            'password' => 'secreto123', 'password_confirmation' => 'secreto123',
        ]);

        $res->assertJsonMissingPath('user.email_verification_code')
            ->assertJsonMissingPath('user.email_verification_attempts')
            ->assertJsonPath('user.email_verified_at', null);
    }

    public function test_si_falla_el_correo_el_registro_igual_funciona(): void
    {
        Mail::shouldReceive('to')->andThrow(new \RuntimeException('SMTP caído'));

        $this->postJson('/api/register', [
            'name' => 'Ana', 'email' => 'ana@example.com',
            'password' => 'secreto123', 'password_confirmation' => 'secreto123',
        ])->assertCreated();

        $this->assertDatabaseHas('users', ['email' => 'ana@example.com']);
    }

    public function test_sin_verificar_la_api_de_habitos_responde_403(): void
    {
        Mail::fake();
        $token = $this->register();

        foreach (['/api/habits', '/api/logs?month=2026-11'] as $url) {
            $this->withToken($token)->getJson($url)
                ->assertForbidden()
                ->assertJsonPath('code', 'email_not_verified')
                ->assertJsonPath('message', 'Debes verificar tu correo para continuar.');
        }
        $this->withToken($token)->postJson('/api/habits', ['name' => 'Leer'])->assertForbidden();
        $this->assertSame(0, Habit::count());
    }

    public function test_sin_verificar_si_puede_ver_su_perfil_y_cerrar_sesion(): void
    {
        Mail::fake();
        $token = $this->register();

        $this->withToken($token)->getJson('/api/me')->assertOk()->assertJsonPath('user.email_verified_at', null);
        $this->withToken($token)->postJson('/api/logout')->assertOk();
    }

    public function test_codigo_correcto_desbloquea_la_api(): void
    {
        Mail::fake();
        $token = $this->register();

        $this->withToken($token)->postJson('/api/email/verify', ['code' => $this->lastCode()])
            ->assertOk()
            ->assertJsonPath('user.email', 'ana@example.com');

        $this->assertNotNull(User::first()->email_verified_at);
        $this->withToken($token)->getJson('/api/habits')->assertOk();
    }

    public function test_codigo_incorrecto(): void
    {
        Mail::fake();
        $token = $this->register();
        $code = $this->lastCode();
        $wrong = $code === '000000' ? '111111' : '000000';

        $this->withToken($token)->postJson('/api/email/verify', ['code' => $wrong])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'code_invalid')
            ->assertJsonPath('message', 'El código es incorrecto.');
        $this->assertNull(User::first()->email_verified_at);
    }

    public function test_mensaje_en_ingles(): void
    {
        Mail::fake();
        $token = $this->register();

        $this->withToken($token)->postJson('/api/email/verify', ['code' => '000000'], ['Accept-Language' => 'en'])
            ->assertJsonPath('message', 'The code is incorrect.');
        $this->withToken($token)->getJson('/api/habits', ['Accept-Language' => 'en'])
            ->assertJsonPath('message', 'You must verify your email to continue.');
    }

    public function test_formato_del_codigo(): void
    {
        Mail::fake();
        $token = $this->register();

        $this->withToken($token)->postJson('/api/email/verify', [])->assertJsonValidationErrors('code');
        $this->withToken($token)->postJson('/api/email/verify', ['code' => '12ab56'])->assertJsonValidationErrors('code');
        $this->withToken($token)->postJson('/api/email/verify', ['code' => '12345'])->assertJsonValidationErrors('code');
    }

    public function test_bloqueo_tras_cinco_intentos_y_reenvio_lo_libera(): void
    {
        Mail::fake();
        $token = $this->register();
        $code = $this->lastCode();
        $wrong = $code === '000000' ? '111111' : '000000';

        for ($i = 0; $i < 5; $i++) {
            $res = $this->withToken($token)->postJson('/api/email/verify', ['code' => $wrong]);
        }
        $res->assertJsonPath('code', 'code_locked');
        $this->withToken($token)->postJson('/api/email/verify', ['code' => $code])
            ->assertJsonPath('code', 'code_locked');

        $this->travel(61)->seconds();
        $this->withToken($token)->postJson('/api/email/resend')->assertOk();

        $this->assertSame(0, User::first()->email_verification_attempts);
    }

    public function test_reenviar_respeta_la_espera_de_60_segundos(): void
    {
        Mail::fake();
        $token = $this->register();

        $this->withToken($token)->postJson('/api/email/resend')
            ->assertStatus(429)
            ->assertJsonPath('code', 'resend_too_soon')
            ->assertJsonStructure(['retry_after']);

        $this->travel(61)->seconds();
        $this->withToken($token)->postJson('/api/email/resend')
            ->assertOk()->assertJsonPath('message', 'Te enviamos un nuevo código.');
        Mail::assertSent(VerificationCodeMail::class, 2);
    }

    public function test_reenviar_con_smtp_caido_responde_503(): void
    {
        Mail::fake();
        $token = $this->register();
        $this->travel(61)->seconds();

        Mail::shouldReceive('to')->andThrow(new \RuntimeException('SMTP caído'));

        $this->withToken($token)->postJson('/api/email/resend')
            ->assertStatus(503)->assertJsonPath('code', 'mail_failed');
    }

    public function test_usuario_ya_verificado_no_recibe_otro_codigo(): void
    {
        Mail::fake();
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/email/resend')->assertOk();
        Mail::assertNothingSent();
    }

    public function test_los_endpoints_requieren_sesion(): void
    {
        $this->postJson('/api/email/verify', ['code' => '123456'])->assertUnauthorized();
        $this->postJson('/api/email/resend')->assertUnauthorized();
    }

    public function test_el_correo_se_envia_en_el_idioma_de_la_peticion(): void
    {
        Mail::fake();
        $this->register(['Accept-Language' => 'en']);

        Mail::assertSent(VerificationCodeMail::class, function ($mail) {
            return $mail->envelope()->subject === 'Your Rayita verification code'
                && str_contains($mail->render(), 'Use this code to verify your email')
                && str_contains($mail->render(), $mail->code);
        });
    }
}
