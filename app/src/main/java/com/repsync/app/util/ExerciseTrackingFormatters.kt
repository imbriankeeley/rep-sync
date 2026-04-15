package com.repsync.app.util

import com.repsync.app.data.entity.ExerciseTrackingType

fun formatWeightValue(weight: Double): String {
    return if (weight == weight.toLong().toDouble()) {
        weight.toLong().toString()
    } else {
        "%.1f".format(weight)
    }
}

fun formatDistanceMiles(distanceMiles: Double): String {
    return if (distanceMiles == distanceMiles.toLong().toDouble()) {
        distanceMiles.toLong().toString()
    } else {
        "%.2f".format(distanceMiles)
    }
}

fun formatSpeedMph(speedMph: Double): String {
    return if (speedMph == speedMph.toLong().toDouble()) {
        speedMph.toLong().toString()
    } else {
        "%.1f".format(speedMph)
    }
}

fun formatDurationValue(totalSeconds: Int): String {
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%d:%02d".format(minutes, seconds)
}

fun formatTrackedSetSummary(
    trackingType: ExerciseTrackingType,
    weight: Double?,
    reps: Int?,
    durationSeconds: Int?,
    distanceMiles: Double?,
    speedMph: Double?,
): String {
    return when (trackingType) {
        ExerciseTrackingType.WEIGHT_REPS -> {
            val weightText = weight?.let(::formatWeightValue) ?: "-"
            val repsText = reps?.toString() ?: "-"
            "$weightText lbs x $repsText reps"
        }
        ExerciseTrackingType.DURATION -> {
            durationSeconds?.let(::formatDurationValue) ?: "-"
        }
        ExerciseTrackingType.DURATION_DISTANCE -> {
            val durationText = durationSeconds?.let(::formatDurationValue) ?: "-"
            val distanceText = distanceMiles?.let(::formatDistanceMiles) ?: "-"
            val speedText = speedMph?.let(::formatSpeedMph)
            if (speedText != null) {
                "$durationText | $distanceText mi | $speedText mph"
            } else {
                "$durationText | $distanceText mi"
            }
        }
    }
}
