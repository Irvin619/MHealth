<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Client extends Model
{
    protected $primaryKey = 'client_id';

    protected $fillable = [
        'user_id',
        'anonymous_alias',
        'emotional_literacy_score',
    ];

    protected function casts(): array
    {
        return ['emotional_literacy_score' => 'integer'];
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
}
