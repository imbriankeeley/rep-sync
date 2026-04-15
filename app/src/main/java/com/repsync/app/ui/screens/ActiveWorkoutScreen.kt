package com.repsync.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.repsync.app.data.entity.ExerciseTrackingType
import com.repsync.app.ui.components.ExerciseNameField
import com.repsync.app.ui.theme.BackgroundCard
import com.repsync.app.ui.theme.BackgroundCardElevated
import com.repsync.app.ui.theme.BackgroundPrimary
import com.repsync.app.ui.theme.CheckmarkGreen
import com.repsync.app.ui.theme.DestructiveRed
import com.repsync.app.ui.theme.Divider
import com.repsync.app.ui.theme.InputBackground
import com.repsync.app.ui.theme.PrimaryGreen
import com.repsync.app.ui.theme.TextOnDark
import com.repsync.app.ui.theme.TextOnDarkSecondary
import com.repsync.app.ui.viewmodel.ActiveExerciseUiModel
import com.repsync.app.ui.viewmodel.ActiveSetUiModel
import com.repsync.app.ui.viewmodel.ActiveWorkoutManager
import com.repsync.app.util.formatTrackedSetSummary
import com.repsync.app.util.formatElapsedTime
import sh.calvin.reorderable.ReorderableItem
import sh.calvin.reorderable.rememberReorderableLazyListState

