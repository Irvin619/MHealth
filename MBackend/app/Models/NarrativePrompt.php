<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NarrativePrompt extends Model
{
    protected $primaryKey = 'prompt_id';

    protected $fillable = [
        'client_id',
        'prompt_category',
        'disclosure_text',
    ];

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class, 'client_id', 'client_id');
    }
}
