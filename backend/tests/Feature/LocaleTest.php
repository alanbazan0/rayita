<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LocaleTest extends TestCase
{
    use RefreshDatabase;

    public function test_sin_accept_language_responde_en_espanol(): void
    {
        // El cliente de pruebas manda en-us por defecto; se vacía el header.
        $this->postJson('/api/login', ['email' => 'a@example.com', 'password' => 'x'], ['Accept-Language' => ''])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Correo o contraseña incorrectos.');
    }

    public function test_responde_en_ingles_con_accept_language(): void
    {
        $this->postJson('/api/login', ['email' => 'a@example.com', 'password' => 'x'], ['Accept-Language' => 'en-US,en;q=0.9'])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Incorrect email or password.');
    }

    public function test_validaciones_se_traducen(): void
    {
        $this->postJson('/api/register', [], ['Accept-Language' => 'en'])
            ->assertJsonPath('errors.name.0', 'The name is required.');

        $this->postJson('/api/register', [], ['Accept-Language' => 'es'])
            ->assertJsonPath('errors.name.0', 'El nombre es obligatorio.');
    }

    public function test_idioma_no_soportado_cae_al_predeterminado(): void
    {
        $this->postJson('/api/register', [], ['Accept-Language' => 'fr-FR'])
            ->assertJsonPath('errors.name.0', 'El nombre es obligatorio.');
    }

    public function test_respeta_el_orden_de_preferencia(): void
    {
        $this->postJson('/api/register', [], ['Accept-Language' => 'fr, en;q=0.8, es;q=0.5'])
            ->assertJsonPath('errors.name.0', 'The name is required.');
    }
}
