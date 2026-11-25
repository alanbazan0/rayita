<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Bloquea la API de hábitos hasta que el usuario verifique su correo. */
class EnsureEmailVerified
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->user()?->hasVerifiedEmail()) {
            return response()->json([
                'message' => __('Debes verificar tu correo para continuar.'),
                'code' => 'email_not_verified',
            ], 403);
        }

        return $next($request);
    }
}
