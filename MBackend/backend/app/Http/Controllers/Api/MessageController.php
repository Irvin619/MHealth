<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Message;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MessageController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'receiver_id' => ['required', 'integer', 'exists:users,id'],
            'body' => ['required', 'string', 'max:10000'],
        ]);

        if ((int) $validated['receiver_id'] === (int) $request->user()->id) {
            return response()->json(['message' => 'You cannot send a message to yourself.'], 422);
        }

        $message = Message::create([
            'sender_id' => $request->user()->id,
            'receiver_id' => $validated['receiver_id'],
            'encrypted_body' => $validated['body'],
        ]);

        return response()->json([
            'message' => [
                'message_id' => $message->message_id,
                'sender_id' => $message->sender_id,
                'receiver_id' => $message->receiver_id,
                'body' => $message->encrypted_body,
                'sent_at' => $message->sent_at,
            ],
        ], 201);
    }

    public function index(Request $request, int $userId): JsonResponse
    {
        abort_unless(User::whereKey($userId)->exists(), 404);

        $messages = Message::query()
            ->where(function ($query) use ($request, $userId): void {
                $query->where('sender_id', $request->user()->id)
                    ->where('receiver_id', $userId);
            })
            ->orWhere(function ($query) use ($request, $userId): void {
                $query->where('sender_id', $userId)
                    ->where('receiver_id', $request->user()->id);
            })
            ->orderBy('sent_at')
            ->get()
            ->map(fn (Message $message): array => [
                'message_id' => $message->message_id,
                'sender_id' => $message->sender_id,
                'receiver_id' => $message->receiver_id,
                'body' => $message->encrypted_body,
                'sent_at' => $message->sent_at,
            ]);

        return response()->json(['data' => $messages]);
    }
}
