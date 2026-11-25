<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\EmotionMapController;
use App\Http\Controllers\Api\MessageController;
use App\Http\Controllers\Api\SummaryController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function (): void {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/emotion-maps', [EmotionMapController::class, 'store']);
    Route::get('/emotion-maps', [EmotionMapController::class, 'index']);
    Route::get('/summaries', [SummaryController::class, 'index']);
    Route::post('/messages', [MessageController::class, 'store']);
    Route::get('/messages/{userId}', [MessageController::class, 'index'])->whereNumber('userId');
});