@Composable
fun ActiveWorkoutScreen(
    workoutId: Long? = null,
    onNavigateHome: () -> Unit,
    activeWorkoutManager: ActiveWorkoutManager,
    onNavigateToExerciseHistory: (String) -> Unit = {},
) {
    // These must run before any early return so the workout actually starts
    LaunchedEffect(workoutId) {
        if (!activeWorkoutManager.isActiveWorkoutSession(workoutId)) {
            if (workoutId != null) {
                activeWorkoutManager.loadWorkout(workoutId)
            } else {
                activeWorkoutManager.startQuickWorkout()
            }
        }
    }

    // Navigate home when workout ends (finished or cancelled)
    LaunchedEffect(Unit) {
        activeWorkoutManager.workoutEndedEvent.collect {
            onNavigateHome()
        }
    }

    val activeState by activeWorkoutManager.activeWorkoutState.collectAsState()
    val uiState = activeState ?: run {
        Box(
            modifier = Modifier.fillMaxSize().background(BackgroundPrimary),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Loading...",
                color = TextOnDarkSecondary,
                style = MaterialTheme.typography.bodyLarge,
            )
        }
        return
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(BackgroundPrimary),
        ) {
            // Header with timer
            ActiveWorkoutHeader(
                elapsedSeconds = uiState.elapsedSeconds,
                workoutName = uiState.workoutName,
                restTimerSecondsRemaining = uiState.restTimerSecondsRemaining,
                onCloseClick = activeWorkoutManager::showCancelDialog,
                onStopwatchClick = activeWorkoutManager::showRestTimerDialog,
                onSkipRestTimer = activeWorkoutManager::dismissRestTimer,
            )

            if (uiState.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Loading...",
                        color = TextOnDarkSecondary,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
            } else {
                // Exercise list + buttons
                val lazyListState = rememberLazyListState()
                val reorderableLazyListState = rememberReorderableLazyListState(lazyListState) { from, to ->
                    // Offset by 1 for the header spacer item
                    activeWorkoutManager.moveExercise(from.index - 1, to.index - 1)
                }

                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
                    state = lazyListState,
                ) {
                    item {
                        Spacer(modifier = Modifier.height(16.dp))
                    }

                    // Exercise cards (reorderable)
                    itemsIndexed(
                        items = uiState.exercises,
                        key = { _, exercise -> exercise.id },
                    ) { _, exercise ->
                        ReorderableItem(reorderableLazyListState, key = exercise.id) { isDragging ->
                            ActiveExerciseCard(
                                exercise = exercise,
                                exerciseNameSuggestions = uiState.exerciseNameSuggestions,
                                onExerciseNameChange = { name ->
                                    activeWorkoutManager.onExerciseNameChange(exercise.id, name)
                                },
                                onAddSet = { activeWorkoutManager.addSet(exercise.id) },
                                onRemoveSet = { setIndex ->
                                    activeWorkoutManager.removeSet(exercise.id, setIndex)
                                },
                                onSetWeightChange = { setIndex, weight ->
                                    activeWorkoutManager.onSetWeightChange(exercise.id, setIndex, weight)
                                },
                                onSetRepsChange = { setIndex, reps ->
                                    activeWorkoutManager.onSetRepsChange(exercise.id, setIndex, reps)
                                },
                                onSetDurationMinutesChange = { setIndex, minutes ->
                                    activeWorkoutManager.onSetDurationMinutesChange(
                                        exercise.id,
                                        setIndex,
                                        minutes,
                                    )
                                },
                                onSetDurationSecondsChange = { setIndex, seconds ->
                                    activeWorkoutManager.onSetDurationSecondsChange(
                                        exercise.id,
                                        setIndex,
                                        seconds,
                                    )
                                },
                                onSetDistanceChange = { setIndex, distance ->
                                    activeWorkoutManager.onSetDistanceChange(exercise.id, setIndex, distance)
                                },
                                onSetSpeedChange = { setIndex, speed ->
                                    activeWorkoutManager.onSetSpeedChange(exercise.id, setIndex, speed)
                                },
                                onTrackingTypeChange = { trackingType ->
                                    activeWorkoutManager.onExerciseTrackingTypeChange(
                                        exercise.id,
                                        trackingType,
                                    )
                                },
                                onToggleSetCompleted = { setIndex ->
                                    activeWorkoutManager.toggleSetCompleted(exercise.id, setIndex)
                                },
                                onRemoveExercise = {
                                    activeWorkoutManager.removeExercise(exercise.id)
                                },
                                onExerciseHistoryClick = onNavigateToExerciseHistory,
                                modifier = Modifier
                                    .longPressDraggableHandle()
                                    .graphicsLayer {
                                        alpha = if (isDragging) 0.85f else 1f
                                    }
                                    .then(
                                        if (isDragging) Modifier
                                            .zIndex(1f)
                                            .shadow(8.dp, RoundedCornerShape(16.dp))
                                        else Modifier
                                    ),
                            )
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                    }

                    // Add Exercise button
                    item {
                        Spacer(modifier = Modifier.height(4.dp))
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(48.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(PrimaryGreen)
                                .clickable { activeWorkoutManager.addExercise() },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "Add Exercise",
                                color = TextOnDark,
                                style = MaterialTheme.typography.labelLarge,
                            )
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                    }

                    // Finish Workout button
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(52.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(PrimaryGreen)
                                .clickable { activeWorkoutManager.showFinishDialog() },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "Finish Workout",
                                color = TextOnDark,
                                style = MaterialTheme.typography.labelLarge,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                        Spacer(modifier = Modifier.height(32.dp))
                    }

                    // Extra space when keyboard is open so content can scroll above it
                    item {
                        val imeBottom = WindowInsets.ime.getBottom(LocalDensity.current)
                        if (imeBottom > 0) {
                            Spacer(
                                modifier = Modifier.height(
                                    with(LocalDensity.current) { imeBottom.toDp() }
                                ),
                            )
                        }
                    }
                }
            }
        }

        // Cancel Workout dialog
        if (uiState.showCancelDialog) {
            CancelWorkoutDialog(
                onResume = activeWorkoutManager::dismissCancelDialog,
                onCancel = activeWorkoutManager::cancelWorkout,
            )
        }

        // Finish Workout dialog
        if (uiState.showFinishDialog) {
            FinishWorkoutDialog(
                title = "Finish Workout?",
                message = null,
                dismissLabel = "Cancel",
                confirmLabel = "Finish",
                onDismiss = activeWorkoutManager::dismissFinishDialog,
                onConfirm = activeWorkoutManager::finishWorkout,
            )
        }

        if (uiState.showIncompleteFinishDialog) {
            FinishWorkoutDialog(
                title = "Workout Incomplete",
                message = "Some sets are unchecked or still missing required values. Do you still want to finish this workout?",
                dismissLabel = "Go Back",
                confirmLabel = "Finish Anyway",
                onDismiss = activeWorkoutManager::dismissFinishDialog,
                onConfirm = activeWorkoutManager::finishWorkout,
            )
        }

        // Rest Timer Duration dialog
        if (uiState.showRestTimerDialog) {
            RestTimerDurationDialog(
                currentDurationSeconds = uiState.restTimerDurationSeconds,
                onDismiss = activeWorkoutManager::dismissRestTimerDialog,
                onConfirm = { seconds -> activeWorkoutManager.setRestTimerDuration(seconds) },
            )
        }
    }
}

