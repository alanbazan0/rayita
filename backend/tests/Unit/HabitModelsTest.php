<?php

namespace Tests\Unit;

use App\Enums\LogStatus;
use App\Models\Habit;
use App\Models\HabitLog;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class HabitModelsTest extends TestCase
{
    use RefreshDatabase;

    public function test_usuario_tiene_habitos_y_habito_tiene_marcas(): void
    {
        $user = User::factory()->create();
        $habit = Habit::factory()->for($user)->create();
        HabitLog::factory()->for($habit)->create(['date' => '2026-11-01']);

        $this->assertTrue($user->habits->contains($habit));
        $this->assertTrue($habit->user->is($user));
        $this->assertCount(1, $habit->logs);
    }

    public function test_casts_de_fecha_y_estado(): void
    {
        $log = HabitLog::factory()->partial()->create(['date' => '2026-11-05'])->fresh();

        $this->assertSame(LogStatus::Partial, $log->status);
        $this->assertSame('2026-11-05', $log->date->toDateString());
    }

    public function test_scope_in_month_incluye_primer_y_ultimo_dia(): void
    {
        $habit = Habit::factory()->create();
        foreach (['2026-10-31', '2026-11-01', '2026-11-30', '2026-12-01'] as $d) {
            HabitLog::factory()->for($habit)->create(['date' => $d]);
        }

        $dates = HabitLog::inMonth('2026-11')->orderBy('date')->get()
            ->map(fn ($l) => $l->date->toDateString())->all();

        $this->assertSame(['2026-11-01', '2026-11-30'], $dates);
    }

    public function test_scope_done_excluye_parciales(): void
    {
        $habit = Habit::factory()->create();
        HabitLog::factory()->for($habit)->create(['date' => '2026-11-01']);
        HabitLog::factory()->for($habit)->partial()->create(['date' => '2026-11-02']);

        $this->assertSame(1, HabitLog::done()->count());
    }

    public function test_marca_unica_por_habito_y_dia(): void
    {
        $habit = Habit::factory()->create();
        HabitLog::factory()->for($habit)->create(['date' => '2026-11-01']);

        $this->expectException(UniqueConstraintViolationException::class);
        HabitLog::factory()->for($habit)->create(['date' => '2026-11-01']);
    }

    public function test_borrar_habito_borra_sus_marcas(): void
    {
        $habit = Habit::factory()->create();
        HabitLog::factory()->for($habit)->create(['date' => '2026-11-01']);

        $habit->delete();

        $this->assertSame(0, HabitLog::count());
    }
}
