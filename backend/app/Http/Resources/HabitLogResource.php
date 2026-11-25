<?php

namespace App\Http\Resources;

use App\Models\HabitLog;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin HabitLog */
class HabitLogResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'habit_id' => $this->habit_id,
            'date' => $this->date->toDateString(),
            'status' => $this->status->value,
        ];
    }
}