@Composable
private fun ActiveWorkoutHeader(
    elapsedSeconds: Long,
    workoutName: String,
    restTimerSecondsRemaining: Int,
    onCloseClick: () -> Unit,
    onStopwatchClick: () -> Unit,
    onSkipRestTimer: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(BackgroundCard)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Timer icon (tap to configure rest timer)
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(BackgroundCardElevated)
                    .clickable { onStopwatchClick() },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "\u23F1",
                    fontSize = 18.sp,
                )
            }

            // Timer display
            Text(
                text = formatElapsedTime(elapsedSeconds),
                color = TextOnDark,
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
            )

            // X close button (destructive)
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(DestructiveRed)
                    .clickable { onCloseClick() },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "X",
                    color = TextOnDark,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Workout name
        Text(
            text = workoutName,
            color = TextOnDark,
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(8.dp))
        HorizontalDivider(color = Divider, thickness = 0.5.dp)

        // Rest timer banner
        if (restTimerSecondsRemaining > 0) {
            Spacer(modifier = Modifier.height(8.dp))
            RestTimerBanner(
                secondsRemaining = restTimerSecondsRemaining,
                onSkip = onSkipRestTimer,
            )
        }
    }
}

@Composable
private fun ActiveExerciseCard(
    exercise: ActiveExerciseUiModel,
    exerciseNameSuggestions: List<String>,
    onExerciseNameChange: (String) -> Unit,
    onAddSet: () -> Unit,
    onRemoveSet: (Int) -> Unit,
    onSetWeightChange: (Int, String) -> Unit,
    onSetRepsChange: (Int, String) -> Unit,
    onSetDurationMinutesChange: (Int, String) -> Unit,
    onSetDurationSecondsChange: (Int, String) -> Unit,
    onSetDistanceChange: (Int, String) -> Unit,
    onSetSpeedChange: (Int, String) -> Unit,
    onTrackingTypeChange: (ExerciseTrackingType) -> Unit,
    onToggleSetCompleted: (Int) -> Unit,
    onRemoveExercise: () -> Unit,
    onExerciseHistoryClick: (String) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(BackgroundCard)
            .padding(16.dp),
    ) {
        // Exercise name row with delete button
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            ExerciseNameField(
                name = exercise.name,
                suggestions = exerciseNameSuggestions,
                onNameChange = onExerciseNameChange,
                onSuggestionSelected = onExerciseNameChange,
                modifier = Modifier.weight(1f),
            )
            if (exercise.name.isNotBlank()) {
                Spacer(modifier = Modifier.width(6.dp))
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(BackgroundCardElevated)
                        .clickable { onExerciseHistoryClick(exercise.name) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "\u23F3",
                        fontSize = 14.sp,
                    )
                }
            }
            Spacer(modifier = Modifier.width(6.dp))
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(BackgroundCardElevated)
                    .clickable { onRemoveExercise() },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "X",
                    color = TextOnDarkSecondary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        if (exercise.isTrackingTypeEditable) {
            ActiveTrackingTypeSelector(
                selectedType = exercise.trackingType,
                onTypeSelected = onTrackingTypeChange,
            )
        } else {
            TrackingTypePill(trackingType = exercise.trackingType)
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Table header
        ActiveSetHeaderRow(trackingType = exercise.trackingType)

        Spacer(modifier = Modifier.height(8.dp))

        // Set rows
        exercise.sets.forEachIndexed { index, set ->
            ActiveSetRow(
                setNumber = index + 1,
                set = set,
                trackingType = exercise.trackingType,
                onWeightChange = { onSetWeightChange(index, it) },
                onRepsChange = { onSetRepsChange(index, it) },
                onDurationMinutesChange = { onSetDurationMinutesChange(index, it) },
                onDurationSecondsChange = { onSetDurationSecondsChange(index, it) },
                onDistanceChange = { onSetDistanceChange(index, it) },
                onSpeedChange = { onSetSpeedChange(index, it) },
                onToggleCompleted = { onToggleSetCompleted(index) },
                onRemove = if (exercise.sets.size > 1) {
                    { onRemoveSet(index) }
                } else null,
            )
            if (index < exercise.sets.size - 1) {
                Spacer(modifier = Modifier.height(6.dp))
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Add Set button
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(36.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(BackgroundCardElevated)
                .clickable { onAddSet() },
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "+ Add Set",
                color = TextOnDarkSecondary,
                style = MaterialTheme.typography.labelMedium,
            )
        }
    }
}

