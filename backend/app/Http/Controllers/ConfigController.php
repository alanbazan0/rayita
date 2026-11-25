<?php

namespace App\Http\Controllers;

use App\Services\InviteCode;
use Illuminate\Http\JsonResponse;

class ConfigController extends Controller
{
    /** Ajustes públicos que la app necesita antes de iniciar sesión. */
    public function show(): JsonResponse
    {
        return response()->json([
            'registration' => [
                'requires_invite_code' => InviteCode::required(),
            ],
            // Los client IDs de Google son públicos; la app los necesita para iniciar el flujo.
            'google' => [
                'enabled' => filled(config('services.google.client_id')),
                'web_client_id' => config('services.google.client_id') ?: null,
                'ios_client_id' => config('services.google.ios_client_id') ?: null,
            ],
        ]);
    }
}
