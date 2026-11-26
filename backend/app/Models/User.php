<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password'])]
#[Hidden(['password', 'remember_token', 'google_id', 'email_verification_code', 'email_verification_expires_at', 'email_verification_attempts', 'email_verification_sent_at'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    public function hasVerifiedEmail(): bool
    {
        return $this->email_verified_at !== null;
    }

    /** Se incluye en el JSON del usuario para que la app sepa si debe mostrar anuncios. */
    protected $appends = ['ads_removed'];

    public function habits(): HasMany
    {
        return $this->hasMany(Habit::class);
    }

    public function purchases(): HasMany
    {
        return $this->hasMany(Purchase::class);
    }

    /** Si la cuenta tiene validada la compra de "quitar anuncios". */
    protected function adsRemoved(): Attribute
    {
        return Attribute::get(
            fn (): bool => $this->purchases()
                ->where('product_id', config('services.google_play.remove_ads_product'))
                ->exists()
        );
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'email_verification_expires_at' => 'datetime',
            'email_verification_sent_at' => 'datetime',
            'password' => 'hashed',
        ];
    }
}
