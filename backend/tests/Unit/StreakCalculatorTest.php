<?php

namespace Tests\Unit;

use App\Services\StreakCalculator;
use Carbon\CarbonImmutable;
use PHPUnit\Framework\TestCase;

class StreakCalculatorTest extends TestCase
{
    private StreakCalculator $calc;

    private CarbonImmutable $today;

    protected function setUp(): void
    {
        parent::setUp();
        $this->calc = new StreakCalculator;
        $this->today = CarbonImmutable::parse('2026-11-23');
    }

    public function test_sin_marcas_devuelve_cero(): void
    {
        $this->assertSame(['current' => 0, 'longest' => 0], $this->calc->calculate([], $this->today));
    }

    public function test_racha_actual_incluye_hoy(): void
    {
        $r = $this->calc->calculate(['2026-11-21', '2026-11-22', '2026-11-23'], $this->today);
        $this->assertSame(3, $r['current']);
        $this->assertSame(3, $r['longest']);
    }

    public function test_racha_sigue_viva_si_el_ultimo_dia_fue_ayer(): void
    {
        $r = $this->calc->calculate(['2026-11-21', '2026-11-22'], $this->today);
        $this->assertSame(2, $r['current']);
    }

    public function test_racha_actual_es_cero_si_se_salto_ayer_y_hoy(): void
    {
        $r = $this->calc->calculate(['2026-11-20', '2026-11-21'], $this->today);
        $this->assertSame(0, $r['current']);
        $this->assertSame(2, $r['longest']);
    }

    public function test_racha_mas_larga_puede_ser_anterior_a_la_actual(): void
    {
        $dates = ['2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04', '2026-11-22', '2026-11-23'];
        $r = $this->calc->calculate($dates, $this->today);
        $this->assertSame(2, $r['current']);
        $this->assertSame(4, $r['longest']);
    }

    public function test_fechas_desordenadas_y_duplicadas(): void
    {
        $r = $this->calc->calculate(['2026-11-23', '2026-11-22', '2026-11-23', '2026-11-21'], $this->today);
        $this->assertSame(3, $r['current']);
        $this->assertSame(3, $r['longest']);
    }

    public function test_racha_cruza_cambio_de_mes_y_de_anio(): void
    {
        $today = CarbonImmutable::parse('2027-01-02');
        $r = $this->calc->calculate(['2026-12-30', '2026-12-31', '2027-01-01', '2027-01-02'], $today);
        $this->assertSame(4, $r['current']);
    }

    public function test_dias_inactivos_no_rompen_la_racha(): void
    {
        // Viernes 27 y lunes 30; sábado y domingo no aplican.
        $r = (new StreakCalculator)->calculate(
            ['2026-11-26', '2026-11-27', '2026-11-30'],
            CarbonImmutable::parse('2026-11-30'),
            [1, 2, 3, 4, 5],
        );
        $this->assertSame(['current' => 3, 'longest' => 3], $r);
    }

    public function test_sin_dias_activos_el_fin_de_semana_si_la_rompe(): void
    {
        $r = (new StreakCalculator)->calculate(['2026-11-27', '2026-11-30'], CarbonImmutable::parse('2026-11-30'));
        $this->assertSame(1, $r['current']);
    }

    public function test_hoy_inactivo_mantiene_la_racha_si_el_ultimo_dia_activo_se_cumplio(): void
    {
        // Hoy es sábado: el viernes se cumplió, así que sigue viva.
        $r = (new StreakCalculator)->calculate(['2026-11-26', '2026-11-27'], CarbonImmutable::parse('2026-11-28'), [1, 2, 3, 4, 5]);
        $this->assertSame(2, $r['current']);

        // Si el viernes no se cumplió, se rompió.
        $r = (new StreakCalculator)->calculate(['2026-11-26'], CarbonImmutable::parse('2026-11-28'), [1, 2, 3, 4, 5]);
        $this->assertSame(0, $r['current']);
    }

    public function test_marcas_en_dias_inactivos_se_ignoran(): void
    {
        $r = (new StreakCalculator)->calculate(['2026-11-28', '2026-11-29'], CarbonImmutable::parse('2026-11-29'), [1, 2, 3, 4, 5]);
        $this->assertSame(['current' => 0, 'longest' => 0], $r);
    }

    public function test_inicio_de_la_racha_actual(): void
    {
        $c = new StreakCalculator;
        $hoy = CarbonImmutable::parse('2026-11-24');

        // Sin marcas: no hay racha.
        $this->assertNull($c->currentStreakStart([], $hoy));
        // Racha de 3 días que llega hasta hoy.
        $this->assertSame('2026-11-22', $c->currentStreakStart(['2026-11-22', '2026-11-23', '2026-11-24'], $hoy));
        // Sigue viva si el último día cumplido fue ayer.
        $this->assertSame('2026-11-22', $c->currentStreakStart(['2026-11-22', '2026-11-23'], $hoy));
        // Un hueco la corta: cuenta desde el día siguiente al hueco.
        $this->assertSame('2026-11-23', $c->currentStreakStart(['2026-11-20', '2026-11-23', '2026-11-24'], $hoy));
        // Si el último día fue anteayer, la racha ya se perdió.
        $this->assertNull($c->currentStreakStart(['2026-11-21', '2026-11-22'], $hoy));
    }

    public function test_inicio_de_la_racha_atraviesa_el_fin_de_semana_si_no_aplica(): void
    {
        // Viernes 27 y lunes 30 de noviembre de 2026; sábado y domingo no aplican.
        $inicio = (new StreakCalculator)->currentStreakStart(
            ['2026-11-26', '2026-11-27', '2026-11-30'],
            CarbonImmutable::parse('2026-11-30'),
            [1, 2, 3, 4, 5],
        );
        $this->assertSame('2026-11-26', $inicio);
    }

    public function test_inicio_de_la_racha_coincide_con_su_longitud(): void
    {
        $c = new StreakCalculator;
        $hoy = CarbonImmutable::parse('2026-11-24');
        $fechas = ['2026-11-18', '2026-11-20', '2026-11-21', '2026-11-22', '2026-11-23'];

        $inicio = $c->currentStreakStart($fechas, $hoy);
        $dias = CarbonImmutable::parse($inicio)->diffInDays($hoy);   // hasta hoy

        $this->assertSame('2026-11-20', $inicio);
        $this->assertSame($c->calculate($fechas, $hoy)['current'], (int) $dias);
    }
}
