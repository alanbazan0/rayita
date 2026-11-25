<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class GoogleLoginRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'id_token' => ['required', 'string', 'max:8192'],
            // Solo se usa si la cuenta es nueva y el servidor exige invitación.
            'invite_code' => ['nullable', 'string', 'max:64'],
        ];
    }

    public function messages(): array
    {
        return [
            'id_token.required' => __('Falta el token de Google.'),
        ];
    }
}
