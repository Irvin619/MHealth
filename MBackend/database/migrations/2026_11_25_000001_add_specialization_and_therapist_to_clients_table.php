<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('clients', function (Blueprint $table): void {
            $table->string('specialization')->nullable()->after('anonymous_alias');
            $table->foreignId('therapist_id')
                ->nullable()
                ->after('specialization')
                ->constrained('therapists', 'therapist_id')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('clients', function (Blueprint $table): void {
            $table->dropForeign(['therapist_id']);
            $table->dropColumn(['therapist_id', 'specialization']);
        });
    }
};
