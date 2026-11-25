<?php

namespace Tests\Feature;

use App\Models\Habit;
use App\Models\HabitLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class HabitLogTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private Habit $habit;

    protected function setUp(): void
    {
        parent::setUp();
        Sanctum::actingAs($this->user = User::factory()->create());
        $this->habit = Habit::factory()->for($this->user)->create();
    }

    public function test_marcar_dia_como_cumplido_por_defecto(): void
    {
        $this->putJson("/api/habits/{$this->habit->id}/logs/2026-11-01")
            ->assertCreated()
            ->assertJson(['data' => ['date' => '2026-11-01', 'status' => 'done']]);
    }

    public function test_marcar_es_idempotente_y_actualiza_estado(): void
    {
        $url = "/api/habits/{$this->habit->id}/logs/2026-11-01";
        $this->putJson($url)->assertCreated();
        $this->putJson($url, ['status' => 'partial'])->assertOk()->assertJsonPath('data.status', 'partial');

        $this->assertSame(1, HabitLog::count());
    }

    public function test_estado_invalido(): void
    {
        $this->putJson("/api/habits/{$this->habit->id}/logs/2026-11-01", ['status' => 'nope'])
            ->assertUnprocessable()->assertJsonValidationErrors('status');
    }

    public function test_no_permite_dias_futuros(): void
    {
        $futuro = now()->addDays(5)->toDateString();

        $this->putJson("/api/habits/{$this->habit->id}/logs/{$futuro}")
            ->assertUnprocessable()->assertJsonValidationErrors('date');
    }

    public function test_fecha_con_formato_invalido_no_existe_la_ruta(): void
    {
        $this->putJson("/api/habits/{$this->habit->id}/logs/hoy")->assertNotFound();
    }

    public function test_fecha_imposible_es_rechazada(): void
    {
        $this->putJson("/api/habits/{$this->habit->id}/logs/2026-02-31")
            ->assertUnprocessable()->assertJsonValidationErrors('date');
    }

    public function test_desmarcar_dia(): void
    {
        HabitLog::factory()->for($this->habit)->create(['date' => '2026-11-01']);

        $this->deleteJson("/api/habits/{$this->habit->id}/logs/2026-11-01")->assertNoContent();
        $this->assertSame(0, HabitLog::count());
        // Desmarcar algo no marcado no falla.
        $this->deleteJson("/api/habits/{$this->habit->id}/logs/2026-11-01")->assertNoContent();
    }

    public function test_no_se_puede_marcar_habito_ajeno(): void
    {
        $ajeno = Habit::factory()->create();

        $this->putJson("/api/habits/{$ajeno->id}/logs/2026-11-01")->assertNotFound();
        $this->deleteJson("/api/habits/{$ajeno->id}/logs/2026-11-01")->assertNotFound();
        $this->assertSame(0, HabitLog::count());
    }

    public function test_listar_marcas_del_mes_solo_del_usuario(): void
    {
        HabitLog::factory()->for($this->habit)->create(['date' => '2026-11-03']);
        HabitLog::factory()->for($this->habit)->create(['date' => '2026-10-31']);
        HabitLog::factory()->create(['date' => '2026-11-03']); // de otro usuario

        $this->getJson('/api/logs?month=2026-11')
            ->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.date', '2026-11-03');
    }

    public function test_listar_filtra_por_habito(): void
    {
        $otro = Habit::factory()->for($this->user)->create();
        HabitLog::factory()->for($this->habit)->create(['date' => '2026-11-03']);
        HabitLog::factory()->for($otro)->create(['date' => '2026-11-04']);

        $this->getJson("/api/logs?month=2026-11&habit_id={$otro->id}")
            ->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.habit_id', $otro->id);
    }

    public function test_listar_requiere_mes_valido(): void
    {
        $this->getJson('/api/logs')->assertJsonValidationErrors('month');
        $this->getJson('/api/logs?month=noviembre')->assertJsonValidationErrors('month');
    }

    public function test_no_se_puede_marcar_un_dia_inactivo(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = Habit::factory()->for($user)->create(['active_days' => [1, 2, 3, 4, 5]]);

        // 2020-11-28 fue sábado.
        $this->putJson("/api/habits/{$habit->id}/logs/2020-11-28", ['status' => 'done'], ['Accept-Language' => 'es'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('date')
            ->assertJsonPath('errors.date.0', 'Ese día no está activo para este hábito. Cambia los días del hábito para poder marcarlo.');
        $this->assertDatabaseCount('habit_logs', 0);

        // 2020-11-27 fue viernes.
        $this->putJson("/api/habits/{$habit->id}/logs/2020-11-27", ['status' => 'done'])->assertCreated();
    }

    public function test_se_puede_quitar_una_marca_de_un_dia_que_ahora_es_inactivo(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = Habit::factory()->for($user)->create();
        $this->putJson("/api/habits/{$habit->id}/logs/2020-11-28", ['status' => 'done'])->assertCreated();

        $habit->update(['active_days' => [1, 2, 3, 4, 5]]);

        $this->deleteJson("/api/habits/{$habit->id}/logs/2020-11-28")->assertNoContent();
        $this->assertDatabaseCount('habit_logs', 0);
    }
}
