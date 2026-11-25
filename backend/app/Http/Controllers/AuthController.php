<?php

namespace App\Http\Controllers;

use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Models\User;
use App\Services\EmailVerificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class AuthController extends Controller
{
    public function __construct(private readonly EmailVerificationService $verification) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        $user = User::create($request->safe()->except(['password_confirmation', 'invite_code']));

        // Si el correo falla, la cuenta queda creada y el usuario puede pedir
        // el código de nuevo desde la app.
        try {
            $this->verification->send($user);
        } catch (\Throwable $e) {
            Log::error('No se pudo enviar el código de verificación: '.$e->getMessage());
        }

        return response()->json([
            'user' => $user,
            'token' => $user->createToken('app')->plainTextToken,
        ], 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        if (! Auth::validate($request->only('email', 'password'))) {
            return response()->json(['message' => __('Correo o contraseña incorrectos.')], 422);
        }

        $user = User::where('email', $request->input('email'))->firstOrFail();

        return response()->json([
            'user' => $user,
            'token' => $user->createToken('app')->plainTextToken,
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(['user' => $request->user()]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => __('Sesión cerrada.')]);
    }
}
