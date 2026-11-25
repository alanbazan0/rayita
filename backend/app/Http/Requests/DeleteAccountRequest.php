<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class DeleteAccountRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            // Se confirma escribiendo el correo de la cuenta (sirve también para cuentas de Google, sin contraseña).
            'email' => ['required', 'string', 'max:255'],
        ];
    }

    public function messages(): array
    {
        return [
            'email.required' => __('Escribe el correo de tu cuenta para confirmar.'),
        ];
    }
}
