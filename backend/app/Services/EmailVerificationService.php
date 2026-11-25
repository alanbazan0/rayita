<?php

namespace App\Services;

use App\Mail\VerificationCodeMail;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;

/**
 * Verificación de correo con un código de 6 dígitos:
 * vence en 15 minutos, admite 5 intentos y se puede reenviar cada 60 segundos.
 */
class EmailVerificationService
{
    public const TTL_MINUTES = 15;

    public const MAX_ATTEMPTS = 5;

    public const RESEND_SECONDS = 60;

    public const OK = 'ok';

    public const INVALID = 'invalid';

    public const EXPIRED = 'expired';

    public const LOCKED = 'locked';

    /** Genera un código nuevo, lo guarda con hash y lo envía por correo. */
    public function send(User $user): void
    {
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $user->forceFill([
            'email_verification_code' => Hash::make($code),
            'email_verification_expires_at' => now()->addMinutes(self::TTL_MINUTES),
            'email_verification_attempts' => 0,
            'email_verification_sent_at' => now(),
        ])->save();

        Mail::to($user->email)->send(new VerificationCodeMail($code, $user->name, self::TTL_MINUTES));
    }

    /** Segundos que faltan para poder pedir otro código (0 = ya se puede). */
    public function secondsUntilResend(User $user): int
    {
        $sentAt = $user->email_verification_sent_at;
        if ($sentAt === null) {
            return 0;
        }

        return max(0, (int) ceil(self::RESEND_SECONDS - $sentAt->diffInSeconds(now(), true)));
    }

    /** @return self::OK|self::INVALID|self::EXPIRED|self::LOCKED */
    public function verify(User $user, string $code): string
    {
        if ($user->hasVerifiedEmail()) {
            return self::OK;
        }

        if ($user->email_verification_code === null
            || $user->email_verification_expires_at === null
            || $user->email_verification_expires_at->isPast()) {
            return self::EXPIRED;
        }

        if ($user->email_verification_attempts >= self::MAX_ATTEMPTS) {
            return self::LOCKED;
        }

        if (! Hash::check($code, $user->email_verification_code)) {
            $user->forceFill(['email_verification_attempts' => $user->email_verification_attempts + 1])->save();

            return $user->email_verification_attempts >= self::MAX_ATTEMPTS ? self::LOCKED : self::INVALID;
        }

        $user->forceFill([
            'email_verified_at' => now(),
            'email_verification_code' => null,
            'email_verification_expires_at' => null,
            'email_verification_attempts' => 0,
        ])->save();

        return self::OK;
    }
}
