<?php

return [

    /*
    | Código de invitación para registrarse. Si está vacío, el registro es abierto.
    | Se lee aquí (y no con env() en el código) para que funcione con config:cache.
    */
    'invite_code' => env('INVITE_CODE'),

];
