package com.repsync.app.data.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.repsync.app.data.entity.CompletedExerciseEntity
import com.repsync.app.data.entity.CompletedSetEntity
import com.repsync.app.data.entity.CompletedWorkoutEntity
import com.repsync.app.data.entity.CompletedWorkoutWithExercises
import com.repsync.app.data.entity.ExerciseHistoryRow
import com.repsync.app.data.entity.PreviousSetResult
import kotlinx.coroutines.flow.Flow

@Dao
interface CompletedWorkoutDao {

    @Insert
    suspend fun insertCompletedWorkout(workout: CompletedWorkoutEntity): Long

    @Update
    suspend fun updateCompletedWorkout(workout: CompletedWorkoutEntity)

    @Delete
    suspend fun deleteCompletedWorkout(workout: CompletedWorkoutEntity)

    @Insert
    suspend fun insertCompletedExercise(exercise: CompletedExerciseEntity): Long

    @Insert
    suspend fun insertCompletedExercises(exercises: List<CompletedExerciseEntity>): List<Long>

    @Insert
    suspend fun insertCompletedSet(set: CompletedSetEntity): Long

    @Insert
    suspend fun insertCompletedSets(sets: List<CompletedSetEntity>): List<Long>

    @Query("SELECT * FROM completed_workouts ORDER BY startedAt DESC")
    fun getAllCompletedWorkouts(): Flow<List<CompletedWorkoutEntity>>

    @Transaction
    @Query("SELECT * FROM completed_workouts WHERE id = :id")
    suspend fun getCompletedWorkoutWithExercises(id: Long): CompletedWorkoutWithExercises?

    @Transaction
    @Query("SELECT * FROM completed_workouts WHERE date = :date ORDER BY startedAt DESC")
    fun getCompletedWorkoutsForDate(date: String): Flow<List<CompletedWorkoutWithExercises>>

    @Query("SELECT DISTINCT date FROM completed_workouts WHERE endedAt IS NOT NULL")
    fun getDatesWithCompletedWorkouts(): Flow<List<String>>

    @Query("SELECT COUNT(*) FROM completed_workouts WHERE endedAt IS NOT NULL")
    fun getCompletedWorkoutCount(): Flow<Int>

    /**
     * Get the "Previous" data for an exercise by name:
     * Returns weight and reps from the most recent completed set for this exercise name.
     * Groups by set orderIndex so the UI can show previous for each set row.
     */
    @Query(
        """
        SELECT ce.trackingType, cs.weight, cs.reps, cs.durationSeconds, cs.distanceMiles, cs.speedMph
        FROM completed_sets cs
        INNER JOIN completed_exercises ce ON cs.completedExerciseId = ce.id
        INNER JOIN completed_workouts cw ON ce.completedWorkoutId = cw.id
        WHERE ce.name = :exerciseName
          AND cw.endedAt IS NOT NULL
          AND cs.orderIndex = :setIndex
        ORDER BY cw.startedAt DESC
        LIMIT 1
        """
    )
    suspend fun getPreviousSetForExercise(exerciseName: String, setIndex: Int): PreviousSetResult?

    /**
     * Get all previous sets for an exercise name from the most recent completed workout
     * containing that exercise.
     */
    @Query(
        """
        SELECT ce.trackingType, cs.weight, cs.reps, cs.durationSeconds, cs.distanceMiles, cs.speedMph
        FROM completed_sets cs
        INNER JOIN completed_exercises ce ON cs.completedExerciseId = ce.id
        WHERE ce.completedWorkoutId = (
            SELECT ce2.completedWorkoutId
            FROM completed_exercises ce2
            INNER JOIN completed_workouts cw ON ce2.completedWorkoutId = cw.id
            WHERE ce2.name = :exerciseName
              AND cw.endedAt IS NOT NULL
            ORDER BY cw.startedAt DESC
            LIMIT 1
        )
        AND ce.name = :exerciseName
        ORDER BY cs.orderIndex ASC
        """
    )
    suspend fun getAllPreviousSetsForExercise(exerciseName: String): List<PreviousSetResult>

    /**
     * Get all distinct exercise names from both completed workouts and templates (for autocomplete).
     */
    @Query(
        """
        SELECT DISTINCT name FROM (
            SELECT name FROM completed_exercises
            UNION
            SELECT name FROM exercises
        ) ORDER BY name ASC
        """
    )
    suspend fun getAllExerciseNames(): List<String>

    @Query("SELECT * FROM completed_workouts WHERE isQuickWorkout = 1 ORDER BY startedAt DESC")
    fun getQuickWorkouts(): Flow<List<CompletedWorkoutEntity>>

    @Transaction
    @Query("SELECT * FROM completed_workouts WHERE isQuickWorkout = 1 ORDER BY startedAt DESC")
    fun getQuickWorkoutsWithExercises(): Flow<List<CompletedWorkoutWithExercises>>

    @Query(
        """
        SELECT ce.trackingType
        FROM completed_exercises ce
        INNER JOIN completed_workouts cw ON ce.completedWorkoutId = cw.id
        WHERE ce.name = :exerciseName
          AND cw.endedAt IS NOT NULL
        ORDER BY cw.startedAt DESC
        LIMIT 1
        """
    )
    suspend fun getMostRecentTrackingTypeForExerciseName(exerciseName: String): String?

    /**
     * Get full exercise history: all sets for a specific exercise name across all completed workouts.
     */
    @Query(
        """
        SELECT
            cw.date,
            cw.name AS workoutName,
            ce.trackingType,
            cs.weight,
            cs.reps,
            cs.orderIndex,
            cs.durationSeconds,
            cs.distanceMiles,
            cs.speedMph
        FROM completed_sets cs
        INNER JOIN completed_exercises ce ON cs.completedExerciseId = ce.id
        INNER JOIN completed_workouts cw ON ce.completedWorkoutId = cw.id
        WHERE ce.name = :exerciseName
          AND cw.endedAt IS NOT NULL
        ORDER BY cw.date DESC, cw.startedAt DESC, cs.orderIndex ASC
        """
    )
    suspend fun getExerciseHistory(exerciseName: String): List<ExerciseHistoryRow>

    /**
     * Get the max weight ever recorded for a specific exercise.
     */
    @Query(
        """
        SELECT MAX(
            CASE ce.trackingType
                WHEN 'duration_distance' THEN COALESCE(cs.distanceMiles, 0)
                WHEN 'duration' THEN COALESCE(cs.durationSeconds, 0)
                ELSE COALESCE(cs.weight, 0)
            END
        )
        FROM completed_sets cs
        INNER JOIN completed_exercises ce ON cs.completedExerciseId = ce.id
        INNER JOIN completed_workouts cw ON ce.completedWorkoutId = cw.id
        WHERE ce.name = :exerciseName AND cw.endedAt IS NOT NULL
        """
    )
    suspend fun getExerciseMaxWeight(exerciseName: String): Double?
}
