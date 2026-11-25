<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Elige el idioma de los mensajes según Accept-Language.
 * Idiomas soportados: es (por defecto) y en.
 */
class SetLocale
{
    public const SUPPORTED = ['es', 'en'];

    public function handle(Request $request, Closure $next): Response
    {
        app()->setLocale($this->resolve($request));

        return $next($request);
    }

    private function resolve(Request $request): string
    {
        $header = (string) $request->header('Accept-Language', '');

        // Se toma el primer idioma soportado en el orden en que viene el header.
        foreach (explode(',', $header) as $part) {
            $code = strtolower(substr(trim(explode(';', $part)[0]), 0, 2));
            if (in_array($code, self::SUPPORTED, true)) {
                return $code;
            }
        }

        return config('app.locale', 'es');
    }
}
