<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Therapist;
use App\Support\MentalHealthSpecialization;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PatientSpecializationController extends Controller
{
    public function assign(Request $request): JsonResponse
    {
        abort_unless($request->user()->role === 'patient', 403, 'Only patients can select a specialization.');

        $validated = $request->validate([
            'specialization' => ['required', 'string', Rule::in(MentalHealthSpecialization::OPTIONS)],
        ]);

        $patient = $request->user()->client;
        if (! $patient) {
            return response()->json(['message' => 'The patient profile could not be found.'], 404);
        }

        $therapist = null;
        if ($patient->specialization === $validated['specialization'] && $patient->therapist_id !== null) {
            $therapist = Therapist::with('user')->find($patient->therapist_id);
        }

        $therapist ??= Therapist::query()
            ->with('user')
            ->withCount('patients')
            ->where('specialization', $validated['specialization'])
            ->orderBy('patients_count')
            ->orderBy('therapist_id')
            ->first();

        if (! $therapist) {
            return response()->json([
                'message' => 'No therapists are currently available for this specialization. Please try another.',
            ], 409);
        }

        $patient->forceFill([
            'specialization' => $validated['specialization'],
            'therapist_id' => $therapist->therapist_id,
        ])->save();

        return response()->json([
            'specialization' => $patient->specialization,
            'therapist' => [
                'name' => $therapist->user->name,
                'specialization' => $therapist->specialization,
                'license_number' => $therapist->license_number,
                'user_code' => $therapist->user->user_code,
            ],
        ]);
    }
}