@Composable
private fun ActiveTrackingTypeSelector(
    selectedType: ExerciseTrackingType,
    onTypeSelected: (ExerciseTrackingType) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        ExerciseTrackingType.entries.forEach { type ->
            val isSelected = type == selectedType
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (isSelected) PrimaryGreen else BackgroundCardElevated)
                    .clickable { onTypeSelected(type) }
                    .padding(horizontal = 8.dp, vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = activeTrackingTypeLabel(type),
                    color = if (isSelected) TextOnDark else TextOnDarkSecondary,
                    style = MaterialTheme.typography.labelMedium,
                )
            }
        }
    }
}

@Composable
private fun TrackingTypePill(trackingType: ExerciseTrackingType) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(BackgroundCardElevated)
            .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Text(
            text = activeTrackingTypeLabel(trackingType),
            color = TextOnDarkSecondary,
            style = MaterialTheme.typography.labelMedium,
        )
    }
}

@Composable
private fun ActiveSetHeaderRow(trackingType: ExerciseTrackingType) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Set",
            modifier = Modifier.width(36.dp),
            color = TextOnDarkSecondary,
            style = MaterialTheme.typography.titleSmall,
            textAlign = TextAlign.Center,
        )
        Text(
            text = "Previous",
            modifier = Modifier.weight(1.2f),
            color = TextOnDarkSecondary,
            style = MaterialTheme.typography.titleSmall,
            textAlign = TextAlign.Center,
        )
        when (trackingType) {
            ExerciseTrackingType.WEIGHT_REPS -> {
                Text(
                    text = "Details",
                    modifier = Modifier.weight(2f),
                    color = TextOnDarkSecondary,
                    style = MaterialTheme.typography.titleSmall,
                    textAlign = TextAlign.Center,
                )
            }
            ExerciseTrackingType.DURATION -> {
                Text(
                    text = "Details",
                    modifier = Modifier.weight(1.6f),
                    color = TextOnDarkSecondary,
                    style = MaterialTheme.typography.titleSmall,
                    textAlign = TextAlign.Center,
                )
            }
            ExerciseTrackingType.DURATION_DISTANCE -> {
                Text(
                    text = "Details",
                    modifier = Modifier.weight(3.1f),
                    color = TextOnDarkSecondary,
                    style = MaterialTheme.typography.titleSmall,
                    textAlign = TextAlign.Center,
                )
            }
        }
        Spacer(modifier = Modifier.width(36.dp))
    }
}

