package com.repsync.app.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.repsync.app.data.converter.Converters
import com.repsync.app.data.dao.BodyweightDao
import com.repsync.app.data.dao.CompletedWorkoutDao
import com.repsync.app.data.dao.UserProfileDao
import com.repsync.app.data.dao.WorkoutDao
import com.repsync.app.data.entity.BodyweightEntryEntity
import com.repsync.app.data.entity.CompletedExerciseEntity
import com.repsync.app.data.entity.CompletedSetEntity
import com.repsync.app.data.entity.CompletedWorkoutEntity
import com.repsync.app.data.entity.ExerciseEntity
import com.repsync.app.data.entity.ExerciseSetEntity
import com.repsync.app.data.entity.UserProfileEntity
import com.repsync.app.data.entity.WorkoutEntity

@Database(
    entities = [
        WorkoutEntity::class,
        ExerciseEntity::class,
        ExerciseSetEntity::class,
        CompletedWorkoutEntity::class,
        CompletedExerciseEntity::class,
        CompletedSetEntity::class,
        UserProfileEntity::class,
        BodyweightEntryEntity::class,
    ],
    version = 5,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class RepSyncDatabase : RoomDatabase() {

    abstract fun workoutDao(): WorkoutDao
    abstract fun completedWorkoutDao(): CompletedWorkoutDao
    abstract fun userProfileDao(): UserProfileDao
    abstract fun bodyweightDao(): BodyweightDao

    companion object {
        @Volatile
        private var INSTANCE: RepSyncDatabase? = null

        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS bodyweight_entries (
                        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        date TEXT NOT NULL,
                        weight REAL NOT NULL
                    )
                    """.trimIndent()
                )
            }
        }

        private val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE workouts ADD COLUMN orderIndex INTEGER NOT NULL DEFAULT 0")
                db.execSQL(
                    """
                    UPDATE workouts SET orderIndex = (
                        SELECT COUNT(*) FROM workouts w2 WHERE w2.createdAt > workouts.createdAt
                    )
                    """.trimIndent()
                )
            }
        }

        private val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "ALTER TABLE exercises ADD COLUMN trackingType TEXT NOT NULL DEFAULT 'weight_reps'"
                )
                db.execSQL(
                    "ALTER TABLE completed_exercises ADD COLUMN trackingType TEXT NOT NULL DEFAULT 'weight_reps'"
                )
                db.execSQL(
                    "ALTER TABLE exercise_sets ADD COLUMN durationSeconds INTEGER"
                )
                db.execSQL(
                    "ALTER TABLE exercise_sets ADD COLUMN distanceMiles REAL"
                )
                db.execSQL(
                    "ALTER TABLE completed_sets ADD COLUMN durationSeconds INTEGER"
                )
                db.execSQL(
                    "ALTER TABLE completed_sets ADD COLUMN distanceMiles REAL"
                )
            }
        }

        private val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "ALTER TABLE exercise_sets ADD COLUMN speedMph REAL"
                )
                db.execSQL(
                    "ALTER TABLE completed_sets ADD COLUMN speedMph REAL"
                )
            }
        }

        fun getDatabase(context: Context): RepSyncDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    RepSyncDatabase::class.java,
                    "repsync_database"
                )
                    .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5)
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
