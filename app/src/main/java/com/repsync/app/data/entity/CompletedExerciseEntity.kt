package com.repsync.app.data.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "completed_exercises",
    foreignKeys = [
        ForeignKey(
            entity = CompletedWorkoutEntity::class,
            parentColumns = ["id"],
            childColumns = ["completedWorkoutId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("completedWorkoutId")]
)
data class CompletedExerciseEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val completedWorkoutId: Long,
    val name: String,
    val orderIndex: Int,
    val trackingType: String = ExerciseTrackingType.WEIGHT_REPS.storageValue,
)