@Composable
private fun ActiveSetRow(
    setNumber: Int,
    set: ActiveSetUiModel,
    trackingType: ExerciseTrackingType,
    onWeightChange: (String) -> Unit,
    onRepsChange: (String) -> Unit,
    onDurationMinutesChange: (String) -> Unit,
    onDurationSecondsChange: (String) -> Unit,
    onDistanceChange: (String) -> Unit,
    onSpeedChange: (String) -> Unit,
    onToggleCompleted: () -> Unit,
    onRemove: (() -> Unit)?,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
    ) {
        ActiveSetTopRow(
            setNumber = setNumber,
            set = set,
            trackingType = trackingType,
            onToggleCompleted = onToggleCompleted,
            onRemove = onRemove,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(modifier = Modifier.height(8.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 2.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            when (trackingType) {
                ExerciseTrackingType.WEIGHT_REPS -> {
                    LabeledSetInputField(
                        label = "Weight",
                        value = set.weight,
                        placeholder = "+lbs",
                        onValueChange = onWeightChange,
                        modifier = Modifier.weight(1f),
                        keyboardType = KeyboardType.Decimal,
                    )
                    LabeledSetInputField(
                        label = "Reps",
                        value = set.reps,
                        placeholder = "Reps",
                        onValueChange = onRepsChange,
                        modifier = Modifier.weight(1f),
                        keyboardType = KeyboardType.Number,
                    )
                }
                ExerciseTrackingType.DURATION -> {
                    LabeledSetInputField(
                        label = "Min",
                        value = set.durationMinutes,
                        placeholder = "0",
                        onValueChange = onDurationMinutesChange,
                        modifier = Modifier.weight(1f),
                        keyboardType = KeyboardType.Number,
                    )
                    LabeledSetInputField(
                        label = "Sec",
                        value = set.durationSeconds,
                        placeholder = "00",
                        onValueChange = onDurationSecondsChange,
                        modifier = Modifier.weight(1f),
                        keyboardType = KeyboardType.Number,
                    )
                }
                ExerciseTrackingType.DURATION_DISTANCE -> {
                    LabeledSetInputField(
                        label = "Min",
                        value = set.durationMinutes,
                        placeholder = "0",
                        onValueChange = onDurationMinutesChange,
                        modifier = Modifier.weight(1f),
                        keyboardType = KeyboardType.Number,
                    )
                    LabeledSetInputField(
                        label = "Sec",
                        value = set.durationSeconds,
                        placeholder = "00",
                        onValueChange = onDurationSecondsChange,
                        modifier = Modifier.weight(1f),
                        keyboardType = KeyboardType.Number,
                    )
                    LabeledSetInputField(
                        label = "Miles",
                        value = set.distance,
                        placeholder = "0.0",
                        onValueChange = onDistanceChange,
                        modifier = Modifier.weight(1.2f),
                        keyboardType = KeyboardType.Decimal,
                    )
                    LabeledSetInputField(
                        label = "MPH",
                        value = set.speed,
                        placeholder = "0.0",
                        onValueChange = onSpeedChange,
                        modifier = Modifier.weight(1.1f),
                        keyboardType = KeyboardType.Decimal,
                    )
                }
            }
        }
    }
}

@Composable
private fun ActiveSetTopRow(
    setNumber: Int,
    set: ActiveSetUiModel,
    trackingType: ExerciseTrackingType,
    onToggleCompleted: () -> Unit,
    onRemove: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(BackgroundCardElevated)
                .then(if (onRemove != null) Modifier.clickable { onRemove() } else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "$setNumber",
                color = if (onRemove != null) DestructiveRed else TextOnDarkSecondary,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
            )
        }
        Spacer(modifier = Modifier.width(8.dp))
        Box(
            modifier = Modifier.weight(1.2f),
            contentAlignment = Alignment.CenterStart,
        ) {
            val previousText = if (set.isCompleted) {
                currentSetSummary(set, trackingType)
            } else {
                set.previous?.let { prev ->
                    formatTrackedSetSummary(
                        trackingType = ExerciseTrackingType.fromStorage(prev.trackingType),
                        weight = prev.weight,
                        reps = prev.reps,
                        durationSeconds = prev.durationSeconds,
                        distanceMiles = prev.distanceMiles,
                        speedMph = prev.speedMph,
                    )
                } ?: "-"
            }
            Text(
                text = previousText,
                color = if (set.isCompleted) CheckmarkGreen else TextOnDarkSecondary,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Start,
            )
        }
        Spacer(modifier = Modifier.width(4.dp))
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(if (set.isCompleted) CheckmarkGreen else BackgroundCardElevated)
                .clickable { onToggleCompleted() },
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "\u2713",
                color = if (set.isCompleted) TextOnDark else TextOnDarkSecondary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

@Composable
private fun LabeledSetInputField(
    label: String,
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Number,
) {
    Column(modifier = modifier) {
        Text(
            text = label,
            color = TextOnDarkSecondary,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(start = 6.dp, bottom = 4.dp),
        )
        ActiveSetInputField(
            value = value,
            placeholder = placeholder,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            keyboardType = keyboardType,
        )
    }
}

private fun currentSetSummary(
    set: ActiveSetUiModel,
    trackingType: ExerciseTrackingType,
): String {
    val totalSeconds = ((set.durationMinutes.toIntOrNull() ?: 0) * 60) +
        (set.durationSeconds.toIntOrNull() ?: 0)
    return formatTrackedSetSummary(
        trackingType = trackingType,
        weight = set.weight.toDoubleOrNull(),
        reps = set.reps.toIntOrNull(),
        durationSeconds = totalSeconds.takeIf { it > 0 },
        distanceMiles = set.distance.toDoubleOrNull(),
        speedMph = set.speed.toDoubleOrNull(),
    )
}

private fun activeTrackingTypeLabel(type: ExerciseTrackingType): String {
    return when (type) {
        ExerciseTrackingType.WEIGHT_REPS -> "Weight + Reps"
        ExerciseTrackingType.DURATION -> "Time"
        ExerciseTrackingType.DURATION_DISTANCE -> "Time + Distance + Speed"
    }
}

@Composable
private fun ActiveSetInputField(
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Number,
) {
    var textFieldValue by remember { mutableStateOf(TextFieldValue(text = value)) }
    var needsSelectAll by remember { mutableStateOf(false) }

    // Sync external value changes (e.g. from ViewModel) without fighting local edits
    LaunchedEffect(value) {
        if (value != textFieldValue.text) {
            textFieldValue = TextFieldValue(
                text = value,
                selection = TextRange(value.length),
            )
        }
    }

    // Apply select-all after focus, deferred so it doesn't conflict with IME
    LaunchedEffect(needsSelectAll) {
        if (needsSelectAll) {
            textFieldValue = textFieldValue.copy(
                selection = TextRange(0, textFieldValue.text.length)
            )
            needsSelectAll = false
        }
    }

    BasicTextField(
        value = textFieldValue,
        onValueChange = { newValue ->
            textFieldValue = newValue
            onValueChange(newValue.text)
        },
        modifier = modifier
            .padding(horizontal = 4.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(InputBackground)
            .onFocusChanged { focusState ->
                if (focusState.isFocused && textFieldValue.text.isNotEmpty()) {
                    needsSelectAll = true
                }
            }
            .padding(horizontal = 8.dp, vertical = 8.dp),
        textStyle = MaterialTheme.typography.bodyMedium.copy(
            color = TextOnDark,
            textAlign = TextAlign.Center,
        ),
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        cursorBrush = SolidColor(PrimaryGreen),
        decorationBox = { innerTextField ->
            Box(contentAlignment = Alignment.Center) {
                if (textFieldValue.text.isEmpty()) {
                    Text(
                        text = placeholder,
                        color = TextOnDarkSecondary.copy(alpha = 0.5f),
                        style = MaterialTheme.typography.bodyMedium,
                        textAlign = TextAlign.Center,
                    )
                }
                innerTextField()
            }
        },
    )
}

@Composable
private fun RestTimerBanner(
    secondsRemaining: Int,
    onSkip: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(BackgroundCardElevated)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Rest",
            color = TextOnDarkSecondary,
            style = MaterialTheme.typography.labelMedium,
        )

        Text(
            text = formatElapsedTime(secondsRemaining.toLong()),
            color = PrimaryGreen,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )

        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(BackgroundCard)
                .clickable { onSkip() }
                .padding(horizontal = 12.dp, vertical = 6.dp),
        ) {
            Text(
                text = "Skip",
                color = TextOnDarkSecondary,
                style = MaterialTheme.typography.labelMedium,
            )
        }
    }
}

