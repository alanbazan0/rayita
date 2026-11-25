<?php

namespace Tests\Unit;

use App\Services\TallyCalculator;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class TallyCalculatorTest extends TestCase
{
    #[DataProvider('cases')]
    public function test_agrupa_en_cincos(int $count, int $groups, int $remainder): void
    {
        $this->assertSame(
            ['total' => $count, 'groups' => $groups, 'remainder' => $remainder],
            (new TallyCalculator)->fromCount($count),
        );
    }

    public static function cases(): array
    {
        return [
            'cero' => [0, 0, 0],
            'cuatro' => [4, 0, 4],
            'cinco exactos' => [5, 1, 0],
            'diecisiete' => [17, 3, 2],
            'treinta' => [30, 6, 0],
        ];
    }

    public function test_negativos_se_tratan_como_cero(): void
    {
        $this->assertSame(['total' => 0, 'groups' => 0, 'remainder' => 0], (new TallyCalculator)->fromCount(-3));
    }
}
