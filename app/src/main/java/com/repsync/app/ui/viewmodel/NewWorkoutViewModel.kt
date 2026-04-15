package com.repsync.app.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.repsync.app.data.RepSyncDatabase
import com.repsync.app.data.entity.ExerciseEntity
import com.repsync.app.data.entity.ExerciseSetEntity
import com.repsync.app.data.entity.ExerciseTrackingType
import com.repsync.app.data.entity.WorkoutEntity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class SetUiModel(
    val orderIndex: Int,
)

data class ExerciseUiModel(
    val id: String = java.util.UUID.randomUUID().toString(),
    val name: String = "",
    val trackingType: ExerciseTrackingType = ExerciseTrackingType.WEIGHT_REPS,
    val sets: List<SetUiModel> = listOf(SetUiModel(orderIndex = 0)),
)

data class NewWorkoutUiState(
    val workoutName: String = "",
    val exercises: List<ExerciseUiModel> = emptyList(),
    val isSaving: Boolean = false,
    val isSaved: Boolean = false,
    val editingWorkoutId: Long? = null,
    val editingWorkoutOrderIndex: Int? = null,
    val exerciseNameSuggestions: List<String> = emptyList(),
)

class NewWorkoutViewModel(application: Application) : AndroidViewModel(application) {

    private val workoutDao = RepSyncDatabase.getDatabase(application).workoutDao()
    private val completedWorkoutDao = RepSyncDatabase.getDatabase(application).completedWorkoutDao()

    private val _uiState = MutableStateFlow(NewWorkoutUiState())
    val uiState: StateFlow<NewWorkoutUiState> = _uiState.asStateFlow()

    init {
        loadExerciseNames()
    }

    private fun loadExerciseNames() {
        viewModelScope.launch {
            val names = completedWorkoutDao.getAllExerciseNames()
            _uiState.value = _uiState.value.copy(exerciseNameSuggestions = names)
        }
    }

    fun loadWorkoutForEditing(workoutId: Long) {
        viewModelScope.launch {
            val workoutWithExercises = workoutDao.getWorkoutWithExercises(workoutId) ?: return@launch
            val exercises = workoutWithExercises.exercises
                .sortedBy { it.exercise.orderIndex }
                .map { exerciseWithSets ->
                    ExerciseUiModel(
                        name = exerciseWithSets.exercise.name,
                        trackingType = ExerciseTrackingType.fromStorage(
                            exerciseWithSets.exercise.trackingType
                        ),
                        sets = exerciseWithSets.sets
                            .sortedBy { it.orderIndex }
                            .map { set ->
                                SetUiModel(orderIndex = set.orderIndex)
                            }.ifEmpty {
                                listOf(SetUiModel(orderIndex = 0))
                            },
                    )
                }
            _uiState.value = _uiState.value.copy(
                workoutName = workoutWithExercises.workout.name,
                exercises = exercises,
                editingWorkoutId = workoutId,
                editingWorkoutOrderIndex = workoutWithExercises.workout.orderIndex,
            )
        }
    }

    fun onWorkoutNameChange(name: String) {
        _uiState.value = _uiState.value.copy(workoutName = name)
    }

    fun addExercise() {
        val current = _uiState.value
        _uiState.value = current.copy(
            exercises = current.exercises + ExerciseUiModel()
        )
    }

    fun removeExercise(exerciseId: String) {
        val current = _uiState.value
        _uiState.value = current.copy(
            exercises = current.exercises.filter { it.id != exerciseId }
        )
    }

    fun moveExercise(fromIndex: Int, toIndex: Int) {
        val currentExercises = _uiState.value.exercises.toMutableList()
        val item = currentExercises.removeAt(fromIndex)
        currentExercises.add(toIndex, item)
        _uiState.value = _uiState.value.copy(exercises = currentExercises)
    }

    fun onExerciseNameChange(exerciseId: String, name: String) {
        val current = _uiState.value
        _uiState.value = current.copy(
            exercises = current.exercises.map { exercise ->
                if (exercise.id == exerciseId) exercise.copy(name = name)
                else exercise
            }
        )
    }

    fun onExerciseTrackingTypeChange(exerciseId: String, trackingType: ExerciseTrackingType) {
        val current = _uiState.value
        _uiState.value = current.copy(
            exercises = current.exercises.map { exercise ->
                if (exercise.id == exerciseId) exercise.copy(trackingType = trackingType)
                else exercise
            }
        )
    }

    fun addSet(exerciseId: String) {
        val current = _uiState.value
        _uiState.value = current.copy(
            exercises = current.exercises.map { exercise ->
                if (exercise.id == exerciseId) {
                    val newIndex = exercise.sets.size
                    exercise.copy(
                        sets = exercise.sets + SetUiModel(orderIndex = newIndex)
                    )
                } else exercise
            }
        )
    }

    fun removeSet(exerciseId: String, setIndex: Int) {
        val current = _uiState.value
        _uiState.value = current.copy(
            exercises = current.exercises.map { exercise ->
                if (exercise.id == exerciseId && exercise.sets.size > 1) {
                    exercise.copy(
                        sets = exercise.sets.filterIndexed { index, _ -> index != setIndex }
                            .mapIndexed { index, set -> set.copy(orderIndex = index) }
                    )
                } else exercise
            }
        )
    }

    fun saveWorkout() {
        val state = _uiState.value
        if (state.workoutName.isBlank()) return
        if (state.exercises.isEmpty()) return

        _uiState.value = state.copy(isSaving = true)

        viewModelScope.launch {
            val editId = state.editingWorkoutId
            if (editId != null) {
                // Update existing workout, preserving orderIndex
                val orderIndex = state.editingWorkoutOrderIndex ?: 0
                workoutDao.updateWorkout(WorkoutEntity(id = editId, name = state.workoutName, orderIndex = orderIndex))
                workoutDao.deleteExercisesByWorkoutId(editId)
                insertExercisesAndSets(editId, state.exercises)
            } else {
                // Create new workout at the bottom of the list
                val count = workoutDao.getWorkoutCount()
                val workoutId = workoutDao.insertWorkout(
                    WorkoutEntity(name = state.workoutName, orderIndex = count)
                )
                insertExercisesAndSets(workoutId, state.exercises)
            }
            _uiState.value = _uiState.value.copy(isSaving = false, isSaved = true)
        }
    }

    private suspend fun insertExercisesAndSets(workoutId: Long, exercises: List<ExerciseUiModel>) {
        exercises.forEachIndexed { exerciseIndex, exercise ->
            if (exercise.name.isBlank()) return@forEachIndexed
            val exerciseId = workoutDao.insertExercise(
                ExerciseEntity(
                    workoutId = workoutId,
                    name = exercise.name,
                    orderIndex = exerciseIndex,
                    trackingType = exercise.trackingType.storageValue,
                )
            )
            val sets = exercise.sets.mapIndexed { setIndex, _ ->
                ExerciseSetEntity(
                    exerciseId = exerciseId,
                    orderIndex = setIndex,
                    weight = null,
                    reps = null,
                    durationSeconds = null,
                    distanceMiles = null,
                    speedMph = null,
                )
            }
            if (sets.isNotEmpty()) {
                workoutDao.insertSets(sets)
            }
        }
    }

}
