<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;

class ConfigController extends Controller
{
    /** Ajustes públicos que la app necesita antes de iniciar sesión. */
    public function show(): JsonResponse
    {
        return response()->json([
            'registration' => [
                'requires_invite_code' => filled(config('registration.invite_code')),
            ],
        ]);
    }
}
