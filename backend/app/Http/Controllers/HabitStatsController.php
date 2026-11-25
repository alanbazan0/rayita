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

        $streak = $this->streaks->calculate($doneDates, $today, $habit->activeDays());

        $monthPrefix = $month.'-';
        $monthDone = $doneDates->filter(fn ($d) => str_starts_with($d, $monthPrefix))->count();
        $monthPartial = $habit->logs()->inMonth($month)
            ->where('status', 'partial')->count();
        $totalPartial = $habit->logs()->where('status', 'partial')->count();

        return response()->json([
            'habit_id' => $habit->id,
            'current_streak' => $streak['current'],
            'longest_streak' => $streak['longest'],
            'goal' => $this->goals->evaluate($habit, $doneDates, $today),
            'month' => [
                'month' => $month,
                'done' => $monthDone,
                'partial' => $monthPartial,
                'tally' => $this->tally->fromCount($monthDone),
            ],
            'total' => [
                'done' => $doneDates->count(),
                'partial' => $totalPartial,
                'tally' => $this->tally->fromCount($doneDates->count()),
            ],
        ]);
    }
}
