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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.lifecycle.viewmodel.compose.viewModel
import com.repsync.app.data.entity.ExerciseTrackingType
import com.repsync.app.ui.components.ExerciseNameField
import com.repsync.app.ui.theme.BackgroundCard
import com.repsync.app.ui.theme.BackgroundCardElevated
import com.repsync.app.ui.theme.BackgroundPrimary
import com.repsync.app.ui.theme.DestructiveRed
import com.repsync.app.ui.theme.PrimaryGreen
import com.repsync.app.ui.theme.TextOnDark
import com.repsync.app.ui.theme.TextOnDarkSecondary
import com.repsync.app.ui.viewmodel.ExerciseUiModel
import com.repsync.app.ui.viewmodel.NewWorkoutViewModel
import sh.calvin.reorderable.ReorderableItem
import sh.calvin.reorderable.rememberReorderableLazyListState

@Composable
fun NewWorkoutScreen(
    editWorkoutId: Long? = null,
    onNavigateBack: () -> Unit,
    viewModel: NewWorkoutViewModel = viewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    // Load workout for editing if ID provided
    LaunchedEffect(editWorkoutId) {
        if (editWorkoutId != null && editWorkoutId > 0) {
            viewModel.loadWorkoutForEditing(editWorkoutId)
        }
    }

    // Navigate back after save
    LaunchedEffect(uiState.isSaved) {
        if (uiState.isSaved) {
            onNavigateBack()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundPrimary),
    ) {
        // Header
        NewWorkoutHeader(
            isEditing = editWorkoutId != null && editWorkoutId > 0,
            onBackClick = onNavigateBack,
            onSaveClick = viewModel::saveWorkout,
            canSave = uiState.workoutName.isNotBlank() && uiState.exercises.isNotEmpty(),
        )

        // Content
        val lazyListState = rememberLazyListState()
        val reorderableLazyListState = rememberReorderableLazyListState(lazyListState) { from, to ->
            // Offset by 1 for the workout name input item
            viewModel.moveExercise(from.index - 1, to.index - 1)
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            state = lazyListState,
        ) {
            // Workout name input
            item {
                Spacer(modifier = Modifier.height(16.dp))
                WorkoutNameInput(
                    name = uiState.workoutName,
                    onNameChange = viewModel::onWorkoutNameChange,
                )
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Exercise cards (reorderable)
            itemsIndexed(
                items = uiState.exercises,
                key = { _, exercise -> exercise.id },
            ) { _, exercise ->
                ReorderableItem(reorderableLazyListState, key = exercise.id) { isDragging ->
                    ExerciseCard(
                        exercise = exercise,
                        exerciseNameSuggestions = uiState.exerciseNameSuggestions,
                        onExerciseNameChange = { name ->
                            viewModel.onExerciseNameChange(exercise.id, name)
                        },
                        onTrackingTypeChange = { trackingType ->
                            viewModel.onExerciseTrackingTypeChange(exercise.id, trackingType)
                        },
                        onAddSet = { viewModel.addSet(exercise.id) },
                        onRemoveSet = { setIndex -> viewModel.removeSet(exercise.id, setIndex) },
                        onRemoveExercise = { viewModel.removeExercise(exercise.id) },
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
                        .clickable { viewModel.addExercise() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Add Exercise",
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
                Spacer(modifier = Modifier.height(24.dp))
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

@Composable
private fun NewWorkoutHeader(
    isEditing: Boolean,
    onBackClick: () -> Unit,
    onSaveClick: () -> Unit,
    canSave: Boolean,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(BackgroundCard)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Back button
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(BackgroundCardElevated)
                .clickable { onBackClick() },
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "<",
                color = TextOnDark,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
            )
        }

        Text(
            text = if (isEditing) "Edit Workout" else "New Workout",
            color = TextOnDark,
            style = MaterialTheme.typography.headlineLarge,
        )

        // Save button
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(if (canSave) PrimaryGreen else BackgroundCardElevated)
                .clickable(enabled = canSave) { onSaveClick() }
                .padding(horizontal = 20.dp, vertical = 8.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Save",
                color = if (canSave) TextOnDark else TextOnDarkSecondary,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun WorkoutNameInput(
    name: String,
    onNameChange: (String) -> Unit,
) {
    BasicTextField(
        value = name,
        onValueChange = onNameChange,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(BackgroundCard)
            .padding(horizontal = 20.dp, vertical = 16.dp),
        textStyle = MaterialTheme.typography.bodyLarge.copy(color = TextOnDark),
        singleLine = true,
        cursorBrush = SolidColor(PrimaryGreen),
        decorationBox = { innerTextField ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Name: ",
                    color = TextOnDarkSecondary,
                    style = MaterialTheme.typography.bodyLarge,
                )
                Box(modifier = Modifier.weight(1f)) {
                    if (name.isEmpty()) {
                        Text(
                            text = "Push",
                            color = TextOnDarkSecondary.copy(alpha = 0.5f),
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }
                    innerTextField()
                }
            }
        },
    )
}

@Composable
private fun ExerciseCard(
    exercise: ExerciseUiModel,
    exerciseNameSuggestions: List<String>,
    onExerciseNameChange: (String) -> Unit,
    onTrackingTypeChange: (ExerciseTrackingType) -> Unit,
    onAddSet: () -> Unit,
    onRemoveSet: (Int) -> Unit,
    onRemoveExercise: () -> Unit,
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
            Spacer(modifier = Modifier.width(8.dp))
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

        TrackingTypeSelector(
            selectedType = exercise.trackingType,
            onTypeSelected = onTrackingTypeChange,
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Sets display — compact row of set badges
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Sets",
                color = TextOnDarkSecondary,
                style = MaterialTheme.typography.titleSmall,
            )
            Spacer(modifier = Modifier.width(12.dp))

            // Set number badges in a flowing row
            exercise.sets.forEachIndexed { index, _ ->
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(BackgroundCardElevated)
                        .then(
                            if (exercise.sets.size > 1) {
                                Modifier.clickable { onRemoveSet(index) }
                            } else Modifier
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "${index + 1}",
                        color = if (exercise.sets.size > 1) DestructiveRed else TextOnDarkSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                    )
                }
                Spacer(modifier = Modifier.width(6.dp))
            }

            Spacer(modifier = Modifier.weight(1f))

            // Set count label
            Text(
                text = "${exercise.sets.size} total",
                color = TextOnDarkSecondary.copy(alpha = 0.6f),
                style = MaterialTheme.typography.bodySmall,
            )
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
private fun TrackingTypeSelector(
    selectedType: ExerciseTrackingType,
    onTypeSelected: (ExerciseTrackingType) -> Unit,
) {
    Column {
        Text(
            text = "Tracking",
            color = TextOnDarkSecondary,
            style = MaterialTheme.typography.titleSmall,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ExerciseTrackingType.entries.forEach { type ->
                val isSelected = selectedType == type
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
                        text = trackingTypeSelectorLabel(type),
                        color = if (isSelected) TextOnDark else TextOnDarkSecondary,
                        style = MaterialTheme.typography.labelMedium,
                    )
                }
            }
        }
    }
}

private fun trackingTypeSelectorLabel(type: ExerciseTrackingType): String {
    return when (type) {
        ExerciseTrackingType.WEIGHT_REPS -> "Weight + Reps"
        ExerciseTrackingType.DURATION -> "Time"
        ExerciseTrackingType.DURATION_DISTANCE -> "Time + Dist + Speed"
    }
}
