<?php

namespace Tests\Feature;

use App\Models\Habit;
use App\Models\HabitLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DeleteAccountTest extends TestCase
{
    use RefreshDatabase;

    public function test_requiere_sesion(): void
    {
        $this->deleteJson('/api/me', ['email' => 'a@a.com'])->assertUnauthorized();
    }

    public function test_elimina_la_cuenta_con_sus_habitos_marcas_y_sesiones(): void
    {
        $user = User::factory()->create(['email' => 'ana@example.com']);
        $habit = Habit::factory()->for($user)->create();
        HabitLog::factory()->for($habit)->create(['date' => '2026-11-24']);
        $token = $user->createToken('app')->plainTextToken;

        $this->deleteJson('/api/me', ['email' => 'ana@example.com'], ['Authorization' => "Bearer $token", 'Accept-Language' => 'es'])
            ->assertOk()
            ->assertJsonPath('message', 'Tu cuenta fue eliminada.');

        $this->assertDatabaseMissing('users', ['id' => $user->id]);
        $this->assertDatabaseCount('habits', 0);
        $this->assertDatabaseCount('habit_logs', 0);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_el_correo_se_compara_sin_distinguir_mayusculas_ni_espacios(): void
    {
        $user = User::factory()->create(['email' => 'ana@example.com']);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/me', ['email' => '  ANA@Example.COM '])->assertOk();
        $this->assertDatabaseMissing('users', ['id' => $user->id]);
    }

    public function test_un_correo_distinto_no_elimina_nada(): void
    {
        $user = User::factory()->create(['email' => 'ana@example.com']);
        Habit::factory()->for($user)->create();
        Sanctum::actingAs($user);

        $this->deleteJson('/api/me', ['email' => 'otra@example.com'], ['Accept-Language' => 'es'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.email.0', 'El correo no coincide con el de tu cuenta.');

        $this->assertDatabaseHas('users', ['id' => $user->id]);
        $this->assertDatabaseCount('habits', 1);
    }

    public function test_exige_escribir_el_correo(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->deleteJson('/api/me', [])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_no_toca_a_otros_usuarios(): void
    {
        $ana = User::factory()->create(['email' => 'ana@example.com']);
        $luis = User::factory()->create(['email' => 'luis@example.com']);
        Habit::factory()->for($luis)->create();
        Sanctum::actingAs($ana);

        $this->deleteJson('/api/me', ['email' => 'ana@example.com'])->assertOk();

        $this->assertDatabaseHas('users', ['id' => $luis->id]);
        $this->assertDatabaseCount('habits', 1);
    }

    public function test_una_cuenta_sin_verificar_tambien_puede_eliminarse(): void
    {
        $user = User::factory()->unverified()->create(['email' => 'ana@example.com']);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/me', ['email' => 'ana@example.com'])->assertOk();
        $this->assertDatabaseMissing('users', ['id' => $user->id]);
    }

    public function test_una_cuenta_de_google_se_elimina_igual(): void
    {
        $user = User::factory()->create(['email' => 'ana@example.com', 'google_id' => 'g-123']);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/me', ['email' => 'ana@example.com'])->assertOk();
        $this->assertDatabaseMissing('users', ['google_id' => 'g-123']);
    }

    public function test_tras_eliminar_el_mismo_correo_puede_volver_a_registrarse(): void
    {
        config(['registration.invite_code' => null]);
        $user = User::factory()->create(['email' => 'ana@example.com']);
        Sanctum::actingAs($user);
        $this->deleteJson('/api/me', ['email' => 'ana@example.com'])->assertOk();

        $this->postJson('/api/register', [
            'name' => 'Ana', 'email' => 'ana@example.com', 'password' => 'secreto123', 'password_confirmation' => 'secreto123',
        ])->assertCreated();
    }
}
