<?php

namespace Tests\Unit;

use App\Mail\VerificationCodeMail;
use App\Models\User;
use App\Services\EmailVerificationService as Service;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class EmailVerificationServiceTest extends TestCase
{
    use RefreshDatabase;

    private Service $service;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = new Service;
        Mail::fake();
    }

    private function sendCode(User $user): string
    {
        $this->service->send($user);
        $code = null;
        Mail::assertSent(VerificationCodeMail::class, function ($mail) use (&$code) {
            $code = $mail->code;

            return true;
        });

        return $code;
    }

    public function test_envia_un_codigo_de_6_digitos_y_lo_guarda_con_hash(): void
    {
        $user = User::factory()->unverified()->create();
        $code = $this->sendCode($user);

        $this->assertMatchesRegularExpression('/^\d{6}$/', $code);
        $user->refresh();
        $this->assertNotSame($code, $user->email_verification_code);
        $this->assertTrue(Hash::check($code, $user->email_verification_code));
        $this->assertTrue($user->email_verification_expires_at->isFuture());
    }

    public function test_el_correo_va_al_usuario(): void
    {
        $user = User::factory()->unverified()->create();
        $this->sendCode($user);

        Mail::assertSent(VerificationCodeMail::class, fn ($m) => $m->hasTo($user->email));
    }

    public function test_codigo_correcto_verifica_y_limpia(): void
    {
        $user = User::factory()->unverified()->create();
        $code = $this->sendCode($user);

        $this->assertSame(Service::OK, $this->service->verify($user, $code));

        $user->refresh();
        $this->assertTrue($user->hasVerifiedEmail());
        $this->assertNull($user->email_verification_code);
    }

    public function test_codigo_incorrecto_suma_intento(): void
    {
        $user = User::factory()->unverified()->create();
        $this->sendCode($user);

        $this->assertSame(Service::INVALID, $this->service->verify($user, '000000'));
        $this->assertSame(1, $user->fresh()->email_verification_attempts);
        $this->assertFalse($user->fresh()->hasVerifiedEmail());
    }

    public function test_se_bloquea_tras_cinco_intentos_aunque_luego_acierte(): void
    {
        $user = User::factory()->unverified()->create();
        $code = $this->sendCode($user);
        $wrong = $code === '111111' ? '222222' : '111111';

        for ($i = 0; $i < Service::MAX_ATTEMPTS - 1; $i++) {
            $this->assertSame(Service::INVALID, $this->service->verify($user, $wrong));
        }
        $this->assertSame(Service::LOCKED, $this->service->verify($user, $wrong));
        // Con el código correcto sigue bloqueado hasta pedir uno nuevo.
        $this->assertSame(Service::LOCKED, $this->service->verify($user->fresh(), $code));
        $this->assertFalse($user->fresh()->hasVerifiedEmail());
    }

    public function test_codigo_vencido(): void
    {
        $user = User::factory()->unverified()->create();
        $code = $this->sendCode($user);

        $this->travel(Service::TTL_MINUTES + 1)->minutes();

        $this->assertSame(Service::EXPIRED, $this->service->verify($user->fresh(), $code));
    }

    public function test_sin_codigo_pedido_cuenta_como_vencido(): void
    {
        $user = User::factory()->unverified()->create();

        $this->assertSame(Service::EXPIRED, $this->service->verify($user, '123456'));
    }

    public function test_usuario_ya_verificado_devuelve_ok(): void
    {
        $user = User::factory()->create();

        $this->assertSame(Service::OK, $this->service->verify($user, '000000'));
    }

    public function test_reenvio_cada_60_segundos(): void
    {
        $user = User::factory()->unverified()->create();
        $this->assertSame(0, $this->service->secondsUntilResend($user));

        $this->service->send($user);
        $wait = $this->service->secondsUntilResend($user->fresh());
        $this->assertGreaterThan(55, $wait);
        $this->assertLessThanOrEqual(60, $wait);

        $this->travel(61)->seconds();
        $this->assertSame(0, $this->service->secondsUntilResend($user->fresh()));
    }

    public function test_un_codigo_nuevo_reinicia_los_intentos(): void
    {
        $user = User::factory()->unverified()->create();
        $this->sendCode($user);
        $this->service->verify($user, '000000');
        $this->assertSame(1, $user->fresh()->email_verification_attempts);

        $this->service->send($user->fresh());

        $this->assertSame(0, $user->fresh()->email_verification_attempts);
    }
}
