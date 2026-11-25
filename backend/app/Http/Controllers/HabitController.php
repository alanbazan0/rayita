<?php

namespace App\Http\Controllers;

use App\Http\Requests\HabitRequest;
use App\Http\Resources\HabitResource;
use App\Models\Habit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class HabitController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return HabitResource::collection(
            $request->user()->habits()->orderBy('created_at')->orderBy('id')->get()
        );
    }

    public function store(HabitRequest $request): JsonResponse
    {
        $habit = $request->user()->habits()->create($request->habitData());

        return (new HabitResource($habit))->response()->setStatusCode(201);
    }

    public function show(Request $request, Habit $habit): HabitResource
    {
        $this->ensureOwner($request, $habit);

        return new HabitResource($habit);
    }

    public function update(HabitRequest $request, Habit $habit): HabitResource
    {
        $this->ensureOwner($request, $habit);
        $habit->update($request->habitData());

        return new HabitResource($habit);
    }

    public function destroy(Request $request, Habit $habit): JsonResponse
    {
        $this->ensureOwner($request, $habit);
        $habit->delete();

        return response()->json(null, 204);
    }

    /** Un hábito ajeno responde 404 para no revelar que existe. */
    private function ensureOwner(Request $request, Habit $habit): void
    {
        abort_unless($habit->user_id === $request->user()->id, 404);
    }
}
