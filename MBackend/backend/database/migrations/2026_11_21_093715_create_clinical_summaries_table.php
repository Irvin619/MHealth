<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('clinical_summaries', function (Blueprint $table) {
            $table->id('summary_id');
            $table->foreignId('map_id')->constrained('emotion_maps', 'map_id')->onDelete('cascade');
            $table->foreignId('therapist_id')->nullable()->constrained('therapists', 'therapist_id')->onDelete('set null');
            $table->text('summary_text');
            $table->string('risk_status')->default('low');
            $table->timestamp('generated_at')->useCurrent();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('clinical_summaries');
    }
};
