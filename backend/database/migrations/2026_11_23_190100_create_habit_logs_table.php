<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('habit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('habit_id')->constrained()->cascadeOnDelete();
            $table->date('date');
            $table->string('status', 20)->default('done');
            $table->timestamps();

            // Una sola marca por hábito y día.
            $table->unique(['habit_id', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('habit_logs');
    }
};
