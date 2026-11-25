<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('habits', function (Blueprint $table) {
            // Días de la semana en que aplica el hábito (ISO: 1 = lunes … 7 = domingo).
            // null = todos los días.
            $table->json('active_days')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('habits', function (Blueprint $table) {
            $table->dropColumn('active_days');
        });
    }
};
