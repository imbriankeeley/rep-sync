package com.repsync.app.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.repsync.app.data.RepSyncDatabase
import com.repsync.app.data.entity.CompletedWorkoutWithExercises
import com.repsync.app.data.entity.ExerciseEntity
import com.repsync.app.data.entity.ExerciseSetEntity
import com.repsync.app.data.entity.WorkoutEntity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter

data class DayViewUiState(
    val date: LocalDate = LocalDate.now(),
    val workouts: List<CompletedWorkoutWithExercises> = emptyList(),
    val isLoading: Boolean = true,
    val showCopyDatePicker: Boolean = false,
    val copyingWorkoutId: Long? = null,
    val showSaveTemplateDialog: Boolean = false,
    val savingTemplateWorkoutId: Long? = null,
    val showDeleteDialog: Boolean = false,
    val deletingWorkoutId: Long? = null,
    val templateSaved: Boolean = false,
    val workoutCopied: Boolean = false,
    val workoutDeleted: Boolean = false,
)

class DayViewViewModel(application: Application) : AndroidViewModel(application) {

    private val db = RepSyncDatabase.getDatabase(application)
    private val completedWorkoutDao = db.completedWorkoutDao()
    private val workoutDao = db.workoutDao()

    private val _uiState = MutableStateFlow(DayViewUiState())
    val uiState: StateFlow<DayViewUiState> = _uiState.asStateFlow()

    fun loadDate(date: LocalDate) {
        _uiState.value = _uiState.value.copy(date = date, isLoading = true)
        viewModelScope.launch {
            val dateString = date.format(DateTimeFormatter.ISO_LOCAL_DATE)
            completedWorkoutDao.getCompletedWorkoutsForDate(dateString).collect { workouts ->
                _uiState.value = _uiState.value.copy(
                    workouts = workouts,
                    isLoading = false,
                )
            }
        }
    }

    fun showCopyDatePicker(workoutId: Long) {
        _uiState.value = _uiState.value.copy(
            showCopyDatePicker = true,
            copyingWorkoutId = workoutId,
        )
    }

    fun dismissCopyDatePicker() {
        _uiState.value = _uiState.value.copy(
            showCopyDatePicker = false,
            copyingWorkoutId = null,
        )
    }

    fun copyWorkoutToDate(targetDate: LocalDate) {
        val workoutId = _uiState.value.copyingWorkoutId ?: return
        val sourceWorkout = _uiState.value.workouts.find { it.workout.id == workoutId } ?: return

        viewModelScope.launch {
            val targetDateString = targetDate.format(DateTimeFormatter.ISO_LOCAL_DATE)
            val now = System.currentTimeMillis()

            // Insert the completed workout copy
            val newWorkoutId = completedWorkoutDao.insertCompletedWorkout(
                sourceWorkout.workout.copy(
                    id = 0,
                    date = targetDateString,
                    startedAt = now,
                    endedAt = now,
                )
            )

            // Copy exercises and sets
            for (exerciseWithSets in sourceWorkout.exercises) {
                val newExerciseId = completedWorkoutDao.insertCompletedExercise(
                    exerciseWithSets.exercise.copy(
                        id = 0,
                        completedWorkoutId = newWorkoutId,
                    )
                )
                val newSets = exerciseWithSets.sets.map { set ->
                    set.copy(
                        id = 0,
                        completedExerciseId = newExerciseId,
                    )
                }
                if (newSets.isNotEmpty()) {
                    completedWorkoutDao.insertCompletedSets(newSets)
                }
            }

            _uiState.value = _uiState.value.copy(
                showCopyDatePicker = false,
                copyingWorkoutId = null,
                workoutCopied = true,
            )
        }
    }

    fun showSaveTemplateDialog(workoutId: Long) {
        _uiState.value = _uiState.value.copy(
            showSaveTemplateDialog = true,
            savingTemplateWorkoutId = workoutId,
        )
    }

    fun dismissSaveTemplateDialog() {
        _uiState.value = _uiState.value.copy(
            showSaveTemplateDialog = false,
            savingTemplateWorkoutId = null,
        )
    }

    fun saveAsTemplate(name: String) {
        val workoutId = _uiState.value.savingTemplateWorkoutId ?: return
        val sourceWorkout = _uiState.value.workouts.find { it.workout.id == workoutId } ?: return

        viewModelScope.launch {
            // Create a new workout template
            val templateId = workoutDao.insertWorkout(
                WorkoutEntity(name = name)
            )

            // Copy exercises and sets into template format
            for (exerciseWithSets in sourceWorkout.exercises) {
                val exerciseId = workoutDao.insertExercise(
                    ExerciseEntity(
                        workoutId = templateId,
                        name = exerciseWithSets.exercise.name,
                        orderIndex = exerciseWithSets.exercise.orderIndex,
                        trackingType = exerciseWithSets.exercise.trackingType,
                    )
                )
                val templateSets = exerciseWithSets.sets.map { set ->
                    ExerciseSetEntity(
                        exerciseId = exerciseId,
                        orderIndex = set.orderIndex,
                        weight = set.weight,
                        reps = set.reps,
                        durationSeconds = set.durationSeconds,
                        distanceMiles = set.distanceMiles,
                        speedMph = set.speedMph,
                    )
                }
                if (templateSets.isNotEmpty()) {
                    workoutDao.insertSets(templateSets)
                }
            }

            _uiState.value = _uiState.value.copy(
                showSaveTemplateDialog = false,
                savingTemplateWorkoutId = null,
                templateSaved = true,
            )
        }
    }

    // Delete workout

    fun showDeleteDialog(workoutId: Long) {
        _uiState.value = _uiState.value.copy(
            showDeleteDialog = true,
            deletingWorkoutId = workoutId,
        )
    }

    fun dismissDeleteDialog() {
        _uiState.value = _uiState.value.copy(
            showDeleteDialog = false,
            deletingWorkoutId = null,
        )
    }

    fun deleteWorkout() {
        val workoutId = _uiState.value.deletingWorkoutId ?: return
        val workout = _uiState.value.workouts.find { it.workout.id == workoutId } ?: return

        viewModelScope.launch {
            completedWorkoutDao.deleteCompletedWorkout(workout.workout)
            _uiState.value = _uiState.value.copy(
                showDeleteDialog = false,
                deletingWorkoutId = null,
                workoutDeleted = true,
            )
        }
    }

    fun clearTemplateSavedFlag() {
        _uiState.value = _uiState.value.copy(templateSaved = false)
    }

    fun clearWorkoutCopiedFlag() {
        _uiState.value = _uiState.value.copy(workoutCopied = false)
    }

    fun clearWorkoutDeletedFlag() {
        _uiState.value = _uiState.value.copy(workoutDeleted = false)
    }
}
