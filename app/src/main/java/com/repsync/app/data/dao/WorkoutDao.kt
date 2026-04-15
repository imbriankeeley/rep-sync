package com.repsync.app.data.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.repsync.app.data.entity.ExerciseEntity
import com.repsync.app.data.entity.ExerciseSetEntity
import com.repsync.app.data.entity.WorkoutEntity
import com.repsync.app.data.entity.WorkoutWithExercises
import kotlinx.coroutines.flow.Flow

@Dao
interface WorkoutDao {

    @Insert
    suspend fun insertWorkout(workout: WorkoutEntity): Long

    @Update
    suspend fun updateWorkout(workout: WorkoutEntity)

    @Delete
    suspend fun deleteWorkout(workout: WorkoutEntity)

    @Insert
    suspend fun insertExercise(exercise: ExerciseEntity): Long

    @Insert
    suspend fun insertExercises(exercises: List<ExerciseEntity>): List<Long>

    @Update
    suspend fun updateExercise(exercise: ExerciseEntity)

    @Delete
    suspend fun deleteExercise(exercise: ExerciseEntity)

    @Query("DELETE FROM exercises WHERE workoutId = :workoutId")
    suspend fun deleteExercisesByWorkoutId(workoutId: Long)

    @Insert
    suspend fun insertSet(set: ExerciseSetEntity): Long

    @Insert
    suspend fun insertSets(sets: List<ExerciseSetEntity>): List<Long>

    @Update
    suspend fun updateSet(set: ExerciseSetEntity)

    @Delete
    suspend fun deleteSet(set: ExerciseSetEntity)

    @Query("DELETE FROM exercise_sets WHERE exerciseId = :exerciseId")
    suspend fun deleteSetsByExerciseId(exerciseId: Long)

    @Query("SELECT * FROM workouts ORDER BY orderIndex ASC")
    fun getAllWorkouts(): Flow<List<WorkoutEntity>>

    @Query("SELECT * FROM workouts WHERE id = :id")
    suspend fun getWorkoutById(id: Long): WorkoutEntity?

    @Transaction
    @Query("SELECT * FROM workouts WHERE id = :id")
    suspend fun getWorkoutWithExercises(id: Long): WorkoutWithExercises?

    @Transaction
    @Query("SELECT * FROM workouts ORDER BY orderIndex ASC")
    fun getAllWorkoutsWithExercises(): Flow<List<WorkoutWithExercises>>

    @Query("SELECT * FROM workouts WHERE name LIKE '%' || :query || '%' ORDER BY orderIndex ASC")
    fun searchWorkouts(query: String): Flow<List<WorkoutEntity>>

    @Query("UPDATE workouts SET orderIndex = :orderIndex WHERE id = :id")
    suspend fun updateWorkoutOrder(id: Long, orderIndex: Int)

    @Query("SELECT COUNT(*) FROM workouts")
    suspend fun getWorkoutCount(): Int

    @Query("SELECT trackingType FROM exercises WHERE name = :name ORDER BY id DESC LIMIT 1")
    suspend fun getTrackingTypeForExerciseName(name: String): String?
}
