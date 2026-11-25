<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('habits', function (Blueprint $table) {
            // Meta opcional: N días desde goal_start, o un rango con goal_end.
            $table->unsignedSmallInteger('goal_days')->nullable();
            $table->date('goal_start')->nullable();
            $table->date('goal_end')->nullable();
            // Qué pasa si se falla un día: 'reset' (reinicia) o 'accumulate' (acumula).
            $table->string('goal_on_fail', 10)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('habits', function (Blueprint $table) {
            $table->dropColumn(['goal_days', 'goal_start', 'goal_end', 'goal_on_fail']);
        });
    }
};
