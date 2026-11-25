<?php

namespace App\Services;

use App\Models\ClinicalSummary;
use App\Models\EmotionMap;
use App\Models\NarrativePrompt;

class EmotionTriageService
{
    private const CRISIS_TERMS = [
        'suicid',
        'self-harm',
        'self harm',
        'kill myself',
        'end my life',
        'want to die',
        'overdose',
        'hurt myself',
        'crisis',
    ];

    public function triage(EmotionMap $emotionMap, ?NarrativePrompt $prompt = null): array
    {
        $disclosure = $prompt?->disclosure_text ?? '';
        $content = mb_strtolower($disclosure.' '.json_encode($emotionMap->emotion_nodes));

        foreach (self::CRISIS_TERMS as $term) {
            if (str_contains($content, $term)) {
                ClinicalSummary::create([
                    'map_id' => $emotionMap->map_id,
                    'summary_text' => 'Crisis indicators detected. Immediate human support may be needed.',
                    'risk_status' => 'high',
                    'generated_at' => now(),
                ]);

                return [
                    'crisis_override' => true,
                    'risk_status' => 'high',
                    'message' => 'Your response suggests you may need immediate support.',
                    'helplines' => [
                        [
                            'name' => '988 Suicide & Crisis Lifeline',
                            'region' => 'United States and Canada',
                            'call' => '988',
                            'text' => '988',
                        ],
                        [
                            'name' => 'Emergency services',
                            'region' => 'Other locations',
                            'instruction' => 'Contact your local emergency number or crisis service.',
                        ],
                    ],
                ];
            }
        }

        $riskStatus = $emotionMap->valence_score <= 3 || $emotionMap->intensity_level >= 8
            ? 'moderate'
            : 'low';

        $details = [
            'Color' => $emotionMap->color_hex,
            'Valence score' => $emotionMap->valence_score,
            'Intensity level' => $emotionMap->intensity_level,
            'Emotion nodes' => $emotionMap->emotion_nodes,
            'Prompt disclosure' => $disclosure !== '' ? $disclosure : null,
        ];

        $summary = ClinicalSummary::create([
            'map_id' => $emotionMap->map_id,
            'summary_text' => json_encode($details, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES),
            'risk_status' => $riskStatus,
            'generated_at' => now(),
        ]);

        return [
            'crisis_override' => false,
            'risk_status' => $riskStatus,
            'summary' => $summary,
        ];
    }
}
