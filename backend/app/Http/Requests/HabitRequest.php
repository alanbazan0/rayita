<?php

namespace App\Http\Requests;

use App\Models\Habit;
use App\Services\StreakCalculator;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class HabitRequest extends FormRequest
{
    public function rules(): array
    {
        // En PUT/PATCH los campos son opcionales; en POST el nombre es obligatorio.
        $required = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'name' => [$required, 'string', 'max:100'],
            'color' => ['nullable', 'string', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'icon' => ['nullable', 'string', 'max:50'],
            'active_days' => ['nullable', 'array', 'min:1'],
            'active_days.*' => ['integer', 'between:1,7', 'distinct'],
            'goal_days' => ['nullable', 'integer', 'min:1', 'max:3650'],
            'goal_start' => ['nullable', 'date_format:Y-m-d'],
            'goal_end' => ['nullable', 'date_format:Y-m-d'],
            'goal_on_fail' => ['nullable', 'in:reset,accumulate'],
        ];
    }

    public function after(): array
    {
        return [function (Validator $validator) {
            $start = $this->input('goal_start');
            $end = $this->input('goal_end');
            if (! $end || $validator->errors()->hasAny(['goal_start', 'goal_end', 'active_days', 'active_days.*'])) {
                return;
            }
            $start ??= now()->toDateString();

            if ($end < $start) {
                $validator->errors()->add('goal_end', __('La fecha final debe ser igual o posterior a la inicial.'));
            } elseif (CarbonImmutable::parse($start)->diffInDays(CarbonImmutable::parse($end)) >= 3650) {
                $validator->errors()->add('goal_end', __('La meta no puede superar 3650 días.'));
            } elseif ($this->countActiveDays($start, $end) === 0) {
                $validator->errors()->add('goal_end', __('El rango no incluye ningún día activo del hábito.'));
            }
        }];
    }

    /** Días activos efectivos: los enviados, o los del hábito que se edita. @return list<int> */
    private function effectiveActiveDays(): array
    {
        if ($this->has('active_days')) {
            $days = array_values(array_unique(array_map('intval', (array) $this->input('active_days'))));

            return $days === [] ? StreakCalculator::ALL_DAYS : $days;
        }

        $habit = $this->route('habit');

        return $habit instanceof Habit ? $habit->activeDays() : StreakCalculator::ALL_DAYS;
    }

    /** Cuántos días activos hay entre dos fechas (inclusive). */
    private function countActiveDays(string $start, string $end): int
    {
        $active = $this->effectiveActiveDays();
        $count = 0;
        for ($d = CarbonImmutable::parse($start); $d->toDateString() <= $end; $d = $d->addDay()) {
            if (in_array($d->dayOfWeekIso, $active, true)) {
                $count++;
            }
        }

        return $count;
    }

    /**
     * Datos del hábito normalizados: con fecha final los días de la meta se
     * calculan del rango (solo días activos); sin días ni fecha final la meta
     * se elimina; con los 7 días activos se guarda null.
     *
     * @return array<string, mixed>
     */
    public function habitData(): array
    {
        $data = $this->validated();

        if (array_key_exists('active_days', $data)) {
            $days = array_values(array_unique(array_map('intval', $data['active_days'] ?? [])));
            sort($days);
            $data['active_days'] = ($days === [] || count($days) === 7) ? null : $days;
        }

        $goalKeys = ['goal_days', 'goal_start', 'goal_end', 'goal_on_fail'];
        $habit = $this->route('habit');
        $existingEnd = $habit instanceof Habit ? $habit->goal_end?->toDateString() : null;

        if (! $this->hasAny($goalKeys)) {
            // Cambiar los días activos recalcula la meta por fechas ya guardada.
            if ($existingEnd !== null && array_key_exists('active_days', $data)) {
                $data['goal_days'] = $this->countActiveDays($habit->goal_start->toDateString(), $existingEnd);
            }

            return $data;
        }

        $start = $data['goal_start'] ?? null;
        $end = $data['goal_end'] ?? null;
        $days = $data['goal_days'] ?? null;

        if ($end === null && $days === null) {
            return [...$data, 'goal_days' => null, 'goal_start' => null, 'goal_end' => null, 'goal_on_fail' => null];
        }

        $start ??= now()->toDateString();
        if ($end !== null) {
            $days = $this->countActiveDays($start, $end);
        }

        return [
            ...$data,
            'goal_days' => (int) $days,
            'goal_start' => $start,
            'goal_end' => $end,
            'goal_on_fail' => $data['goal_on_fail'] ?? 'reset',
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => __('El nombre del hábito es obligatorio.'),
            'name.max' => __('El nombre no puede superar 100 caracteres.'),
            'color.regex' => __('El color debe tener formato hexadecimal, por ejemplo #4F46E5.'),
            'goal_days.integer' => __('La meta debe ser un número de días.'),
            'goal_days.min' => __('La meta debe ser de al menos 1 día.'),
            'goal_days.max' => __('La meta no puede superar 3650 días.'),
            'goal_start.date_format' => __('La fecha inicial debe tener formato AAAA-MM-DD.'),
            'goal_end.date_format' => __('La fecha final debe tener formato AAAA-MM-DD.'),
            'goal_on_fail.in' => __('Si fallas un día, la meta puede reiniciar o acumular.'),
            'active_days.array' => __('Los días activos deben ser una lista.'),
            'active_days.min' => __('Elige al menos un día de la semana.'),
            'active_days.*.between' => __('Los días activos deben ir del 1 (lunes) al 7 (domingo).'),
            'active_days.*.integer' => __('Los días activos deben ir del 1 (lunes) al 7 (domingo).'),
            'active_days.*.distinct' => __('Los días activos no pueden repetirse.'),
            'icon.max' => __('El ícono no puede superar 50 caracteres.'),
        ];
    }
}
