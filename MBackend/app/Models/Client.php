<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Client extends Model
{
    protected $primaryKey = 'client_id';

    protected $hidden = ['has_custom_alias'];

    protected $fillable = [
        'user_id',
        'anonymous_alias',
        'has_custom_alias',
        'emotional_literacy_score',
        'specialization',
        'therapist_id',
    ];

    protected function casts(): array
    {
        return [
            'emotional_literacy_score' => 'integer',
            'has_custom_alias' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id', 'id');
    }

    public function emotionMaps(): HasMany
    {
        return $this->hasMany(EmotionMap::class, 'client_id', 'client_id');
    }

    public function narrativePrompts(): HasMany
    {
        return $this->hasMany(NarrativePrompt::class, 'client_id', 'client_id');
    }

    public function therapist(): BelongsTo
    {
        return $this->belongsTo(Therapist::class, 'therapist_id', 'therapist_id');
    }
}
