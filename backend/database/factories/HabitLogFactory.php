<?php

namespace Database\Factories;

use App\Enums\LogStatus;
use App\Models\Habit;
use Illuminate\Database\Eloquent\Factories\Factory;

class HabitLogFactory extends Factory
{
    public function definition(): array
    {
        return [
            'habit_id' => Habit::factory(),
            'date' => fake()->date(),
            'status' => LogStatus::Done,
        ];
    }

    public function partial(): static
    {
        return $this->state(['status' => LogStatus::Partial]);
    }
}
