<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Client;
use App\Models\Message;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MessageController extends Controller
{
    public function assignedPatients(Request $request): JsonResponse
    {
        $therapist = $request->user()->therapist;
        if (! $therapist) {
            return response()->json(['message' => 'Only therapists can view assigned patients.'], 403);
        }

        $patients = $therapist->patients()
            ->with('user:id,name,user_code')
            ->orderBy('client_id')
            ->get()
            ->map(fn (Client $patient): array => [
                'name' => $patient->has_custom_alias
                    ? $patient->anonymous_alias
                    : $patient->user->name,
                'user_code' => $patient->user->user_code,
            ]);

        return response()->json(['data' => $patients]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'receiver_code' => ['required', 'string', 'regex:/^[0-9]{5}$/', 'exists:users,user_code'],
            'body' => ['required', 'string', 'max:10000'],
        ]);

        $sender = $request->user();
        $receiver = User::where('user_code', $validated['receiver_code'])->firstOrFail();
        $this->ensurePatientTherapistPair($sender, $receiver);

        $message = Message::create([
            'sender_id' => $sender->id,
            'receiver_id' => $receiver->id,
            'encrypted_body' => $validated['body'],
        ]);

        return response()->json([
            'message' => [
                'message_id' => $message->message_id,
                'body' => $message->encrypted_body,
                'sent_at' => $message->sent_at,
            ],
        ], 201);
    }

    public function index(Request $request, string $userCode): JsonResponse
    {
        $currentUser = $request->user();
        $otherUser = User::where('user_code', $userCode)->firstOrFail();
        $this->ensurePatientTherapistPair($currentUser, $otherUser);

        $messages = Message::query()
            ->with(['sender:id,user_code', 'receiver:id,user_code'])
            ->where(function ($query) use ($currentUser, $otherUser): void {
                $query->where('sender_id', $currentUser->id)
                    ->where('receiver_id', $otherUser->id);
            })
            ->orWhere(function ($query) use ($currentUser, $otherUser): void {
                $query->where('sender_id', $otherUser->id)
                    ->where('receiver_id', $currentUser->id);
            })
            ->orderBy('sent_at')
            ->get()
            ->map(fn (Message $message): array => [
                'message_id' => $message->message_id,
                'sender_code' => $message->sender_id === $currentUser->id
                    ? null
                    : $message->sender->user_code,
                'receiver_code' => $message->receiver_id === $currentUser->id
                    ? null
                    : $message->receiver->user_code,
                'is_mine' => $message->sender_id === $currentUser->id,
                'body' => $message->encrypted_body,
                'sent_at' => $message->sent_at,
            ]);

        return response()->json(['data' => $messages]);
    }

    private function ensurePatientTherapistPair(User $first, User $second): void
    {
        $validRoles = in_array($first->role, ['patient', 'therapist'], true)
            && in_array($second->role, ['patient', 'therapist'], true)
            && $first->role !== $second->role;
        abort_unless(
            $first->id !== $second->id && $validRoles,
            403,
            'Messages are available only between a patient and a therapist.',
        );

        $patient = $first->role === 'patient' ? $first : $second;
        $therapist = $first->role === 'therapist' ? $first : $second;
        abort_unless(
            $patient->client?->therapist_id !== null
                && $therapist->therapist?->therapist_id !== null
                && (int) $patient->client->therapist_id === (int) $therapist->therapist->therapist_id,
            403,
            'Messages are available only with your assigned therapist.',
        );
    }
}
