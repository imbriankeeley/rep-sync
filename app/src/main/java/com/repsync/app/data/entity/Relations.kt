package com.repsync.app.data.entity

import androidx.room.Embedded
import androidx.room.Relation

data class ExerciseWithSets(
    @Embedded val exercise: ExerciseEntity,
    @Relation(
        parentColumn = "id",
        entityColumn = "exerciseId"
    )
    val sets: List<ExerciseSetEntity>
)

data class WorkoutWithExercises(
    @Embedded val workout: WorkoutEntity,
    @Relation(
        entity = ExerciseEntity::class,
        parentColumn = "id",
        entityColumn = "workoutId"
    )
    val exercises: List<ExerciseWithSets>
)

data class CompletedExerciseWithSets(
    @Embedded val exercise: CompletedExerciseEntity,
    @Relation(
        parentColumn = "id",
        entityColumn = "completedExerciseId"
    )
    val sets: List<CompletedSetEntity>
)

data class CompletedWorkoutWithExercises(
    @Embedded val workout: CompletedWorkoutEntity,
    @Relation(
        entity = CompletedExerciseEntity::class,
        parentColumn = "id",
        entityColumn = "completedWorkoutId"
    )
    val exercises: List<CompletedExerciseWithSets>
)

data class PreviousSetResult(
    val trackingType: String,
    val weight: Double?,
    val reps: Int?,
    val durationSeconds: Int?,
    val distanceMiles: Double?,
    val speedMph: Double?,
)

data class ExerciseHistoryRow(
    val date: String,
    val workoutName: String,
    val trackingType: String,
    val weight: Double?,
    val reps: Int?,
    val orderIndex: Int,
    val durationSeconds: Int?,
    val distanceMiles: Double?,
    val speedMph: Double?,
)
