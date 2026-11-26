<?php

namespace App\Http\Controllers;

use App\Exceptions\PurchaseException;
use App\Models\Purchase;
use App\Services\GooglePlayVerifier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class PurchaseController extends Controller
{
    /**
     * Valida con Google Play la compra de "quitar anuncios" y la liga a la cuenta.
     * Es idempotente: repetir la misma compra (por ejemplo al restaurar) responde igual.
     */
    public function verify(Request $request, GooglePlayVerifier $google): JsonResponse
    {
        $product = (string) config('services.google_play.remove_ads_product');

        $data = $request->validate([
            'product_id' => ['required', 'string', 'in:'.$product],
            'purchase_token' => ['required', 'string', 'max:512'],
        ]);

        $user = $request->user();

        $existing = Purchase::where('purchase_token', $data['purchase_token'])->first();
        if ($existing && $existing->user_id !== $user->id) {
            return response()->json(['message' => __('Esta compra ya está ligada a otra cuenta.')], 409);
        }

        if (! $existing) {
            try {
                $info = $google->verifyProduct($data['product_id'], $data['purchase_token']);
            } catch (PurchaseException $e) {
                Log::warning('Compra no validada: '.$e->getMessage());

                return $e->reason === PurchaseException::INVALID
                    ? response()->json(['message' => __('No pudimos confirmar la compra con Google Play.')], 422)
                    : response()->json(['message' => __('No se pudo validar la compra ahora. Inténtalo más tarde.')], 503);
            }

            Purchase::create([
                'user_id' => $user->id,
                'product_id' => $data['product_id'],
                'purchase_token' => $data['purchase_token'],
                'order_id' => $info['order_id'],
                'purchased_at' => $info['purchased_at'],
            ]);
        }

        return response()->json(['user' => $user->fresh()]);
    }
}
