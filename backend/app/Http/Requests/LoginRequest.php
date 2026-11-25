<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ];
    }

    public function messages(): array
    {
        return [
            'email.required' => __('El correo es obligatorio.'),
            'email.email' => __('El correo no tiene un formato válido.'),
            'password.required' => __('La contraseña es obligatoria.'),
        ];
    }
}
