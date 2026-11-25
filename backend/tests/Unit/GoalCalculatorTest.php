<?php

namespace Tests\Unit;

use App\Models\Habit;
use App\Services\GoalCalculator;
use App\Services\StreakCalculator;
use Carbon\CarbonImmutable;
use PHPUnit\Framework\TestCase;

class GoalCalculatorTest extends TestCase
{
    private function habit(int $days, string $start, ?string $end = null, string $onFail = 'reset'): Habit
    {
        return (new Habit)->forceFill([
            'goal_days' => $days,
            'goal_start' => CarbonImmutable::parse($start),
            'goal_end' => $end ? CarbonImmutable::parse($end) : null,
            'goal_on_fail' => $onFail,
        ]);
    }

    private function calc(Habit $habit, array $dates, string $today): ?array
    {
        return (new GoalCalculator(new StreakCalculator))->evaluate($habit, $dates, CarbonImmutable::parse($today));
    }

    public function test_sin_meta_devuelve_null(): void
    {
        $this->assertNull($this->calc(new Habit, ['2026-11-01'], '2026-11-02'));
    }

    public function test_reinicia_con_la_racha_actual(): void
    {
        $r = $this->calc($this->habit(10, '2026-11-01'), ['2026-11-01', '2026-11-02', '2026-11-03'], '2026-11-03');
        $this->assertSame(3, $r['progress']);
        $this->assertSame('active', $r['status']);
        $this->assertNull($r['days_left']);
    }

    public function test_reinicia_al_fallar_un_dia(): void
    {
        $dates = ['2026-11-01', '2026-11-02', '2026-11-03', '2026-11-05'];
        $r = $this->calc($this->habit(10, '2026-11-01'), $dates, '2026-11-05');
        $this->assertSame(1, $r['progress']);
    }

    public function test_acumula_sin_importar_los_huecos(): void
    {
        $dates = ['2026-11-01', '2026-11-02', '2026-11-03', '2026-11-05'];
        $r = $this->calc($this->habit(10, '2026-11-01', null, 'accumulate'), $dates, '2026-11-05');
        $this->assertSame(4, $r['progress']);
    }

    public function test_cumplida_al_llegar_al_objetivo(): void
    {
        $dates = ['2026-11-01', '2026-11-02', '2026-11-03'];
        $r = $this->calc($this->habit(3, '2026-11-01'), $dates, '2026-11-03');
        $this->assertSame('achieved', $r['status']);
        $this->assertSame(3, $r['progress']);
    }

    public function test_cumplida_se_mantiene_aunque_luego_falle(): void
    {
        $dates = ['2026-11-01', '2026-11-02', '2026-11-03'];
        $r = $this->calc($this->habit(3, '2026-11-01'), $dates, '2026-11-09');
        $this->assertSame('achieved', $r['status']);
    }

    public function test_ignora_marcas_anteriores_al_inicio(): void
    {
        $dates = ['2026-10-29', '2026-10-30', '2026-10-31'];
        $r = $this->calc($this->habit(5, '2026-11-01'), $dates, '2026-11-02');
        $this->assertSame(0, $r['progress']);
    }

    public function test_con_fechas_dias_restantes_y_fallida(): void
    {
        $habit = $this->habit(5, '2026-11-01', '2026-11-05');
        $r = $this->calc($habit, ['2026-11-01'], '2026-11-03');
        $this->assertSame(2, $r['days_left']);
        $this->assertSame('active', $r['status']);

        $r = $this->calc($habit, ['2026-11-01'], '2026-11-06');
        $this->assertSame('failed', $r['status']);
        $this->assertSame(0, $r['days_left']);
    }

    public function test_con_fechas_acumulando_ignora_marcas_posteriores_al_fin(): void
    {
        $habit = $this->habit(3, '2026-11-01', '2026-11-03', 'accumulate');
        $r = $this->calc($habit, ['2026-11-01', '2026-11-04', '2026-11-05'], '2026-11-06');
        $this->assertSame(1, $r['progress']);
        $this->assertSame('failed', $r['status']);
    }

    public function test_la_meta_solo_cuenta_dias_activos(): void
    {
        $habit = $this->habit(10, '2026-11-23')->forceFill(['active_days' => [1, 2, 3, 4, 5]]);
        // Lunes a viernes + lunes siguiente, con sábado/domingo sin marcar.
        $dates = ['2026-11-23', '2026-11-24', '2026-11-25', '2026-11-26', '2026-11-27', '2026-11-30'];
        $r = $this->calc($habit, $dates, '2026-11-30');
        $this->assertSame(6, $r['progress']);
        $this->assertSame('active', $r['status']);
    }

    public function test_marcas_en_fin_de_semana_no_suman_a_la_meta(): void
    {
        $habit = $this->habit(10, '2026-11-23', null, 'accumulate')->forceFill(['active_days' => [1, 2, 3, 4, 5]]);
        $r = $this->calc($habit, ['2026-11-23', '2026-11-28'], '2026-11-29');
        $this->assertSame(1, $r['progress']);
    }
}
