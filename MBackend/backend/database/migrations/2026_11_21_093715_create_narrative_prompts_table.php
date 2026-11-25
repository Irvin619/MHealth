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
        Schema::create('narrative_prompts', function (Blueprint $table) {
            $table->id('prompt_id');
            $table->foreignId('client_id')->constrained('clients', 'client_id')->onDelete('cascade');
            $table->string('prompt_category');
            $table->text('disclosure_text')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('narrative_prompts');
    }
};
