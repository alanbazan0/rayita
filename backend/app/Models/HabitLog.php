<?php

namespace App\Models;

use App\Enums\LogStatus;
use Database\Factories\HabitLogFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['date', 'status'])]
class HabitLog extends Model
{
    /** @use HasFactory<HabitLogFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'date' => 'date:Y-m-d',
            'status' => LogStatus::class,
        ];
    }

    public function habit(): BelongsTo
    {
        return $this->belongsTo(Habit::class);
    }

    /** Solo las marcas de un mes dado (formato Y-m). */
    public function scopeInMonth(Builder $query, string $month): Builder
    {
        return $query->where('date', '>=', "{$month}-01")
            ->where('date', '<=', date('Y-m-t', strtotime("{$month}-01")));
    }

    public function scopeDone(Builder $query): Builder
    {
        return $query->where('status', LogStatus::Done->value);
    }
}
