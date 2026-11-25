<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/** Correo con el código de 6 dígitos para verificar la cuenta. */
class VerificationCodeMail extends Mailable
{
    public function __construct(
        public readonly string $code,
        public readonly string $userName,
        public readonly int $minutes,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: __('Tu código de verificación de Calendar Check'));
    }

    public function content(): Content
    {
        $name = e($this->userName);
        $code = e($this->code);
        $hello = e(__('Hola :name,', ['name' => $this->userName]));
        $intro = e(__('Usa este código para verificar tu correo en Calendar Check:'));
        $expires = e(__('El código vence en :minutes minutos. Si no creaste una cuenta, ignora este mensaje.', ['minutes' => $this->minutes]));

        $html = <<<HTML
<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#17262A">
  <h2 style="color:#5C5EDD;margin:0 0 16px">Calendar Check</h2>
  <p>{$hello}</p>
  <p>{$intro}</p>
  <p style="font-size:34px;font-weight:700;letter-spacing:8px;background:#F2F3F8;border-radius:12px;padding:16px;text-align:center">{$code}</p>
  <p style="color:#6B7A8F;font-size:13px">{$expires}</p>
</div>
HTML;

        return new Content(htmlString: $html);
    }
}
