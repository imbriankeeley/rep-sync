package com.repsync.app.ui.viewmodel

import android.app.Application
import android.content.Intent
import android.os.Build
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.repsync.app.data.RepSyncDatabase
import com.repsync.app.data.RestTimerPreferences
import com.repsync.app.data.entity.CompletedExerciseEntity
import com.repsync.app.data.entity.CompletedSetEntity
import com.repsync.app.data.entity.CompletedWorkoutEntity
import com.repsync.app.data.entity.ExerciseTrackingType
import com.repsync.app.service.RestTimerService
import com.repsync.app.service.RestTimerState
import com.repsync.app.util.formatDistanceMiles
import com.repsync.app.util.formatSpeedMph
import com.repsync.app.util.formatWeightValue
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.flow.SharingStarted

data class ActiveWorkoutBannerInfo(
    val workoutName: String,
    val elapsedSeconds: Long,
    val templateId: Long?,
    val isQuickWorkout: Boolean,
)

class ActiveWorkoutManager(application: Application) : AndroidViewModel(application) {

    private val workoutDao = RepSyncDatabase.getDatabase(application).workoutDao()
    private val completedWorkoutDao = RepSyncDatabase.getDatabase(application).completedWorkoutDao()
    private val restTimerPrefs = RestTimerPreferences.getInstance(application)

    private val _activeWorkoutState = MutableStateFlow<ActiveWorkoutUiState?>(null)
    val activeWorkoutState: StateFlow<ActiveWorkoutUiState?> = _activeWorkoutState.asStateFlow()

    private val _workoutEndedEvent = MutableSharedFlow<Unit>()
    val workoutEndedEvent: SharedFlow<Unit> = _workoutEndedEvent.asSharedFlow()

