<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Message;
use App\Models\Therapist;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MHealthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_patient_registration_and_emotion_map_submission_create_a_summary(): void
    {
        $registration = $this->postJson('/api/register', [
            'name' => 'Test Patient',
            'email' => 'patient@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'role' => 'patient',
        ]);

        $registration->assertCreated()->assertJsonPath('user.role', 'patient');
        $registration->assertJsonMissingPath('user.user_code');
        $token = $registration->json('token');
        $client = Client::firstOrFail();
        $this->assertMatchesRegularExpression('/^[0-9]{5}$/', $client->user->user_code);

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

    public function test_emotion_map_submission_requires_context(): void
    {
        /** @var User $user */
        $user = User::factory()->create(['role' => 'patient']);
        Client::create(['user_id' => $user->id, 'anonymous_alias' => 'context-patient']);

        $this->actingAs($user, 'sanctum')->postJson('/api/emotion-maps', [
            'color_hex' => '#AABBCC',
            'valence_score' => 6,
            'intensity_level' => 4,
            'emotion_nodes' => ['calm'],
            'prompt' => [
                'prompt_category' => 'reflection',
                'disclosure_text' => '',
            ],
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('prompt.disclosure_text');
    }

    public function test_profile_returns_only_the_authenticated_users_account_details(): void
    {
        /** @var User $patient */
        $patient = User::factory()->create(['role' => 'patient']);
        Client::create([
            'user_id' => $patient->id,
            'anonymous_alias' => 'Quiet Willow',
            'has_custom_alias' => true,
            'specialization' => 'Trauma & PTSD',
        ]);
        /** @var User $therapist */
        $therapist = User::factory()->create(['role' => 'therapist']);
        Therapist::create([
            'user_id' => $therapist->id,
            'license_number' => 'LIC-PROFILE-001',
            'specialization' => 'Clinical Counselling (anxiety, depression)',
        ]);

        $this->getJson('/api/profile')->assertUnauthorized();

        $this->actingAs($patient, 'sanctum')
            ->getJson('/api/profile')
            ->assertOk()
            ->assertJsonPath('profile.name', $patient->name)
            ->assertJsonPath('profile.email', $patient->email)
            ->assertJsonPath('profile.role', 'patient')
            ->assertJsonPath('profile.user_code', $patient->user_code)
            ->assertJsonPath('profile.anonymous_alias', 'Quiet Willow')
            ->assertJsonPath('profile.specialization', 'Trauma & PTSD')
            ->assertJsonMissingPath('profile.password')
            ->assertJsonMissingPath('profile.license_number');

        $this->actingAs($therapist, 'sanctum')
            ->getJson('/api/profile')
            ->assertOk()
            ->assertJsonPath('profile.name', $therapist->name)
            ->assertJsonPath('profile.email', $therapist->email)
            ->assertJsonPath('profile.role', 'therapist')
            ->assertJsonPath('profile.user_code', $therapist->user_code)
            ->assertJsonPath('profile.license_number', 'LIC-PROFILE-001')
            ->assertJsonPath(
                'profile.specialization',
                'Clinical Counselling (anxiety, depression)',
            )
            ->assertJsonMissingPath('profile.password')
            ->assertJsonMissingPath('profile.anonymous_alias');
    }

    public function test_crisis_disclosure_returns_override_and_persists_high_risk_summary(): void
    {
        /** @var User $user */
        $user = User::factory()->create(['role' => 'patient']);
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
        $sender = User::factory()->create(['role' => 'patient']);
        /** @var User $receiver */
        $receiver = User::factory()->create(['role' => 'therapist']);
        $therapist = Therapist::create([
            'user_id' => $receiver->id,
            'license_number' => 'LIC-MESSAGE-001',
            'specialization' => 'Trauma & PTSD',
        ]);
        Client::create([
            'user_id' => $sender->id,
            'anonymous_alias' => 'message-patient',
            'has_custom_alias' => true,
            'specialization' => 'Trauma & PTSD',
            'therapist_id' => $therapist->therapist_id,
        ]);
        $response = $this->actingAs($sender, 'sanctum')->postJson('/api/messages', [
            'receiver_code' => $receiver->user_code,
            'body' => 'A private note',
        ]);

        $response->assertCreated()
            ->assertJsonPath('message.body', 'A private note')
            ->assertJsonMissingPath('message.sender_code')
            ->assertJsonMissingPath('message.receiver_code');
        $message = Message::firstOrFail();
        $this->assertNotSame('A private note', $message->getRawOriginal('encrypted_body'));
        $this->assertSame('A private note', $message->encrypted_body);

        $this->actingAs($sender, 'sanctum')
            ->getJson('/api/messages/'.$receiver->user_code)
            ->assertOk()
            ->assertJsonPath('data.0.body', 'A private note')
            ->assertJsonPath('data.0.is_mine', true)
            ->assertJsonPath('data.0.sender_code', null)
            ->assertJsonPath('data.0.receiver_code', $receiver->user_code);

        $this->actingAs($receiver, 'sanctum')
            ->getJson('/api/messages/'.$sender->user_code)
            ->assertOk()
            ->assertJsonPath('data.0.is_mine', false)
            ->assertJsonPath('data.0.sender_code', $sender->user_code)
            ->assertJsonPath('data.0.receiver_code', null);

        $this->actingAs($receiver, 'sanctum')
            ->getJson('/api/therapist/patients')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'message-patient')
            ->assertJsonPath('data.0.user_code', $sender->user_code)
            ->assertJsonMissing(['name' => $sender->name]);
    }

    public function test_patient_and_therapist_registrations_receive_unique_five_digit_codes(): void
    {
        $patient = $this->postJson('/api/register', [
            'name' => 'Test Patient',
            'email' => 'unique-patient@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'role' => 'patient',
        ])->assertCreated();

        $therapist = $this->postJson('/api/register', [
            'name' => 'Test Therapist',
            'email' => 'unique-therapist@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'role' => 'therapist',
            'license_number' => 'LIC-UNIQUE-001',
            'specialization' => 'Clinical Counselling (anxiety, depression)',
        ])->assertCreated();

        $patientCode = User::where('email', 'unique-patient@example.com')->value('user_code');
        $therapistCode = $therapist->json('user.user_code');
        $this->assertMatchesRegularExpression('/^[0-9]{5}$/', $patientCode);
        $this->assertMatchesRegularExpression('/^[0-9]{5}$/', $therapistCode);
        $this->assertNotSame($patientCode, $therapistCode);

        $this->expectException(QueryException::class);
        User::factory()->create(['user_code' => $patientCode]);
    }

    public function test_patient_is_assigned_a_matching_therapist_and_receives_their_details(): void
    {
        $specialization = 'Trauma & PTSD';
        $therapist = $this->postJson('/api/register', [
            'name' => 'Matching Therapist',
            'email' => 'matching-therapist@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'role' => 'therapist',
            'license_number' => 'LIC-MATCH-001',
            'specialization' => $specialization,
        ])->assertCreated();

        $patient = $this->postJson('/api/register', [
            'name' => 'Matching Patient',
            'email' => 'matching-patient@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'role' => 'patient',
            'anonymous_alias' => 'MJ Private',
        ])->assertCreated();

        $response = $this->withToken($patient->json('token'))
            ->postJson('/api/patient/specialization', [
                'specialization' => $specialization,
            ]);

        $response->assertOk()
            ->assertJsonPath('specialization', $specialization)
            ->assertJsonPath('therapist.name', 'Matching Therapist')
            ->assertJsonPath('therapist.specialization', $specialization)
            ->assertJsonPath('therapist.license_number', 'LIC-MATCH-001')
            ->assertJsonPath('therapist.user_code', $therapist->json('user.user_code'));

        $therapistProfile = Therapist::where('user_id', $therapist->json('user.id'))
            ->firstOrFail();
        $patientProfile = Client::where('user_id', $patient->json('user.id'))->firstOrFail();
        $this->assertSame($specialization, $patientProfile->specialization);
        $this->assertSame($therapistProfile->therapist_id, $patientProfile->therapist_id);
        $therapistUser = User::findOrFail($therapist->json('user.id'));
        $this->actingAs($therapistUser, 'sanctum')
            ->getJson('/api/therapist/patients')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'MJ Private')
            ->assertJsonPath('data.0.user_code', $patientProfile->user->user_code);
    }

    public function test_assigned_patient_without_custom_alias_is_listed_by_full_name(): void
    {
        /** @var User $patient */
        $patient = User::factory()->create(['role' => 'patient', 'name' => 'Morgan Patient']);
        /** @var User $therapistUser */
        $therapistUser = User::factory()->create(['role' => 'therapist']);
        $therapist = Therapist::create([
            'user_id' => $therapistUser->id,
            'license_number' => 'LIC-ALIAS-001',
            'specialization' => 'Trauma & PTSD',
        ]);
        Client::create([
            'user_id' => $patient->id,
            'anonymous_alias' => 'patient-abcdefghij',
            'therapist_id' => $therapist->therapist_id,
        ]);

        $this->actingAs($therapistUser, 'sanctum')
            ->getJson('/api/therapist/patients')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Morgan Patient');
    }

    public function test_patient_is_not_assigned_when_no_therapist_matches(): void
    {
        $specialization = 'Clinical Counselling (anxiety, depression)';
        $therapistUser = User::factory()->create(['role' => 'therapist']);
        Therapist::create([
            'user_id' => $therapistUser->id,
            'license_number' => 'LIC-OTHER-001',
            'specialization' => 'Trauma & PTSD',
        ]);
        $patient = $this->postJson('/api/register', [
            'name' => 'No Match Patient',
            'email' => 'no-match-patient@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'role' => 'patient',
        ])->assertCreated();

        $this->withToken($patient->json('token'))
            ->postJson('/api/patient/specialization', [
                'specialization' => $specialization,
            ])
            ->assertStatus(409)
            ->assertJsonPath(
                'message',
                'No therapists are currently available for this specialization. Please try another.',
            );

        $this->assertDatabaseHas('clients', [
            'user_id' => $patient->json('user.id'),
            'specialization' => null,
            'therapist_id' => null,
        ]);
    }

    public function test_messages_are_limited_to_patient_therapist_pairs(): void
    {
        /** @var User $patient */
        $patient = User::factory()->create(['role' => 'patient']);
        /** @var User $otherPatient */
        $otherPatient = User::factory()->create(['role' => 'patient']);

        $this->actingAs($patient, 'sanctum')
            ->postJson('/api/messages', [
                'receiver_code' => $otherPatient->user_code,
                'body' => 'A private note',
            ])
            ->assertForbidden();

        $therapist = User::factory()->create(['role' => 'therapist']);
        Therapist::create([
            'user_id' => $therapist->id,
            'license_number' => 'LIC-UNASSIGNED-001',
            'specialization' => 'Trauma & PTSD',
        ]);
        $this->actingAs($patient, 'sanctum')
            ->postJson('/api/messages', [
                'receiver_code' => $therapist->user_code,
                'body' => 'A private note',
            ])
            ->assertForbidden();

        $this->actingAs($patient, 'sanctum')
            ->getJson('/api/therapist/patients')
            ->assertForbidden();
    }
}
