<?php

namespace App\Exceptions;

use RuntimeException;

/** Falla al iniciar sesión con Google (token inválido o función sin configurar). */
class GoogleLoginException extends RuntimeException
{
    public static function notConfigured(): self
    {
        return new self('GOOGLE_CLIENT_ID no está configurado.');
    }

    public static function invalidToken(string $reason, ?\Throwable $previous = null): self
    {
        return new self('Token de Google inválido: '.$reason, previous: $previous);
    }
}
