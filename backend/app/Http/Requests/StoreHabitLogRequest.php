<?php

namespace App\Http\Requests;

use App\Enums\LogStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreHabitLogRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $this->merge(['date' => $this->route('date')]);
    }

    public function rules(): array
    {
        return [
            // Se permite hasta mañana para tolerar husos horarios adelantados.
            'date' => ['required', 'date_format:Y-m-d', 'before_or_equal:tomorrow'],
            // El estado "parcial" ya no existe: solo se puede marcar un día como cumplido.
            'status' => ['sometimes', Rule::in([LogStatus::Done->value])],
        ];
    }

    public function messages(): array
    {
        return [
            'date.date_format' => __('La fecha debe tener formato AAAA-MM-DD.'),
            'date.before_or_equal' => __('No se pueden marcar días futuros.'),
            'status.in' => __('El estado debe ser "done".'),
        ];
    }
}
