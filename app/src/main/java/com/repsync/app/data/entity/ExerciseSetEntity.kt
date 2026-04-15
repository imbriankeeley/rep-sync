package com.repsync.app.data.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "exercise_sets",
    foreignKeys = [
        ForeignKey(
            entity = ExerciseEntity::class,
            parentColumns = ["id"],
            childColumns = ["exerciseId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("exerciseId")]
)
data class ExerciseSetEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val exerciseId: Long,
    val orderIndex: Int,
    val weight: Double? = null,
    val reps: Int? = null,
    val durationSeconds: Int? = null,
    val distanceMiles: Double? = null,
    val speedMph: Double? = null,
)
