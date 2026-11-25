<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Therapist extends Model
{
    protected $primaryKey = 'therapist_id';

    protected $fillable = [
        'user_id',
        'license_number',
        'specialization',
        'is_verified',
    ];

    protected function casts(): array
    {
        return ['is_verified' => 'boolean'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id', 'id');
    }

    public function clinicalSummaries(): HasMany
    {
        return $this->hasMany(ClinicalSummary::class, 'therapist_id', 'therapist_id');
    }
}