@Composable
private fun RestTimerDurationDialog(
    currentDurationSeconds: Int,
    onDismiss: () -> Unit,
    onConfirm: (Int) -> Unit,
) {
    var selectedSeconds by remember { mutableStateOf(currentDurationSeconds) }
    var customInput by remember { mutableStateOf("") }

    val presets = listOf(30 to "30s", 60 to "1m", 90 to "1m 30s", 120 to "2m")

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundPrimary.copy(alpha = 0.7f))
            .clickable { onDismiss() },
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(BackgroundCard)
                .clickable(enabled = false) {}
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Rest Timer",
                color = TextOnDark,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Preset chips
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                presets.forEach { (seconds, label) ->
                    val isSelected = selectedSeconds == seconds && customInput.isEmpty()
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(40.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (isSelected) PrimaryGreen else BackgroundCardElevated)
                            .clickable {
                                selectedSeconds = seconds
                                customInput = ""
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = label,
                            color = if (isSelected) TextOnDark else TextOnDarkSecondary,
                            style = MaterialTheme.typography.labelMedium,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Custom input
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "Custom (sec):",
                    color = TextOnDarkSecondary,
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.weight(1f),
                )
                BasicTextField(
                    value = customInput,
                    onValueChange = { input ->
                        customInput = input.filter { it.isDigit() }
                        customInput.toIntOrNull()?.let { selectedSeconds = it }
                    },
                    modifier = Modifier
                        .width(80.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(InputBackground)
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    textStyle = MaterialTheme.typography.bodyMedium.copy(
                        color = TextOnDark,
                        textAlign = TextAlign.Center,
                    ),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    cursorBrush = SolidColor(PrimaryGreen),
                    decorationBox = { innerTextField ->
                        Box(contentAlignment = Alignment.Center) {
                            if (customInput.isEmpty()) {
                                Text(
                                    text = "${currentDurationSeconds}s",
                                    color = TextOnDarkSecondary.copy(alpha = 0.5f),
                                    style = MaterialTheme.typography.bodyMedium,
                                    textAlign = TextAlign.Center,
                                )
                            }
                            innerTextField()
                        }
                    },
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Cancel / Set buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(BackgroundCardElevated)
                        .clickable { onDismiss() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Cancel",
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(PrimaryGreen)
                        .clickable {
                            val finalSeconds = selectedSeconds.coerceAtLeast(5)
                            onConfirm(finalSeconds)
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Set",
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}

@Composable
private fun CancelWorkoutDialog(
    onResume: () -> Unit,
    onCancel: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundPrimary.copy(alpha = 0.7f))
            .clickable { onResume() },
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(BackgroundCard)
                .clickable(enabled = false) {}
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Cancel Workout?",
                color = TextOnDark,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(24.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Resume button
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(BackgroundCardElevated)
                        .clickable { onResume() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Resume",
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }

                // Cancel button (destructive)
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(DestructiveRed)
                        .clickable { onCancel() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Cancel",
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}

@Composable
private fun FinishWorkoutDialog(
    title: String,
    message: String?,
    dismissLabel: String,
    confirmLabel: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundPrimary.copy(alpha = 0.7f))
            .clickable { onDismiss() },
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(BackgroundCard)
                .clickable(enabled = false) {}
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = title,
                color = TextOnDark,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )

            if (!message.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = message,
                    color = TextOnDarkSecondary,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Cancel button
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(BackgroundCardElevated)
                        .clickable { onDismiss() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = dismissLabel,
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }

                // Finish button (primary green)
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(PrimaryGreen)
                        .clickable { onConfirm() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = confirmLabel,
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}
