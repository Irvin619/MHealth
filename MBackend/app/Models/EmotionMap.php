<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class EmotionMap extends Model
{
    protected $primaryKey = 'map_id';

    protected $fillable = [
        'client_id',
        'color_hex',
        'valence_score',
        'intensity_level',
        'emotion_nodes',
    ];

    protected function casts(): array
    {
        return [
            'valence_score' => 'integer',
            'intensity_level' => 'integer',
            'emotion_nodes' => 'array',
        ];
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class, 'client_id', 'client_id');
    }

    public function clinicalSummary(): HasOne
    {
        return $this->hasOne(ClinicalSummary::class, 'map_id', 'map_id');
    }
}
