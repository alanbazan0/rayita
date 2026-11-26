<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('purchases', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // Producto de Google Play (por ahora solo "remove_ads").
            $table->string('product_id', 100);
            // Token de la compra: Google lo da una sola vez por compra, así que una misma
            // compra no puede estar ligada a dos cuentas.
            $table->string('purchase_token', 512)->unique();
            $table->string('order_id')->nullable();
            $table->timestamp('purchased_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'product_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('purchases');
    }
};
