<?php

namespace App\Http\Controllers;

use App\Enums\LogStatus;
use App\Http\Requests\StoreHabitLogRequest;
use App\Http\Resources\HabitLogResource;
use App\Models\Habit;
use App\Models\HabitLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;

class HabitLogController extends Controller
{
    /** Marcas del mes (todas las del usuario, o de un hábito con ?habit_id=). */
    public function index(Request $request): AnonymousResourceCollection
    {
        $data = $request->validate([
            'month' => ['required', 'date_format:Y-m'],
            'habit_id' => ['sometimes', 'integer'],
        ], [
            'month.required' => __('El mes es obligatorio (AAAA-MM).'),
            'month.date_format' => __('El mes debe tener formato AAAA-MM.'),
        ]);

        $logs = HabitLog::query()
            ->whereHas('habit', fn ($q) => $q->where('user_id', $request->user()->id))
            ->when($data['habit_id'] ?? null, fn ($q, $id) => $q->where('habit_id', $id))
            ->inMonth($data['month'])
            ->orderBy('date')
            ->get();

        return HabitLogResource::collection($logs);
    }

    /** Crea o actualiza la marca de un día (idempotente). */
    public function upsert(StoreHabitLogRequest $request, Habit $habit, string $date): JsonResponse
    {
        abort_unless($habit->user_id === $request->user()->id, 404);

        if (! $habit->isActiveOn($date)) {
            throw ValidationException::withMessages([
                'date' => __('Ese día no está activo para este hábito. Cambia los días del hábito para poder marcarlo.'),
            ]);
        }

        $log = $habit->logs()->updateOrCreate(
            ['date' => $date],
            ['status' => $request->enum('status', LogStatus::class) ?? LogStatus::Done],
        );

        return (new HabitLogResource($log))
            ->response()
            ->setStatusCode($log->wasRecentlyCreated ? 201 : 200);
    }

    public function destroy(Request $request, Habit $habit, string $date): JsonResponse
    {
        abort_unless($habit->user_id === $request->user()->id, 404);

        $habit->logs()->where('date', $date)->delete();

        return response()->json(null, 204);
    }
}
