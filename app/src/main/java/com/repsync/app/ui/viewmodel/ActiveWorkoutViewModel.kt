package com.repsync.app.ui.viewmodel

import com.repsync.app.data.RestTimerPreferences
import com.repsync.app.data.entity.ExerciseTrackingType
import com.repsync.app.data.entity.PreviousSetResult

data class ActiveSetUiModel(
    val orderIndex: Int,
    val weight: String = "",
    val reps: String = "",
    val durationMinutes: String = "",
    val durationSeconds: String = "",
    val distance: String = "",
    val speed: String = "",
    val previous: PreviousSetResult? = null,
    val isCompleted: Boolean = false,
)

data class ActiveExerciseUiModel(
    val id: String = java.util.UUID.randomUUID().toString(),
    val name: String = "",
    val trackingType: ExerciseTrackingType = ExerciseTrackingType.WEIGHT_REPS,
    val isTrackingTypeEditable: Boolean = true,
    val sets: List<ActiveSetUiModel> = listOf(ActiveSetUiModel(orderIndex = 0)),
)

data class ActiveWorkoutUiState(
    val workoutName: String = "",
    val exercises: List<ActiveExerciseUiModel> = emptyList(),
    val elapsedSeconds: Long = 0,
    val isLoading: Boolean = true,
    val showCancelDialog: Boolean = false,
    val showFinishDialog: Boolean = false,
    val showIncompleteFinishDialog: Boolean = false,
    val isFinished: Boolean = false,
    val isCancelled: Boolean = false,
    val templateId: Long? = null,
    val isQuickWorkout: Boolean = false,
    val restTimerSecondsRemaining: Int = 0,
    val restTimerDurationSeconds: Int = RestTimerPreferences.DEFAULT_DURATION_SECONDS,
    val showRestTimerDialog: Boolean = false,
    val exerciseNameSuggestions: List<String> = emptyList(),
)
