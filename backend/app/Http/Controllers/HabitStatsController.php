<?php

namespace App\Http\Controllers;

use App\Models\Habit;
use App\Services\GoalCalculator;
use App\Services\StreakCalculator;
use App\Services\TallyCalculator;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HabitStatsController extends Controller
{
    public function __construct(
        private readonly StreakCalculator $streaks,
        private readonly TallyCalculator $tally,
        private readonly GoalCalculator $goals,
    ) {}

    /**
     * Rachas y conteo de palitos. `today` (AAAA-MM-DD) permite al cliente
     * indicar su día local; `month` (AAAA-MM) elige el mes del resumen.
     */
    public function show(Request $request, Habit $habit): JsonResponse
    {
        abort_unless($habit->user_id === $request->user()->id, 404);

        $data = $request->validate([
            'today' => ['sometimes', 'date_format:Y-m-d'],
            'month' => ['sometimes', 'date_format:Y-m'],
        ], [
            'today.date_format' => __('La fecha debe tener formato AAAA-MM-DD.'),
            'month.date_format' => __('El mes debe tener formato AAAA-MM.'),
        ]);

        $today = CarbonImmutable::parse($data['today'] ?? now()->toDateString());
        $month = $data['month'] ?? $today->format('Y-m');

        $doneDates = $habit->logs()->done()->orderBy('date')->get()
            ->map(fn ($log) => $log->date->toDateString());

        // Primera marca: el hábito "empieza" ahí, no el día en que se creó (se pueden
        // registrar días atrás). Las marcas "parcial" antiguas ya no cuentan.
        $first = $habit->logs()->done()->min('date');

        // Cuaderno de rayitas: los días cumplidos agrupados por mes, del más reciente al más antiguo.
        $history = $doneDates
            ->groupBy(fn ($date) => substr($date, 0, 7))
            ->map(fn ($dates, $monthKey) => [
                'month' => (string) $monthKey,
                'done' => $dates->count(),
                'tally' => $this->tally->fromCount($dates->count()),
            ])
            ->sortKeysDesc()
            ->values();

        $streak = $this->streaks->calculate($doneDates, $today, $habit->activeDays());

        $monthPrefix = $month.'-';
        $monthDone = $doneDates->filter(fn ($d) => str_starts_with($d, $monthPrefix))->count();

        return response()->json([
            'habit_id' => $habit->id,
            'current_streak' => $streak['current'],
            'longest_streak' => $streak['longest'],
            'goal' => $this->goals->evaluate($habit, $doneDates, $today),
            'since' => $first ? substr((string) $first, 0, 10) : null,
            'history' => $history,
            'month' => [
                'month' => $month,
                'done' => $monthDone,
                // Obsoleto: lo siguen leyendo las apps anteriores a quitar el estado parcial.
                'partial' => 0,
                'tally' => $this->tally->fromCount($monthDone),
            ],
            'total' => [
                'done' => $doneDates->count(),
                'partial' => 0,
                'tally' => $this->tally->fromCount($doneDates->count()),
            ],
        ]);
    }
}
