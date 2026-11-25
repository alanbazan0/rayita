<?php

namespace App\Models;

use Carbon\CarbonImmutable;
use Database\Factories\HabitFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['name', 'color', 'icon', 'goal_days', 'goal_start', 'goal_end', 'goal_on_fail', 'active_days'])]
class Habit extends Model
{
    /** @use HasFactory<HabitFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'goal_days' => 'integer',
            'goal_start' => 'date:Y-m-d',
            'goal_end' => 'date:Y-m-d',
            'active_days' => 'array',
        ];
    }

    /** Días de la semana (ISO 1–7) en que aplica el hábito; todos si no se definió. */
    public function activeDays(): array
    {
        $days = $this->active_days;

        return is_array($days) && $days !== [] ? array_values($days) : [1, 2, 3, 4, 5, 6, 7];
    }

    public function isActiveOn(string $date): bool
    {
        return in_array(CarbonImmutable::parse($date)->dayOfWeekIso, $this->activeDays(), true);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function logs(): HasMany
    {
        return $this->hasMany(HabitLog::class);
    }
}
