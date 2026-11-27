<?php

namespace App\Enums;

enum LogStatus: string
{
    case Done = 'done';
    /** Obsoleto: ya no se puede crear. Hay filas antiguas con este valor que se conservan, ocultas. */
    case Partial = 'partial';
}
