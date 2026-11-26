<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('clients', function (Blueprint $table): void {
            $table->boolean('has_custom_alias')->default(false);
        });

        DB::table('clients')
            ->select(['client_id', 'anonymous_alias'])
            ->orderBy('client_id')
            ->chunkById(100, function ($patients): void {
                foreach ($patients as $patient) {
                    if (! preg_match('/^patient-[a-z0-9]{10}$/D', $patient->anonymous_alias)) {
                        DB::table('clients')
                            ->where('client_id', $patient->client_id)
                            ->update(['has_custom_alias' => true]);
                    }
                }
            }, 'client_id');
    }

    public function down(): void
    {
        Schema::table('clients', function (Blueprint $table): void {
            $table->dropColumn('has_custom_alias');
        });
    }
};
