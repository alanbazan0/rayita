<?php

namespace App\Services;

/**
 * Conteo estilo "palitos": grupos de 5 (4 rayas + 1 diagonal) y un resto.
 */
class TallyCalculator
{
    /** @return array{total: int, groups: int, remainder: int} */
    public function fromCount(int $count): array
    {
        $count = max(0, $count);

        return [
            'total' => $count,
            'groups' => intdiv($count, 5),
            'remainder' => $count % 5,
        ];
    }
}
