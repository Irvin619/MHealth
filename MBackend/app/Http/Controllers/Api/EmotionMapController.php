<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EmotionMap;
use App\Services\EmotionTriageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class EmotionMapController extends Controller
{
    public function store(Request $request, EmotionTriageService $triage): JsonResponse
    {
        $client = $request->user()->client;

        if (! $client) {
            return response()->json(['message' => 'Only patient accounts can submit emotion maps.'], 403);
        }

        $validated = $request->validate([
            'color_hex' => ['required', 'regex:/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/'],
            'valence_score' => ['required', 'integer', 'between:0,10'],
            'intensity_level' => ['required', 'integer', 'between:0,10'],
            'emotion_nodes' => ['required', 'array'],
            'emotion_nodes.*' => ['string', 'max:255'],
            'prompt' => ['required', 'array'],
            'prompt.prompt_category' => ['required', 'string', 'max:255'],
            'prompt.disclosure_text' => ['required', 'string', 'max:10000'],
        ]);

        [$emotionMap, $prompt, $result] = DB::transaction(function () use ($client, $validated, $triage): array {
            $emotionMap = $client->emotionMaps()->create([
                'color_hex' => $validated['color_hex'],
                'valence_score' => $validated['valence_score'],
                'intensity_level' => $validated['intensity_level'],
                'emotion_nodes' => $validated['emotion_nodes'],
            ]);

            $prompt = $client->narrativePrompts()->create($validated['prompt']);

            return [$emotionMap, $prompt, $triage->triage($emotionMap, $prompt)];
        });

        if ($result['crisis_override']) {
            return response()->json([
                ...$result,
                'emotion_map_id' => $emotionMap->map_id,
            ], 200);
        }

        return response()->json([
            'crisis_override' => false,
            'emotion_map' => $emotionMap,
            'prompt' => $prompt,
            'risk_status' => $result['risk_status'],
            'summary' => $result['summary'],
        ], 201);
    }

    public function index(Request $request): JsonResponse
    {
        $client = $request->user()->client;

        if (! $client) {
            return response()->json(['message' => 'Only patient accounts can view emotion map history.'], 403);
        }

        $maps = EmotionMap::where('client_id', $client->client_id)
            ->with(['clinicalSummary', 'client.narrativePrompts'])
            ->latest()
            ->paginate(20);

        return response()->json($maps);
    }
}
