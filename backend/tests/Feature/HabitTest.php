<?php

namespace Tests\Feature;

use App\Models\Habit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class HabitTest extends TestCase
{
    use RefreshDatabase;

    public function test_requiere_autenticacion(): void
    {
        $this->getJson('/api/habits')->assertUnauthorized();
        $this->postJson('/api/habits', ['name' => 'Leer'])->assertUnauthorized();
    }

    public function test_crear_habito(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $this->postJson('/api/habits', ['name' => 'Ir al gym', 'color' => '#FF8800', 'icon' => 'dumbbell'])
            ->assertCreated()
            ->assertJsonPath('data.name', 'Ir al gym')
            ->assertJsonPath('data.color', '#FF8800');

        $this->assertDatabaseHas('habits', ['user_id' => $user->id, 'name' => 'Ir al gym']);
    }

    public function test_color_e_icono_son_opcionales(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/habits', ['name' => 'Leer'])->assertCreated()
            ->assertJsonPath('data.color', null);
    }

    public function test_validaciones(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/habits', [])->assertJsonValidationErrors('name');
        $this->postJson('/api/habits', ['name' => str_repeat('a', 101)])->assertJsonValidationErrors('name');
        $this->postJson('/api/habits', ['name' => 'X', 'color' => 'rojo'])->assertJsonValidationErrors('color');
        $this->postJson('/api/habits', ['name' => 'X', 'icon' => str_repeat('a', 51)])->assertJsonValidationErrors('icon');
    }

    public function test_listar_solo_habitos_propios(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        Habit::factory()->for($user)->count(2)->create();
        Habit::factory()->create();

        $this->getJson('/api/habits')->assertOk()->assertJsonCount(2, 'data');
    }

    public function test_actualizar_y_borrar(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $habit = Habit::factory()->for($user)->create(['name' => 'Viejo']);

        $this->putJson("/api/habits/{$habit->id}", ['name' => 'Nuevo'])
            ->assertOk()->assertJsonPath('data.name', 'Nuevo');
        $this->deleteJson("/api/habits/{$habit->id}")->assertNoContent();
        $this->assertDatabaseMissing('habits', ['id' => $habit->id]);
    }

    public function test_editar_color_e_icono_y_quitar_icono(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $habit = Habit::factory()->for($user)->create(['name' => 'Leer', 'color' => '#111111', 'icon' => 'menu_book']);

        $this->putJson("/api/habits/{$habit->id}", ['name' => 'Leer', 'color' => '#22AA33', 'icon' => 'school'])
            ->assertOk()
            ->assertJsonPath('data.color', '#22AA33')
            ->assertJsonPath('data.icon', 'school');

        // Enviar icon: null lo quita.
        $this->putJson("/api/habits/{$habit->id}", ['name' => 'Leer', 'color' => '#22AA33', 'icon' => null])
            ->assertOk()->assertJsonPath('data.icon', null);
        $this->assertNull($habit->fresh()->icon);
    }

    public function test_actualizar_con_datos_invalidos(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $habit = Habit::factory()->for($user)->create();

        $this->putJson("/api/habits/{$habit->id}", ['name' => ''])->assertJsonValidationErrors('name');
        $this->putJson("/api/habits/{$habit->id}", ['color' => 'azul'])->assertJsonValidationErrors('color');
    }

    public function test_habito_ajeno_responde_404(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $ajeno = Habit::factory()->create();

        $this->getJson("/api/habits/{$ajeno->id}")->assertNotFound();
        $this->putJson("/api/habits/{$ajeno->id}", ['name' => 'X'])->assertNotFound();
        $this->deleteJson("/api/habits/{$ajeno->id}")->assertNotFound();
        $this->assertDatabaseHas('habits', ['id' => $ajeno->id]);
    }

    public function test_habito_inexistente_responde_404(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/habits/999')->assertNotFound();
    }

    public function test_crea_habito_con_meta_de_dias(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/habits', [
            'name' => 'No fumar',
            'goal_days' => 10,
            'goal_start' => '2026-11-24',
            'goal_on_fail' => 'accumulate',
        ])->assertCreated()
            ->assertJsonPath('data.goal_days', 10)
            ->assertJsonPath('data.goal_start', '2026-11-24')
            ->assertJsonPath('data.goal_end', null)
            ->assertJsonPath('data.goal_on_fail', 'accumulate');
    }

    public function test_meta_con_fechas_calcula_los_dias_y_reinicia_por_defecto(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/habits', [
            'name' => 'Reto',
            'goal_start' => '2026-11-01',
            'goal_end' => '2026-11-10',
        ])->assertCreated()
            ->assertJsonPath('data.goal_days', 10)
            ->assertJsonPath('data.goal_on_fail', 'reset');
    }

    public function test_fecha_final_anterior_a_la_inicial_es_invalida(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/habits', [
            'name' => 'Reto', 'goal_start' => '2026-11-10', 'goal_end' => '2026-11-01',
        ])->assertUnprocessable()->assertJsonValidationErrors('goal_end');
    }

    public function test_valida_limites_de_la_meta(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/habits', ['name' => 'X', 'goal_days' => 0])
            ->assertUnprocessable()->assertJsonValidationErrors('goal_days');
        $this->postJson('/api/habits', ['name' => 'X', 'goal_days' => 5, 'goal_on_fail' => 'otro'])
            ->assertUnprocessable()->assertJsonValidationErrors('goal_on_fail');
    }

    public function test_quitar_la_meta_y_no_tocarla_al_editar_otros_campos(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $id = $this->postJson('/api/habits', ['name' => 'X', 'goal_days' => 7, 'goal_start' => '2026-11-24'])
            ->json('data.id');

        $this->putJson("/api/habits/$id", ['name' => 'Y'])
            ->assertOk()->assertJsonPath('data.goal_days', 7);

        $this->putJson("/api/habits/$id", ['goal_days' => null, 'goal_end' => null])
            ->assertOk()
            ->assertJsonPath('data.goal_days', null)
            ->assertJsonPath('data.goal_start', null);
    }

    public function test_dias_activos_se_guardan_ordenados_y_todos_los_dias_es_null(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $id = $this->postJson('/api/habits', ['name' => 'Madrugar', 'active_days' => [5, 1, 3, 2, 4]])
            ->assertCreated()
            ->assertJsonPath('data.active_days', [1, 2, 3, 4, 5])
            ->json('data.id');

        $this->putJson("/api/habits/$id", ['active_days' => [1, 2, 3, 4, 5, 6, 7]])
            ->assertOk()
            ->assertJsonPath('data.active_days', [1, 2, 3, 4, 5, 6, 7]);
        $this->assertNull(Habit::find($id)->getRawOriginal('active_days'));
    }

    public function test_sin_dias_activos_el_habito_aplica_todos_los_dias(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/habits', ['name' => 'X'])
            ->assertCreated()->assertJsonPath('data.active_days', [1, 2, 3, 4, 5, 6, 7]);
    }

    public function test_valida_los_dias_activos(): void
    {
        Sanctum::actingAs(User::factory()->create());

        foreach ([[], [0], [8], [1, 1], 'lunes'] as $bad) {
            $this->postJson('/api/habits', ['name' => 'X', 'active_days' => $bad])
                ->assertUnprocessable();
        }
    }

    public function test_meta_por_fechas_cuenta_solo_dias_activos(): void
    {
        Sanctum::actingAs(User::factory()->create());

        // Dos semanas (lunes 30 nov a domingo 13 dic), solo lunes a viernes = 10 días.
        $this->postJson('/api/habits', [
            'name' => 'Levantarme a las 8',
            'active_days' => [1, 2, 3, 4, 5],
            'goal_start' => '2026-11-30',
            'goal_end' => '2026-12-13',
        ])->assertCreated()->assertJsonPath('data.goal_days', 10);
    }

    public function test_rango_sin_dias_activos_es_invalido(): void
    {
        Sanctum::actingAs(User::factory()->create());

        // Sábado 28 y domingo 29 con hábito de lunes a viernes.
        $this->postJson('/api/habits', [
            'name' => 'X', 'active_days' => [1, 2, 3, 4, 5], 'goal_start' => '2026-11-28', 'goal_end' => '2026-11-29',
        ])->assertUnprocessable()->assertJsonValidationErrors('goal_end');
    }

    public function test_cambiar_los_dias_recalcula_una_meta_por_fechas(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $id = $this->postJson('/api/habits', ['name' => 'X', 'goal_start' => '2026-11-30', 'goal_end' => '2026-12-13'])
            ->assertJsonPath('data.goal_days', 14)->json('data.id');

        $this->putJson("/api/habits/$id", ['active_days' => [1, 2, 3, 4, 5]])
            ->assertOk()->assertJsonPath('data.goal_days', 10);
    }

    public function test_meta_por_dias_nueva_empieza_hoy_segun_el_cliente(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/habits', ['name' => 'No fumar', 'goal_days' => 10, 'today' => '2026-11-24'])
            ->assertCreated()
            ->assertJsonPath('data.goal_start', '2026-11-24')
            ->assertJsonPath('data.goal_days', 10);
    }

    public function test_meta_por_dias_sin_inicio_arranca_en_la_racha_actual(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = Habit::factory()->for($user)->create();
        foreach (['2026-11-22', '2026-11-23'] as $date) {
            $habit->logs()->create(['date' => $date, 'status' => 'done']);
        }

        // Dos días de racha ya cumplidos: la meta debe contarlos (2 de 10).
        $this->putJson("/api/habits/{$habit->id}", ['goal_days' => 10, 'today' => '2026-11-24'])
            ->assertOk()
            ->assertJsonPath('data.goal_start', '2026-11-22');

        $this->getJson("/api/habits/{$habit->id}/stats?today=2026-11-24")
            ->assertJsonPath('goal.progress', 2)
            ->assertJsonPath('goal.target', 10);
    }

    public function test_meta_por_dias_sin_racha_viva_empieza_hoy(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = Habit::factory()->for($user)->create();
        $habit->logs()->create(['date' => '2026-11-10', 'status' => 'done']); // racha ya perdida

        $this->putJson("/api/habits/{$habit->id}", ['goal_days' => 10, 'today' => '2026-11-24'])
            ->assertOk()
            ->assertJsonPath('data.goal_start', '2026-11-24');
    }

    public function test_el_inicio_explicito_de_la_meta_se_respeta(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = Habit::factory()->for($user)->create();
        $habit->logs()->create(['date' => '2026-11-23', 'status' => 'done']);

        $this->putJson("/api/habits/{$habit->id}", ['goal_days' => 10, 'goal_start' => '2026-11-24', 'today' => '2026-11-24'])
            ->assertOk()
            ->assertJsonPath('data.goal_start', '2026-11-24');
    }

    public function test_el_inicio_por_racha_respeta_los_dias_activos(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $habit = Habit::factory()->for($user)->create(['active_days' => [1, 2, 3, 4, 5]]);
        // Jueves 26 y viernes 27; el lunes 30 es hoy y aún no se marca.
        foreach (['2026-11-26', '2026-11-27'] as $date) {
            $habit->logs()->create(['date' => $date, 'status' => 'done']);
        }

        $this->putJson("/api/habits/{$habit->id}", ['goal_days' => 5, 'today' => '2026-11-30'])
            ->assertOk()
            ->assertJsonPath('data.goal_start', '2026-11-26');
    }

    public function test_today_invalido_se_rechaza(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/habits', ['name' => 'X', 'today' => 'ayer'])
            ->assertUnprocessable()->assertJsonValidationErrors('today');
    }
}
