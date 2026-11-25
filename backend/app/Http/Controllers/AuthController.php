<?php

namespace App\Http\Controllers;

use App\Exceptions\GoogleLoginException;
use App\Http\Requests\GoogleLoginRequest;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Models\User;
use App\Services\EmailVerificationService;
use App\Services\GoogleIdTokenVerifier;
use App\Services\InviteCode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

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

    /**
     * Inicia sesión (o crea la cuenta) con un ID token de Google. El correo de Google ya
     * viene verificado, así que no se pide el código por correo. Una cuenta nueva exige el
     * código de invitación si el servidor lo tiene configurado; las existentes, no.
     */
    public function google(GoogleLoginRequest $request, GoogleIdTokenVerifier $verifier): JsonResponse
    {
        try {
            $claims = $verifier->verify($request->validated('id_token'));
        } catch (GoogleLoginException $e) {
            Log::warning('Login con Google rechazado: '.$e->getMessage());

            // Sin configurar es un problema del servidor; un token malo, del cliente.
            if ($verifier->audiences() === []) {
                return response()->json(['message' => __('El inicio de sesión con Google no está disponible.')], 503);
            }
            throw ValidationException::withMessages(['id_token' => [__('No se pudo verificar tu cuenta de Google.')]]);
        }

        $user = User::where('google_id', $claims['sub'])->first()
            ?? User::where('email', $claims['email'])->first();
        $created = false;

        if ($user === null) {
            if (InviteCode::required() && ! InviteCode::accepts($request->input('invite_code'))) {
                throw ValidationException::withMessages([
                    'invite_code' => [$request->filled('invite_code')
                        ? __('El código de invitación no es válido.')
                        : __('El código de invitación es obligatorio.')],
                ]);
            }

            // La contraseña aleatoria nunca se usa: esta cuenta entra con Google.
            $user = new User([
                'name' => $claims['name'] ?: Str::before($claims['email'], '@'),
                'email' => $claims['email'],
                'password' => Str::random(48),
            ]);
            $created = true;
        }

        $user->forceFill([
            'google_id' => $user->google_id ?: $claims['sub'],
            'email_verified_at' => $user->email_verified_at ?? now(),
        ])->save();

        return response()->json([
            'user' => $user,
            'token' => $user->createToken('app')->plainTextToken,
        ], $created ? 201 : 200);
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
