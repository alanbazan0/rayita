<?php

namespace App\Http\Resources;

use App\Models\Habit;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Habit */
class HabitResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'color' => $this->color,
            'icon' => $this->icon,
            'active_days' => $this->activeDays(),
            'goal_days' => $this->goal_days,
            'goal_start' => $this->goal_start?->toDateString(),
            'goal_end' => $this->goal_end?->toDateString(),
            'goal_on_fail' => $this->goal_days ? ($this->goal_on_fail ?? 'reset') : null,
            'created_at' => $this->created_at,
        ];
    }
}
