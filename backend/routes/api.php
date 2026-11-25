<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\EmailVerificationController;
use App\Http\Controllers\HabitController;
use App\Http\Controllers\HabitLogController;
use App\Http\Controllers\HabitStatsController;
use App\Http\Middleware\EnsureEmailVerified;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // Verificación de correo (permitida aunque el correo aún no esté verificado).
    Route::post('/email/verify', [EmailVerificationController::class, 'verify'])->middleware('throttle:20,1');
    Route::post('/email/resend', [EmailVerificationController::class, 'resend'])->middleware('throttle:6,60');

    // Todo lo demás exige correo verificado.
    Route::middleware(EnsureEmailVerified::class)->group(function () {
        Route::apiResource('habits', HabitController::class);
        Route::get('/habits/{habit}/stats', [HabitStatsController::class, 'show']);

        Route::get('/logs', [HabitLogController::class, 'index']);
        Route::put('/habits/{habit}/logs/{date}', [HabitLogController::class, 'upsert'])
            ->where('date', '\d{4}-\d{2}-\d{2}');
        Route::delete('/habits/{habit}/logs/{date}', [HabitLogController::class, 'destroy'])
            ->where('date', '\d{4}-\d{2}-\d{2}');
    });
});
