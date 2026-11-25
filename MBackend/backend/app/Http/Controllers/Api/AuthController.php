<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', Password::defaults(), 'confirmed'],
            'role' => ['required', 'in:client,therapist'],
            'anonymous_alias' => ['sometimes', 'nullable', 'string', 'max:255', 'unique:clients,anonymous_alias'],
            'license_number' => ['required_if:role,therapist', 'prohibited_if:role,client', 'string', 'max:255', 'unique:therapists,license_number'],
            'specialization' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $user = DB::transaction(function () use ($validated): User {
            $user = User::create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'password' => Hash::make($validated['password']),
                'role' => $validated['role'],
            ]);

            if ($user->role === 'client') {
                $user->client()->create([
                    'anonymous_alias' => $validated['anonymous_alias'] ?? 'client-'.Str::lower(Str::random(10)),
                ]);
            } else {
                $user->therapist()->create([
                    'license_number' => $validated['license_number'],
                    'specialization' => $validated['specialization'] ?? null,
                ]);
            }

            return $user;
        });

        $token = $user->createToken('flutter')->plainTextToken;

        return response()->json([
            'user' => $user->load(['client', 'therapist']),
            'token' => $token,
            'token_type' => 'Bearer',
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $credentials['email'])->first();

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages(['email' => ['The provided credentials are incorrect.']]);
        }

        return response()->json([
            'user' => $user->load(['client', 'therapist']),
            'token' => $user->createToken('flutter')->plainTextToken,
            'token_type' => 'Bearer',
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['message' => 'Logged out successfully.']);
    }
}
