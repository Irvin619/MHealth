<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ClinicalSummary;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SummaryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $therapist = $request->user()->therapist;

        if (! $therapist) {
            return response()->json(['message' => 'Only therapist accounts can view clinical summaries.'], 403);
        }

        $summaries = ClinicalSummary::with(['emotionMap.client'])
            ->latest('generated_at')
            ->paginate(20);

        return response()->json($summaries);
    }
}
