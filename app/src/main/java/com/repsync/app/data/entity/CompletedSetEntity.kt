package com.repsync.app.data.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "completed_sets",
    foreignKeys = [
        ForeignKey(
            entity = CompletedExerciseEntity::class,
            parentColumns = ["id"],
            childColumns = ["completedExerciseId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("completedExerciseId")]
)
data class CompletedSetEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val completedExerciseId: Long,
    val orderIndex: Int,
    val weight: Double? = null,
    val reps: Int? = null,
    val durationSeconds: Int? = null,
    val distanceMiles: Double? = null,
    val speedMph: Double? = null,
)
