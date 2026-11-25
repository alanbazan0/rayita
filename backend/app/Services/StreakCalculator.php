<?php

namespace App\Services;

use Carbon\CarbonImmutable;

/**
 * Calcula rachas a partir de fechas (Y-m-d) en las que el hábito se cumplió.
 *
 * Con días activos (ISO 1–7), solo esos días cuentan: un día inactivo ni suma
 * ni rompe la racha (viernes y lunes son consecutivos si el fin de semana no aplica).
 */
class StreakCalculator
{
    public const ALL_DAYS = [1, 2, 3, 4, 5, 6, 7];

    /**
     * @param  iterable<string>  $dates  Fechas Y-m-d marcadas como cumplidas.
     * @param  list<int>  $activeDays  Días de la semana (ISO) en que aplica el hábito.
     * @return array{current: int, longest: int}
     */
    public function calculate(iterable $dates, CarbonImmutable $today, array $activeDays = self::ALL_DAYS): array
    {
        $set = [];
        foreach ($dates as $date) {
            if ($this->isActive($date, $activeDays)) {
                $set[$date] = true;
            }
        }

        if ($set === []) {
            return ['current' => 0, 'longest' => 0];
        }

        $sorted = array_keys($set);
        sort($sorted);

        $longest = 1;
        $run = 1;
        for ($i = 1; $i < count($sorted); $i++) {
            $run = $this->previousActive($sorted[$i], $activeDays) === $sorted[$i - 1] ? $run + 1 : 1;
            $longest = max($longest, $run);
        }

        // La racha sigue viva si hoy ya se marcó, o si el último día activo
        // anterior fue cumplido (aún puedes marcar hoy sin perderla).
        $cursor = $today->startOfDay()->toDateString();
        if (! isset($set[$cursor])) {
            $cursor = $this->previousActive($cursor, $activeDays);
        }

        $current = 0;
        while (isset($set[$cursor])) {
            $current++;
            $cursor = $this->previousActive($cursor, $activeDays);
        }

        return ['current' => $current, 'longest' => $longest];
    }

    /**
     * Primer día de la racha actual (la misma que calcula calculate()), o null si no hay.
     *
     * @param  iterable<string>  $dates  Fechas Y-m-d marcadas como cumplidas.
     * @param  list<int>  $activeDays
     */
    public function currentStreakStart(iterable $dates, CarbonImmutable $today, array $activeDays = self::ALL_DAYS): ?string
    {
        $set = [];
        foreach ($dates as $date) {
            if ($this->isActive($date, $activeDays)) {
                $set[$date] = true;
            }
        }

        // La racha sigue viva si hoy ya se marcó o si el último día activo anterior se cumplió.
        $cursor = $today->startOfDay()->toDateString();
        if (! isset($set[$cursor])) {
            $cursor = $this->previousActive($cursor, $activeDays);
        }

        $start = null;
        while (isset($set[$cursor])) {
            $start = $cursor;
            $cursor = $this->previousActive($cursor, $activeDays);
        }

        return $start;
    }

    /** @param  list<int>  $activeDays */
    public function isActive(string $date, array $activeDays): bool
    {
        return in_array(CarbonImmutable::parse($date)->dayOfWeekIso, $activeDays, true);
    }

    /** Último día activo estrictamente anterior a la fecha. @param list<int> $activeDays */
    public function previousActive(string $date, array $activeDays): string
    {
        $cursor = CarbonImmutable::parse($date)->subDay();
        for ($i = 0; $i < 7 && ! in_array($cursor->dayOfWeekIso, $activeDays, true); $i++) {
            $cursor = $cursor->subDay();
        }

        return $cursor->toDateString();
    }
}
