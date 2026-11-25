<?php

namespace App\Http\Requests;

use App\Services\InviteCode;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'confirmed', Password::min(8)],
            // Solo se exige si el servidor tiene INVITE_CODE configurado.
            'invite_code' => [
                Rule::requiredIf(fn () => InviteCode::required()),
                'nullable',
                'string',
                function (string $attribute, mixed $value, \Closure $fail) {
                    if (InviteCode::required() && ! InviteCode::accepts($value)) {
                        $fail(__('El código de invitación no es válido.'));
                    }
                },
            ],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => __('El nombre es obligatorio.'),
            'email.required' => __('El correo es obligatorio.'),
            'email.email' => __('El correo no tiene un formato válido.'),
            'email.unique' => __('Ya existe una cuenta con ese correo.'),
            'invite_code.required' => __('El código de invitación es obligatorio.'),
            'password.required' => __('La contraseña es obligatoria.'),
            'password.confirmed' => __('Las contraseñas no coinciden.'),
            'password.min' => __('La contraseña debe tener al menos 8 caracteres.'),
        ];
    }
}
