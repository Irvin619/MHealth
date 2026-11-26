<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\EmotionMapController;
use App\Http\Controllers\Api\MessageController;
use App\Http\Controllers\Api\PatientSpecializationController;
use App\Http\Controllers\Api\SummaryController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function (): void {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/profile', [AuthController::class, 'profile']);
    Route::post('/patient/specialization', [PatientSpecializationController::class, 'assign']);
    Route::post('/emotion-maps', [EmotionMapController::class, 'store']);
    Route::get('/emotion-maps', [EmotionMapController::class, 'index']);
    Route::get('/summaries', [SummaryController::class, 'index']);
    Route::post('/messages', [MessageController::class, 'store']);
    Route::get('/messages/{userCode}', [MessageController::class, 'index'])->where('userCode', '[0-9]{5}');
    Route::get('/therapist/patients', [MessageController::class, 'assignedPatients']);
});
