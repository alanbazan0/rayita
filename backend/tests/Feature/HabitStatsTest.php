<?php

namespace Tests\Feature;

use App\Models\Habit;
use App\Models\HabitLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class HabitStatsTest extends TestCase
{
    use RefreshDatabase;

    private Habit $habit;

    protected function setUp(): void
    {
        parent::setUp();
        Sanctum::actingAs($user = User::factory()->create());
        $this->habit = Habit::factory()->for($user)->create();
    }

    private function mark(string $date, bool $partial = false): void
    {
        $factory = HabitLog::factory()->for($this->habit);
        ($partial ? $factory->partial() : $factory)->create(['date' => $date]);
    }

    public function test_habito_sin_marcas(): void
    {
        $this->getJson("/api/habits/{$this->habit->id}/stats?today=2026-11-23")
            ->assertOk()
            ->assertJsonPath('current_streak', 0)
            ->assertJsonPath('longest_streak', 0)
            ->assertJsonPath('month.tally', ['total' => 0, 'groups' => 0, 'remainder' => 0]);
    }

    public function test_rachas_y_palitos(): void
    {
        // 7 días de noviembre cumplidos (22 y 23 son la racha actual) + 1 en octubre.
        foreach (['2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04', '2026-11-05', '2026-11-22', '2026-11-23', '2026-10-31'] as $d) {
            $this->mark($d);
        }
        $this->mark('2026-11-10', partial: true);

        $this->getJson("/api/habits/{$this->habit->id}/stats?today=2026-11-23")
            ->assertOk()
            ->assertJsonPath('current_streak', 2)
            // 10-31 + 11-01..11-05 son seis días seguidos.
            ->assertJsonPath('longest_streak', 6)
            ->assertJsonPath('month.done', 7)
            // Las marcas parciales antiguas ya no cuentan para nada.
            ->assertJsonPath('month.partial', 0)
            ->assertJsonPath('month.tally', ['total' => 7, 'groups' => 1, 'remainder' => 2])
            ->assertJsonPath('total.done', 8)
            ->assertJsonPath('total.tally', ['total' => 8, 'groups' => 1, 'remainder' => 3]);
    }

    public function test_parcial_no_cuenta_para_la_racha(): void
    {
        $this->mark('2026-11-22');
        $this->mark('2026-11-23', partial: true);

        $this->getJson("/api/habits/{$this->habit->id}/stats?today=2026-11-23")
            ->assertJsonPath('current_streak', 1);
    }

    public function test_mes_solicitado(): void
    {
        $this->mark('2026-10-01');
        $this->mark('2026-10-02');

        $this->getJson("/api/habits/{$this->habit->id}/stats?today=2026-11-23&month=2026-10")
            ->assertJsonPath('month.month', '2026-10')
            ->assertJsonPath('month.done', 2);
    }

    public function test_parametros_invalidos(): void
    {
        $this->getJson("/api/habits/{$this->habit->id}/stats?today=ayer")->assertJsonValidationErrors('today');
        $this->getJson("/api/habits/{$this->habit->id}/stats?month=2026")->assertJsonValidationErrors('month');
    }

    public function test_habito_ajeno_responde_404(): void
    {
        $ajeno = Habit::factory()->create();

        $this->getJson("/api/habits/{$ajeno->id}/stats")->assertNotFound();
    }

    public function test_stats_sin_meta(): void
    {
        $this->getJson("/api/habits/{$this->habit->id}/stats?today=2026-11-23")
            ->assertOk()->assertJsonPath('goal', null);
    }

    public function test_stats_incluye_el_avance_de_la_meta(): void
    {
        $this->habit->update(['goal_days' => 3, 'goal_start' => '2026-11-20', 'goal_on_fail' => 'reset']);
        $this->mark('2026-11-21');
        $this->mark('2026-11-22');

        $this->getJson("/api/habits/{$this->habit->id}/stats?today=2026-11-22")
            ->assertOk()
            ->assertJsonPath('goal.target', 3)
            ->assertJsonPath('goal.progress', 2)
            ->assertJsonPath('goal.status', 'active');
    }

    public function test_racha_atraviesa_el_fin_de_semana_si_no_aplica(): void
    {
        $this->habit->update(['active_days' => [1, 2, 3, 4, 5]]);
        $this->mark('2026-11-26');
        $this->mark('2026-11-27');
        $this->mark('2026-11-30');

        $this->getJson("/api/habits/{$this->habit->id}/stats?today=2026-11-30")
            ->assertOk()
            ->assertJsonPath('current_streak', 3)
            ->assertJsonPath('longest_streak', 3);
    }
}
