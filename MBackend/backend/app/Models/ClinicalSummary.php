<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ClinicalSummary extends Model
{
    protected $primaryKey = 'summary_id';

    protected $fillable = [
        'map_id',
        'therapist_id',
        'summary_text',
        'risk_status',
        'generated_at',
    ];

    protected function casts(): array
    {
        return ['generated_at' => 'datetime'];
    }

    public function emotionMap(): BelongsTo
    {
        return $this->belongsTo(EmotionMap::class, 'map_id', 'map_id');
    }

    public function therapist(): BelongsTo
    {
        return $this->belongsTo(Therapist::class, 'therapist_id', 'therapist_id');
    }
}