    val bannerInfo: StateFlow<ActiveWorkoutBannerInfo?> = _activeWorkoutState
        .map { state ->
            if (state != null) {
                ActiveWorkoutBannerInfo(
                    workoutName = state.workoutName,
                    elapsedSeconds = state.elapsedSeconds,
                    templateId = state.templateId,
                    isQuickWorkout = state.isQuickWorkout,
                )
            } else null
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    private var timerJob: Job? = null
    private var startedAtMillis: Long = 0L

    init {
        viewModelScope.launch {
            restTimerPrefs.durationSeconds.collect { savedDuration ->
                val current = _activeWorkoutState.value ?: return@collect
                _activeWorkoutState.value = current.copy(restTimerDurationSeconds = savedDuration)
            }
        }
        viewModelScope.launch {
            RestTimerState.secondsRemaining.collect { remaining ->
                val state = _activeWorkoutState.value ?: return@collect
                _activeWorkoutState.value = state.copy(restTimerSecondsRemaining = remaining)
            }
        }
        viewModelScope.launch {
            RestTimerState.timerCompleted.collect {
                onRestTimerComplete()
            }
        }
    }

    fun hasActiveWorkout(): Boolean = _activeWorkoutState.value != null

    fun isActiveWorkoutSession(workoutId: Long?): Boolean {
        val current = _activeWorkoutState.value ?: return false
        return if (workoutId == null) {
            current.isQuickWorkout
        } else {
            !current.isQuickWorkout && current.templateId == workoutId
        }
    }

    fun loadWorkout(workoutId: Long) {
        val current = _activeWorkoutState.value
        if (current != null && current.templateId == workoutId && !current.isQuickWorkout) {
            return
        }

        val existingRestTimerDurationSeconds = current?.restTimerDurationSeconds
            ?: RestTimerPreferences.DEFAULT_DURATION_SECONDS

        _activeWorkoutState.value = ActiveWorkoutUiState(
            workoutName = "Loading workout...",
            exercises = emptyList(),
            elapsedSeconds = 0L,
            isLoading = true,
            templateId = workoutId,
            isQuickWorkout = false,
            restTimerDurationSeconds = existingRestTimerDurationSeconds,
        )

        startedAtMillis = System.currentTimeMillis()
        startTimer()

        viewModelScope.launch {
            val workoutWithExercises = workoutDao.getWorkoutWithExercises(workoutId)
                ?: run {
                    _activeWorkoutState.value = null
                    return@launch
                }

            val exercises = workoutWithExercises.exercises
                .sortedBy { it.exercise.orderIndex }
                .map { exerciseWithSets ->
                    val trackingType = ExerciseTrackingType.fromStorage(
                        exerciseWithSets.exercise.trackingType
                    )
                    val previousSets = completedWorkoutDao.getAllPreviousSetsForExercise(
                        exerciseWithSets.exercise.name
                    )
                    ActiveExerciseUiModel(
                        name = exerciseWithSets.exercise.name,
                        trackingType = trackingType,
                        isTrackingTypeEditable = false,
                        sets = exerciseWithSets.sets
                            .sortedBy { it.orderIndex }
                            .mapIndexed { index, set ->
                                val previous = previousSets.getOrNull(index)
                                ActiveSetUiModel(
                                    orderIndex = set.orderIndex,
                                    weight = set.weight?.let(::formatWeightValue) ?: "",
                                    reps = set.reps?.toString() ?: "",
                                    durationMinutes = set.durationSeconds?.let { (it / 60).toString() } ?: "",
                                    durationSeconds = set.durationSeconds?.let { (it % 60).toString() } ?: "",
                                    distance = set.distanceMiles?.let(::formatDistanceMiles) ?: "",
                                    speed = set.speedMph?.let(::formatSpeedMph) ?: "",
                                    previous = previous?.takeIf {
                                        ExerciseTrackingType.fromStorage(it.trackingType) == trackingType
                                    },
                                )
                            }.ifEmpty {
                                listOf(ActiveSetUiModel(orderIndex = 0))
                            },
                    )
                }

            _activeWorkoutState.value = ActiveWorkoutUiState(
                workoutName = workoutWithExercises.workout.name,
                exercises = exercises,
                elapsedSeconds = 0L,
                isLoading = false,
                templateId = workoutId,
                restTimerDurationSeconds = existingRestTimerDurationSeconds,
            )

            loadExerciseNames()
        }
    }

    fun startQuickWorkout() {
        val current = _activeWorkoutState.value
        if (current?.isQuickWorkout == true) return

        val existingRestTimerDurationSeconds = current?.restTimerDurationSeconds
            ?: RestTimerPreferences.DEFAULT_DURATION_SECONDS

        _activeWorkoutState.value = ActiveWorkoutUiState(
            workoutName = "Quick Workout",
            exercises = emptyList(),
            elapsedSeconds = 0L,
            isLoading = false,
            isQuickWorkout = true,
            restTimerDurationSeconds = existingRestTimerDurationSeconds,
        )

        startedAtMillis = System.currentTimeMillis()
        startTimer()
        loadExerciseNames()
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (true) {
                delay(1000L)
                val elapsed = (System.currentTimeMillis() - startedAtMillis) / 1000
                val current = _activeWorkoutState.value ?: break
                _activeWorkoutState.value = current.copy(elapsedSeconds = elapsed)
            }
        }
    }

    private fun loadExerciseNames() {
        viewModelScope.launch {
            val names = completedWorkoutDao.getAllExerciseNames()
            val current = _activeWorkoutState.value ?: return@launch
            _activeWorkoutState.value = current.copy(exerciseNameSuggestions = names)
        }
    }

    // Exercise and set operations

    fun toggleSetCompleted(exerciseId: String, setIndex: Int) {
        updateSet(exerciseId, setIndex) { it.copy(isCompleted = !it.isCompleted) }
        val state = _activeWorkoutState.value ?: return
        val exercise = state.exercises.find { it.id == exerciseId }
        val set = exercise?.sets?.getOrNull(setIndex)
        if (set?.isCompleted == true) {
            startRestTimer()
        }
    }

    fun onSetWeightChange(exerciseId: String, setIndex: Int, weight: String) {
        updateSet(exerciseId, setIndex) { it.copy(weight = weight) }
    }

