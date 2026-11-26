<?php

namespace App\Exceptions;

use RuntimeException;

/** Falla al validar una compra de Google Play. */
class PurchaseException extends RuntimeException
{
    public const NOT_CONFIGURED = 'not_configured';

    public const INVALID = 'invalid';

    public const UNAVAILABLE = 'unavailable';

    private function __construct(string $message, public readonly string $reason, ?\Throwable $previous = null)
    {
        parent::__construct($message, 0, $previous);
    }

    /** Falta la cuenta de servicio: la función existe pero no está configurada. */
    public static function notConfigured(): self
    {
        return new self('GOOGLE_PLAY_SERVICE_ACCOUNT_B64 no está configurado.', self::NOT_CONFIGURED);
    }

    /** Google dice que la compra no existe, está cancelada o pendiente. */
    public static function invalid(string $reason): self
    {
        return new self('Compra no válida: '.$reason, self::INVALID);
    }

    /** No se pudo hablar con Google (red, credenciales, permisos). */
    public static function unavailable(string $reason, ?\Throwable $previous = null): self
    {
        return new self('No se pudo consultar Google Play: '.$reason, self::UNAVAILABLE, $previous);
    }
}
