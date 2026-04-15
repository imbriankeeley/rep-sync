package com.repsync.app.data.entity

enum class ExerciseTrackingType(
    val storageValue: String,
    val displayName: String,
) {
    WEIGHT_REPS("weight_reps", "Weight + Reps"),
    DURATION("duration", "Time"),
    DURATION_DISTANCE("duration_distance", "Time + Distance + Speed");

    companion object {
        fun fromStorage(value: String?): ExerciseTrackingType {
            return entries.firstOrNull { it.storageValue == value } ?: WEIGHT_REPS
        }
    }
}
