<?php

namespace App\Services;

/** Código de invitación para registrarse (INVITE_CODE). Vacío = registro abierto. */
class InviteCode
{
    public static function required(): bool
    {
        return filled(config('registration.invite_code'));
    }

    /** ¿El código dado es el correcto? (comparación en tiempo constante; ignora espacios alrededor). */
    public static function accepts(?string $given): bool
    {
        $expected = (string) config('registration.invite_code');

        return $expected !== '' && hash_equals($expected, trim((string) $given));
    }
}
