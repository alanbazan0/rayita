<?php

namespace App\Http\Controllers;

use App\Services\EmailVerificationService as Verification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class EmailVerificationController extends Controller
{
    public function __construct(private readonly Verification $verification) {}

    public function verify(Request $request): JsonResponse
    {
        $data = $request->validate(
            ['code' => ['required', 'digits:6']],
            [
                'code.required' => __('El código es obligatorio.'),
                'code.digits' => __('El código debe tener 6 dígitos.'),
            ],
        );

        $user = $request->user();

        $result = $this->verification->verify($user, $data['code']);

        return match ($result) {
            Verification::OK => response()->json(['user' => $user->fresh()]),
            Verification::EXPIRED => response()->json([
                'message' => __('El código venció. Pide uno nuevo.'),
                'code' => 'code_expired',
            ], 422),
            Verification::LOCKED => response()->json([
                'message' => __('Demasiados intentos. Pide un código nuevo.'),
                'code' => 'code_locked',
            ], 422),
            default => response()->json([
                'message' => __('El código es incorrecto.'),
                'code' => 'code_invalid',
            ], 422),
        };
    }

    public function resend(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->hasVerifiedEmail()) {
            return response()->json(['user' => $user]);
        }

        $wait = $this->verification->secondsUntilResend($user);
        if ($wait > 0) {
            return response()->json([
                'message' => __('Espera :seconds segundos para pedir otro código.', ['seconds' => $wait]),
                'code' => 'resend_too_soon',
                'retry_after' => $wait,
            ], 429);
        }

        try {
            $this->verification->send($user);
        } catch (\Throwable $e) {
            Log::error('No se pudo enviar el código de verificación: '.$e->getMessage());

            return response()->json([
                'message' => __('No pudimos enviar el correo. Inténtalo más tarde.'),
                'code' => 'mail_failed',
            ], 503);
        }

        return response()->json(['message' => __('Te enviamos un nuevo código.')]);
    }
}
