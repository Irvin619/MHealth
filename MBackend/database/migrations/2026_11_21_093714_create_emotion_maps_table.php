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
        Schema::create('emotion_maps', function (Blueprint $table) {
            $table->id('map_id');
            $table->foreignId('client_id')->constrained('clients', 'client_id')->onDelete('cascade');
            $table->string('color_hex', 20);
            $table->unsignedTinyInteger('valence_score');
            $table->unsignedTinyInteger('intensity_level');
            $table->json('emotion_nodes');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('emotion_maps');
    }
};
