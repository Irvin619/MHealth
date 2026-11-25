<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Message;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MHealthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_client_registration_and_emotion_map_submission_create_a_summary(): void
    {
        $registration = $this->postJson('/api/register', [
            'name' => 'Test Client',
            'email' => 'client@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'role' => 'client',
        ]);

        $registration->assertCreated()->assertJsonPath('user.role', 'client');
        $token = $registration->json('token');
        $client = Client::firstOrFail();

        $this->withToken($token)->postJson('/api/emotion-maps', [
            'color_hex' => '#AABBCC',
            'valence_score' => 6,
            'intensity_level' => 4,
            'emotion_nodes' => ['calm', 'focused'],
            'prompt' => [
                'prompt_category' => 'reflection',
                'disclosure_text' => 'I had a quiet day.',
            ],
        ])->assertCreated()
            ->assertJsonPath('crisis_override', false)
            ->assertJsonPath('risk_status', 'low');

        $this->assertDatabaseHas('emotion_maps', ['client_id' => $client->client_id]);
        $this->assertDatabaseHas('clinical_summaries', ['risk_status' => 'low']);
        $this->assertDatabaseHas('narrative_prompts', ['client_id' => $client->client_id]);
    }

    public function test_crisis_disclosure_returns_override_and_persists_high_risk_summary(): void
    {
        /** @var User $user */
        $user = User::factory()->create(['role' => 'client']);
        $client = Client::create(['user_id' => $user->id, 'anonymous_alias' => 'test-alias']);

        $this->actingAs($user, 'sanctum')->postJson('/api/emotion-maps', [
            'color_hex' => '#112233',
            'valence_score' => 1,
            'intensity_level' => 10,
            'emotion_nodes' => ['distressed'],
            'prompt' => [
                'prompt_category' => 'check-in',
                'disclosure_text' => 'I want to hurt myself.',
            ],
        ])->assertOk()
            ->assertJsonPath('crisis_override', true)
            ->assertJsonPath('risk_status', 'high')
            ->assertJsonStructure(['helplines']);

        $this->assertDatabaseHas('clinical_summaries', ['risk_status' => 'high']);
        $this->assertDatabaseHas('clients', ['client_id' => $client->client_id]);
    }

    public function test_message_body_is_encrypted_in_storage_and_decrypted_in_response(): void
    {
        /** @var User $sender */
        $sender = User::factory()->create();
        /** @var User $receiver */
        $receiver = User::factory()->create();
        $response = $this->actingAs($sender, 'sanctum')->postJson('/api/messages', [
            'receiver_id' => $receiver->id,
            'body' => 'A private note',
        ]);

        $response->assertCreated()->assertJsonPath('message.body', 'A private note');
        $message = Message::firstOrFail();
        $this->assertNotSame('A private note', $message->getRawOriginal('encrypted_body'));
        $this->assertSame('A private note', $message->encrypted_body);
    }
}
