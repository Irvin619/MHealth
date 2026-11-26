<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('user_code', 5)->nullable()->after('role');
        });

        foreach (DB::table('users')->select('id')->orderBy('id')->cursor() as $user) {
            do {
                $code = (string) random_int(10000, 99999);
            } while (DB::table('users')->where('user_code', $code)->exists());

            DB::table('users')->where('id', $user->id)->update(['user_code' => $code]);
        }

        DB::table('users')->where('role', 'client')->update(['role' => 'patient']);

        Schema::table('users', function (Blueprint $table): void {
            $table->string('role')->default('patient')->change();
            $table->string('user_code', 5)->unique()->change();
        });
    }

    public function down(): void
    {
        DB::table('users')->where('role', 'patient')->update(['role' => 'client']);

        Schema::table('users', function (Blueprint $table): void {
            $table->dropUnique('users_user_code_unique');
            $table->dropColumn('user_code');
            $table->string('role')->default('client')->change();
        });
    }
};
