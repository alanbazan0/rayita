<?php

namespace App\Services;

use App\Models\Habit;
use Carbon\CarbonImmutable;

/**
 * Evalúa el avance de la meta de un hábito (si la tiene).
 *
 * - reset: cuenta la racha de días cumplidos seguidos; un día fallado la reinicia.
 * - accumulate: cuenta los días cumplidos dentro de la meta, aunque no sean seguidos.
 */
class GoalCalculator
{
    public const RESET = 'reset';

    public const ACCUMULATE = 'accumulate';

    public const ACTIVE = 'active';

    public const ACHIEVED = 'achieved';

    public const FAILED = 'failed';

    public function __construct(private readonly StreakCalculator $streaks) {}

    /**
     * @param  iterable<string>  $doneDates  Fechas Y-m-d cumplidas.
     * @return array<string, mixed>|null null si el hábito no tiene meta.
     */
    public function evaluate(Habit $habit, iterable $doneDates, CarbonImmutable $today): ?array
    {
        if (! $habit->goal_days || ! $habit->goal_start) {
            return null;
        }

        $start = $habit->goal_start->toDateString();
        $end = $habit->goal_end?->toDateString();
        $target = (int) $habit->goal_days;
        $onFail = $habit->goal_on_fail === self::ACCUMULATE ? self::ACCUMULATE : self::RESET;

        $active = $habit->activeDays();
        $inWindow = [];
        foreach ($doneDates as $date) {
            if ($date >= $start && ($end === null || $date <= $end) && $this->streaks->isActive($date, $active)) {
                $inWindow[] = $date;
            }
        }

        if ($onFail === self::ACCUMULATE) {
            $count = count(array_unique($inWindow));
            $achieved = $count >= $target;
            $progress = min($count, $target);
        } else {
            // Si la meta ya terminó, la racha se mide hasta su último día.
            $cursor = $end !== null && $today->toDateString() > $end
                ? CarbonImmutable::parse($end)
                : $today;
            $streak = $this->streaks->calculate($inWindow, $cursor, $active);
            $achieved = $streak['longest'] >= $target;
            $progress = $achieved ? $target : min($streak['current'], $target);
        }

        $ended = $end !== null && $today->toDateString() > $end;
        $status = $achieved ? self::ACHIEVED : ($ended ? self::FAILED : self::ACTIVE);

        return [
            'target' => $target,
            'progress' => $progress,
            'on_fail' => $onFail,
            'start' => $start,
            'end' => $end,
            'status' => $status,
            'days_left' => $end === null ? null : max(0, (int) $today->startOfDay()->diffInDays(CarbonImmutable::parse($end), false)),
        ];
    }
}
