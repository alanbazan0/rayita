<?php

namespace Tests\Feature;

use App\Models\Habit;
use App\Models\HabitLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** "Cuaderno de rayitas": historial por mes y primera marca dentro de las estadísticas. */
class HabitHistoryTest extends TestCase
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

    private function stats(string $query = '?today=2026-11-25'): TestResponse
    {
        return $this->getJson("/api/habits/{$this->habit->id}/stats{$query}")->assertOk();
    }

    public function test_sin_marcas_no_hay_historial_ni_primera_fecha(): void
    {
        $this->stats()
            ->assertJsonPath('since', null)
            ->assertJsonPath('history', []);
    }

    public function test_agrupa_los_dias_cumplidos_por_mes_del_mas_reciente_al_mas_antiguo(): void
    {
        foreach (['2026-09-10', '2026-09-11'] as $d) {
            $this->mark($d);
        }
        foreach (range(1, 7) as $day) {
            $this->mark(sprintf('2026-10-%02d', $day));
        }
        foreach (['2026-11-23', '2026-11-24', '2026-11-25'] as $d) {
            $this->mark($d);
        }

        $this->stats()
            ->assertJsonPath('history.0.month', '2026-11')
            ->assertJsonPath('history.0.done', 3)
            ->assertJsonPath('history.0.tally', ['total' => 3, 'groups' => 0, 'remainder' => 3])
            ->assertJsonPath('history.1.month', '2026-10')
            ->assertJsonPath('history.1.tally', ['total' => 7, 'groups' => 1, 'remainder' => 2])
            ->assertJsonPath('history.2.month', '2026-09')
            ->assertJsonPath('history.2.done', 2)
            ->assertJsonCount(3, 'history');
    }

    public function test_el_historial_no_depende_del_mes_pedido(): void
    {
        $this->mark('2026-10-05');
        $this->mark('2026-11-23');

        $this->stats('?today=2026-11-25&month=2026-10')->assertJsonCount(2, 'history');
        $this->stats('?today=2026-11-25&month=2026-11')->assertJsonCount(2, 'history');
    }

    public function test_las_marcas_parciales_no_suman_rayitas_pero_si_marcan_el_inicio(): void
    {
        $this->mark('2026-11-20', partial: true);
        $this->mark('2026-11-23');

        $response = $this->stats();
        $response->assertJsonPath('history.0.done', 1)->assertJsonCount(1, 'history');
        // El hábito empieza en su primera marca, sea cumplida o parcial.
        $response->assertJsonPath('since', '2026-11-20');
    }

    public function test_since_es_la_primera_marca_aunque_se_registre_despues(): void
    {
        // Se creó el 25, pero se registraron días atrás: empieza el 23.
        $this->mark('2026-11-25');
        $this->mark('2026-11-23');
        $this->mark('2026-11-24');

        $this->stats()->assertJsonPath('since', '2026-11-23');
    }

    public function test_solo_cuenta_las_marcas_del_propio_habito(): void
    {
        $other = Habit::factory()->for($this->habit->user)->create();
        HabitLog::factory()->for($other)->create(['date' => '2026-01-01']);
        $this->mark('2026-11-23');

        $this->stats()
            ->assertJsonPath('since', '2026-11-23')
            ->assertJsonCount(1, 'history');
    }

    public function test_sigue_incluyendo_lo_de_siempre(): void
    {
        $this->mark('2026-11-24');
        $this->mark('2026-11-25');

        $this->stats()
            ->assertJsonPath('current_streak', 2)
            ->assertJsonPath('month.done', 2)
            ->assertJsonPath('total.done', 2);
    }

    public function test_no_se_puede_ver_el_historial_de_otro_usuario(): void
    {
        $stranger = Habit::factory()->for(User::factory()->create())->create();

        $this->getJson("/api/habits/{$stranger->id}/stats")->assertNotFound();
    }
}