    fun onSetRepsChange(exerciseId: String, setIndex: Int, reps: String) {
        updateSet(exerciseId, setIndex) { it.copy(reps = reps) }
    }

    fun onSetDurationMinutesChange(exerciseId: String, setIndex: Int, minutes: String) {
        updateSet(exerciseId, setIndex) { it.copy(durationMinutes = minutes.filter { ch -> ch.isDigit() }) }
    }

    fun onSetDurationSecondsChange(exerciseId: String, setIndex: Int, seconds: String) {
        val filtered = seconds.filter { ch -> ch.isDigit() }.take(2)
        val normalized = filtered.toIntOrNull()?.coerceAtMost(59)?.toString() ?: filtered
        updateSet(exerciseId, setIndex) { it.copy(durationSeconds = normalized) }
    }

    fun onSetDistanceChange(exerciseId: String, setIndex: Int, distance: String) {
        updateSet(exerciseId, setIndex) { it.copy(distance = distance) }
    }

    fun onSetSpeedChange(exerciseId: String, setIndex: Int, speed: String) {
        updateSet(exerciseId, setIndex) { it.copy(speed = speed) }
    }

    fun addSet(exerciseId: String) {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(
            exercises = current.exercises.map { exercise ->
                if (exercise.id == exerciseId) {
                    val newIndex = exercise.sets.size
                    exercise.copy(
                        sets = exercise.sets + ActiveSetUiModel(orderIndex = newIndex)
                    )
                } else exercise
            }
        )
        val exercise = _activeWorkoutState.value?.exercises?.find { it.id == exerciseId }
        if (exercise != null && exercise.name.isNotBlank()) {
            viewModelScope.launch {
                val newSetIndex = exercise.sets.size - 1
                val previous = completedWorkoutDao.getPreviousSetForExercise(
                    exercise.name, newSetIndex
                )
                if (previous != null &&
                    ExerciseTrackingType.fromStorage(previous.trackingType) == exercise.trackingType
                ) {
                    val updated = _activeWorkoutState.value ?: return@launch
                    _activeWorkoutState.value = updated.copy(
                        exercises = updated.exercises.map { ex ->
                            if (ex.id == exerciseId) {
                                ex.copy(
                                    sets = ex.sets.mapIndexed { index, set ->
                                        if (index == newSetIndex) set.copy(previous = previous)
                                        else set
                                    }
                                )
                            } else ex
                        }
                    )
                }
            }
        }
    }

    fun removeSet(exerciseId: String, setIndex: Int) {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(
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

    fun addExercise() {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(
            exercises = current.exercises + ActiveExerciseUiModel()
        )
    }

    fun removeExercise(exerciseId: String) {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(
            exercises = current.exercises.filter { it.id != exerciseId }
        )
    }

    fun moveExercise(fromIndex: Int, toIndex: Int) {
        val current = _activeWorkoutState.value ?: return
        val exercises = current.exercises.toMutableList()
        val item = exercises.removeAt(fromIndex)
        exercises.add(toIndex, item)
        _activeWorkoutState.value = current.copy(exercises = exercises)
    }

    fun onExerciseNameChange(exerciseId: String, name: String) {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(
            exercises = current.exercises.map { exercise ->
                if (exercise.id == exerciseId) exercise.copy(name = name)
                else exercise
            }
        )
        resolveTrackingType(exerciseId, name)
        loadPreviousData(exerciseId, name)
    }

    fun onExerciseTrackingTypeChange(exerciseId: String, trackingType: ExerciseTrackingType) {
        val current = _activeWorkoutState.value ?: return
        val targetExercise = current.exercises.find { it.id == exerciseId } ?: return
        if (!targetExercise.isTrackingTypeEditable) return
        _activeWorkoutState.value = current.copy(
            exercises = current.exercises.map { exercise ->
                if (exercise.id == exerciseId) {
                    exercise.copy(
                        trackingType = trackingType,
                        isTrackingTypeEditable = false,
                        sets = exercise.sets.map { set ->
                            set.copy(
                                weight = "",
                                reps = "",
                                durationMinutes = "",
                                durationSeconds = "",
                                distance = "",
                                speed = "",
                                previous = null,
                                isCompleted = false,
                            )
                        }
                    )
                } else exercise
            }
        )
        val exercise = _activeWorkoutState.value?.exercises?.find { it.id == exerciseId } ?: return
        if (exercise.name.isNotBlank()) {
            loadPreviousData(exerciseId, exercise.name)
        }
    }

    private fun resolveTrackingType(exerciseId: String, exerciseName: String) {
        if (exerciseName.isBlank()) return
        viewModelScope.launch {
            val current = _activeWorkoutState.value ?: return@launch
            val exercise = current.exercises.find { it.id == exerciseId } ?: return@launch
            if (!exercise.isTrackingTypeEditable) return@launch

            val knownType = workoutDao.getTrackingTypeForExerciseName(exerciseName)
                ?: completedWorkoutDao.getMostRecentTrackingTypeForExerciseName(exerciseName)

            if (knownType != null) {
                val resolvedType = ExerciseTrackingType.fromStorage(knownType)
                val updated = _activeWorkoutState.value ?: return@launch
                _activeWorkoutState.value = updated.copy(
                    exercises = updated.exercises.map { activeExercise ->
                        if (activeExercise.id == exerciseId) {
                            activeExercise.copy(
                                trackingType = resolvedType,
                                isTrackingTypeEditable = false,
                            )
                        } else activeExercise
                    }
                )
            }
        }
    }

    private fun loadPreviousData(exerciseId: String, exerciseName: String) {
        if (exerciseName.isBlank()) return
        viewModelScope.launch {
            val previousSets = completedWorkoutDao.getAllPreviousSetsForExercise(exerciseName)
            val current = _activeWorkoutState.value ?: return@launch
            _activeWorkoutState.value = current.copy(
                exercises = current.exercises.map { exercise ->
                    if (exercise.id == exerciseId) {
                        exercise.copy(
                            sets = exercise.sets.mapIndexed { index, set ->
                                val previous = previousSets.getOrNull(index)
                                if (previous != null &&
                                    ExerciseTrackingType.fromStorage(previous.trackingType) == exercise.trackingType
                                ) {
                                    set.copy(previous = previous)
                                } else {
                                    set.copy(previous = null)
                                }
                            }
                        )
                    } else exercise
                }
            )
        }
    }

    // Dialogs

    fun showCancelDialog() {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(showCancelDialog = true)
    }

    fun dismissCancelDialog() {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(showCancelDialog = false)
    }

    fun cancelWorkout() {
        timerJob?.cancel()
        dismissRestTimer()
        _activeWorkoutState.value = null
        viewModelScope.launch { _workoutEndedEvent.emit(Unit) }
    }

    fun showFinishDialog() {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = if (hasIncompleteSets(current)) {
            current.copy(showIncompleteFinishDialog = true)
        } else {
            current.copy(showFinishDialog = true)
        }
    }

    fun dismissFinishDialog() {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(
            showFinishDialog = false,
            showIncompleteFinishDialog = false,
        )
    }

    fun finishWorkout() {
        timerJob?.cancel()
        dismissRestTimer()
        val state = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = state.copy(
            showFinishDialog = false,
            showIncompleteFinishDialog = false,
        )

        viewModelScope.launch {
            val now = System.currentTimeMillis()
            val today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"))

            val completedWorkoutId = completedWorkoutDao.insertCompletedWorkout(
                CompletedWorkoutEntity(
                    name = state.workoutName,
                    templateId = state.templateId,
                    date = today,
                    startedAt = startedAtMillis,
                    endedAt = now,
                    isQuickWorkout = state.isQuickWorkout,
                )
            )

            state.exercises.forEachIndexed { exerciseIndex, exercise ->
                if (exercise.name.isBlank()) return@forEachIndexed
                val completedExerciseId = completedWorkoutDao.insertCompletedExercise(
                    CompletedExerciseEntity(
                        completedWorkoutId = completedWorkoutId,
                        name = exercise.name,
                        orderIndex = exerciseIndex,
                        trackingType = exercise.trackingType.storageValue,
                    )
                )
                val completedSets = exercise.sets.mapIndexed { setIndex, set ->
                    CompletedSetEntity(
                        completedExerciseId = completedExerciseId,
                        orderIndex = setIndex,
                        weight = set.weight.toDoubleOrNull(),
                        reps = set.reps.toIntOrNull(),
                        durationSeconds = toTotalDurationSeconds(set),
                        distanceMiles = set.distance.toDoubleOrNull(),
                        speedMph = set.speed.toDoubleOrNull(),
                    )
                }
                if (completedSets.isNotEmpty()) {
                    completedWorkoutDao.insertCompletedSets(completedSets)
                }
            }

            _activeWorkoutState.value = null
            _workoutEndedEvent.emit(Unit)
        }
    }

    // Rest timer

    private fun startRestTimer() {
        val current = _activeWorkoutState.value ?: return
        val duration = current.restTimerDurationSeconds
        val intent = Intent(getApplication(), RestTimerService::class.java).apply {
            putExtra(RestTimerService.EXTRA_DURATION_SECONDS, duration)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getApplication<Application>().startForegroundService(intent)
        } else {
            getApplication<Application>().startService(intent)
        }
    }

    fun dismissRestTimer() {
        val intent = Intent(getApplication(), RestTimerService::class.java).apply {
            action = RestTimerService.ACTION_STOP
        }
        try {
            getApplication<Application>().startService(intent)
        } catch (_: Exception) {
            // Service may not be running
        }
    }

    private fun onRestTimerComplete() {
        // Sound and vibration are handled by the service
        // Just ensure UI state is reset
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(restTimerSecondsRemaining = 0)
    }

    // Rest timer duration dialog

    fun showRestTimerDialog() {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(showRestTimerDialog = true)
    }

    fun dismissRestTimerDialog() {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(showRestTimerDialog = false)
    }

    fun setRestTimerDuration(seconds: Int) {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(
            restTimerDurationSeconds = seconds,
            showRestTimerDialog = false,
        )
        viewModelScope.launch {
            restTimerPrefs.setDuration(seconds)
        }
    }

    // Helpers

    private fun updateSet(
        exerciseId: String,
        setIndex: Int,
        transform: (ActiveSetUiModel) -> ActiveSetUiModel,
    ) {
        val current = _activeWorkoutState.value ?: return
        _activeWorkoutState.value = current.copy(
            exercises = current.exercises.map { exercise ->
                if (exercise.id == exerciseId) {
                    exercise.copy(
                        sets = exercise.sets.mapIndexed { index, set ->
                            if (index == setIndex) transform(set)
                            else set
                        }
                    )
                } else exercise
            }
        )
    }

    private fun hasIncompleteSets(state: ActiveWorkoutUiState): Boolean {
        return state.exercises.any { exercise ->
            exercise.sets.any { set ->
                !set.isCompleted || !setHasRequiredValues(set, exercise.trackingType)
            }
        }
    }

    private fun setHasRequiredValues(
        set: ActiveSetUiModel,
        trackingType: ExerciseTrackingType,
    ): Boolean {
        return when (trackingType) {
            ExerciseTrackingType.WEIGHT_REPS -> set.weight.isNotBlank() && set.reps.isNotBlank()
            ExerciseTrackingType.DURATION -> toTotalDurationSeconds(set)?.let { it > 0 } == true
            ExerciseTrackingType.DURATION_DISTANCE -> {
                toTotalDurationSeconds(set)?.let { it > 0 } == true && set.distance.toDoubleOrNull() != null
            }
        }
    }

    private fun toTotalDurationSeconds(set: ActiveSetUiModel): Int? {
        val minutes = set.durationMinutes.toIntOrNull() ?: 0
        val seconds = set.durationSeconds.toIntOrNull() ?: 0
        val total = minutes * 60 + seconds
        return total.takeIf { it > 0 }
    }

    override fun onCleared() {
        super.onCleared()
        timerJob?.cancel()
    }
}
