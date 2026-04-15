package com.repsync.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.repsync.app.data.entity.CompletedExerciseWithSets
import com.repsync.app.data.entity.CompletedWorkoutWithExercises
import com.repsync.app.data.entity.ExerciseTrackingType
import com.repsync.app.ui.theme.BackgroundCard
import com.repsync.app.ui.theme.BackgroundCardElevated
import com.repsync.app.ui.theme.BackgroundPrimary
import com.repsync.app.ui.theme.CalendarWorkoutDay
import com.repsync.app.ui.theme.DestructiveRed
import com.repsync.app.ui.theme.Divider
import com.repsync.app.ui.theme.PrimaryGreen
import com.repsync.app.ui.theme.TextOnDark
import com.repsync.app.ui.theme.TextOnDarkSecondary
import com.repsync.app.ui.viewmodel.DayViewViewModel
import com.repsync.app.util.formatTrackedSetSummary
import com.repsync.app.util.formatWeightValue
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

@Composable
fun DayViewScreen(
    date: LocalDate,
    onNavigateBack: () -> Unit,
    onNavigateToExerciseHistory: (String) -> Unit = {},
    viewModel: DayViewViewModel = viewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(date) {
        viewModel.loadDate(date)
    }

    // Auto-dismiss success toasts
    LaunchedEffect(uiState.templateSaved) {
        if (uiState.templateSaved) {
            kotlinx.coroutines.delay(2000)
            viewModel.clearTemplateSavedFlag()
        }
    }

    LaunchedEffect(uiState.workoutCopied) {
        if (uiState.workoutCopied) {
            kotlinx.coroutines.delay(2000)
            viewModel.clearWorkoutCopiedFlag()
        }
    }

    LaunchedEffect(uiState.workoutDeleted) {
        if (uiState.workoutDeleted) {
            kotlinx.coroutines.delay(2000)
            viewModel.clearWorkoutDeletedFlag()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(BackgroundPrimary),
        ) {
            // Header
            DayViewHeader(
                date = date,
                onBackClick = onNavigateBack,
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
            } else if (uiState.workouts.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "No workouts on this day",
                        color = TextOnDarkSecondary,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
                ) {
                    item {
                        Spacer(modifier = Modifier.height(16.dp))
                    }

                    items(
                        items = uiState.workouts,
                        key = { it.workout.id },
                    ) { workoutWithExercises ->
                        CompletedWorkoutCard(
                            workoutWithExercises = workoutWithExercises,
                            onCopyToDay = { viewModel.showCopyDatePicker(workoutWithExercises.workout.id) },
                            onSaveAsTemplate = { viewModel.showSaveTemplateDialog(workoutWithExercises.workout.id) },
                            onRemove = { viewModel.showDeleteDialog(workoutWithExercises.workout.id) },
                            onExerciseNameClick = onNavigateToExerciseHistory,
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                    }

                    item {
                        Spacer(modifier = Modifier.height(16.dp))
                    }
                }
            }
        }

        // Success banners
        if (uiState.templateSaved) {
            SuccessBanner(text = "Template saved!")
        }
        if (uiState.workoutCopied) {
            SuccessBanner(text = "Workout copied!")
        }
        if (uiState.workoutDeleted) {
            SuccessBanner(text = "Workout removed!")
        }

        // Copy to date picker dialog
        if (uiState.showCopyDatePicker) {
            CopyToDateDialog(
                onDismiss = viewModel::dismissCopyDatePicker,
                onDateSelected = viewModel::copyWorkoutToDate,
            )
        }

        // Save as template dialog
        if (uiState.showSaveTemplateDialog) {
            val workout = uiState.workouts.find { it.workout.id == uiState.savingTemplateWorkoutId }
            SaveAsTemplateDialog(
                defaultName = workout?.workout?.name ?: "",
                onDismiss = viewModel::dismissSaveTemplateDialog,
                onSave = viewModel::saveAsTemplate,
            )
        }

        // Delete workout confirmation dialog
        if (uiState.showDeleteDialog) {
            DeleteWorkoutDialog(
                onDismiss = viewModel::dismissDeleteDialog,
                onConfirm = viewModel::deleteWorkout,
            )
        }
    }
}

@Composable
private fun DayViewHeader(
    date: LocalDate,
    onBackClick: () -> Unit,
) {
    val dateText = date.format(
        DateTimeFormatter.ofPattern("MMMM d, yyyy")
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(BackgroundCard)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Back button
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
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

        // Date title
        Text(
            text = dateText,
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp),
            color = TextOnDark,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )

        // Spacer to balance the back button
        Spacer(modifier = Modifier.width(40.dp))
    }
}

@Composable
private fun CompletedWorkoutCard(
    workoutWithExercises: CompletedWorkoutWithExercises,
    onCopyToDay: () -> Unit,
    onSaveAsTemplate: () -> Unit,
    onRemove: () -> Unit,
    onExerciseNameClick: (String) -> Unit = {},
) {
    val workout = workoutWithExercises.workout
    val durationText = if (workout.endedAt != null) {
        val durationSec = (workout.endedAt - workout.startedAt) / 1000
        val minutes = durationSec / 60
        val seconds = durationSec % 60
        "%d:%02d".format(minutes, seconds)
    } else {
        "In progress"
    }

    val typeLabel = if (workout.isQuickWorkout) "Quick Workout" else ""

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(BackgroundCard)
            .padding(16.dp),
    ) {
        // Workout name + duration
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = workout.name,
                    color = TextOnDark,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
                if (typeLabel.isNotEmpty()) {
                    Text(
                        text = typeLabel,
                        color = PrimaryGreen,
                        style = MaterialTheme.typography.labelMedium,
                    )
                }
            }
            Text(
                text = durationText,
                color = TextOnDarkSecondary,
                style = MaterialTheme.typography.bodyLarge,
            )
        }

        Spacer(modifier = Modifier.height(12.dp))
        HorizontalDivider(color = Divider, thickness = 0.5.dp)
        Spacer(modifier = Modifier.height(12.dp))

        // Exercise summary
        workoutWithExercises.exercises.forEachIndexed { index, exerciseWithSets ->
            ExerciseSummaryRow(
                exerciseWithSets = exerciseWithSets,
                onExerciseNameClick = onExerciseNameClick,
            )
            if (index < workoutWithExercises.exercises.size - 1) {
                Spacer(modifier = Modifier.height(6.dp))
                HorizontalDivider(color = Divider, thickness = 0.5.dp)
                Spacer(modifier = Modifier.height(6.dp))
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Action buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // Copy to another day
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(BackgroundCardElevated)
                    .clickable { onCopyToDay() },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Copy",
                    color = TextOnDark,
                    style = MaterialTheme.typography.labelLarge,
                )
            }

            // Save as template
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(PrimaryGreen)
                    .clickable { onSaveAsTemplate() },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Template",
                    color = TextOnDark,
                    style = MaterialTheme.typography.labelLarge,
                )
            }

            // Remove workout
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(DestructiveRed)
                    .clickable { onRemove() },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Remove",
                    color = TextOnDark,
                    style = MaterialTheme.typography.labelLarge,
                )
            }
        }
    }
}

@Composable
private fun ExerciseSummaryRow(
    exerciseWithSets: CompletedExerciseWithSets,
    onExerciseNameClick: (String) -> Unit = {},
) {
    val sortedSets = exerciseWithSets.sets.sortedBy { it.orderIndex }
    val trackingType = ExerciseTrackingType.fromStorage(exerciseWithSets.exercise.trackingType)
    val bestSet = when (trackingType) {
        ExerciseTrackingType.WEIGHT_REPS -> exerciseWithSets.sets.maxByOrNull { it.weight ?: 0.0 }
        ExerciseTrackingType.DURATION -> exerciseWithSets.sets.maxByOrNull { it.durationSeconds ?: 0 }
        ExerciseTrackingType.DURATION_DISTANCE -> exerciseWithSets.sets.maxByOrNull { it.distanceMiles ?: 0.0 }
    }

    Column {
        // Exercise name header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onExerciseNameClick(exerciseWithSets.exercise.name) },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = exerciseWithSets.exercise.name,
                color = PrimaryGreen,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = "\u23F3",
                fontSize = 14.sp,
            )
        }

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = trackingType.displayName,
            color = TextOnDarkSecondary.copy(alpha = 0.5f),
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
        )

        Spacer(modifier = Modifier.height(4.dp))

        // Set rows
        sortedSets.forEachIndexed { index, set ->
            val isBest = set == bestSet && sortedSets.size > 1
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Set number
                Text(
                    text = "${index + 1}",
                    color = TextOnDarkSecondary,
                    fontSize = 14.sp,
                    modifier = Modifier.width(24.dp),
                )
                // Trophy for best set
                if (isBest) {
                    Text(
                        text = "\uD83C\uDFC6",
                        fontSize = 12.sp,
                        modifier = Modifier.width(12.dp),
                    )
                } else {
                    Spacer(modifier = Modifier.width(12.dp))
                }

                Spacer(modifier = Modifier.weight(1f))

                Text(
                    text = formatTrackedSetSummary(
                        trackingType = trackingType,
                        weight = set.weight,
                        reps = set.reps,
                        durationSeconds = set.durationSeconds,
                        distanceMiles = set.distanceMiles,
                        speedMph = set.speedMph,
                    ),
                    color = TextOnDark,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
private fun CopyToDateDialog(
    onDismiss: () -> Unit,
    onDateSelected: (LocalDate) -> Unit,
) {
    var selectedMonth by remember { mutableStateOf(YearMonth.now()) }
    var selectedDate by remember { mutableStateOf<LocalDate?>(null) }

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
                .padding(horizontal = 24.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(BackgroundCard)
                .clickable(enabled = false) {}
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Copy to Day",
                color = TextOnDark,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Mini calendar for date picking
            MiniCalendar(
                currentMonth = selectedMonth,
                selectedDate = selectedDate,
                onPreviousMonth = { selectedMonth = selectedMonth.minusMonths(1) },
                onNextMonth = { selectedMonth = selectedMonth.plusMonths(1) },
                onDayClick = { date -> selectedDate = date },
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Cancel / Copy buttons
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
                        .background(
                            if (selectedDate != null) PrimaryGreen
                            else PrimaryGreen.copy(alpha = 0.4f)
                        )
                        .clickable(enabled = selectedDate != null) {
                            selectedDate?.let { onDateSelected(it) }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Copy",
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}

@Composable
private fun MiniCalendar(
    currentMonth: YearMonth,
    selectedDate: LocalDate?,
    onPreviousMonth: () -> Unit,
    onNextMonth: () -> Unit,
    onDayClick: (LocalDate) -> Unit,
) {
    Column {
        // Month header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .clickable { onPreviousMonth() },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "<<",
                    color = TextOnDark,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                )
            }

            Text(
                text = "${currentMonth.month.getDisplayName(TextStyle.FULL, Locale.getDefault())} ${currentMonth.year}",
                color = TextOnDark,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
            )

            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .clickable { onNextMonth() },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = ">>",
                    color = TextOnDark,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Day-of-week headers
        val dayHeaders = listOf("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
        Row(modifier = Modifier.fillMaxWidth()) {
            dayHeaders.forEach { day ->
                Text(
                    text = day,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center,
                    color = TextOnDarkSecondary,
                    fontSize = 12.sp,
                )
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        // Calendar grid
        val firstOfMonth = currentMonth.atDay(1)
        val startOffset = firstOfMonth.dayOfWeek.value % 7
        val daysInMonth = currentMonth.lengthOfMonth()
        val totalCells = startOffset + daysInMonth
        val rows = (totalCells + 6) / 7

        for (row in 0 until rows) {
            Row(modifier = Modifier.fillMaxWidth()) {
                for (col in 0..6) {
                    val cellIndex = row * 7 + col
                    val dayOfMonth = cellIndex - startOffset + 1

                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (dayOfMonth in 1..daysInMonth) {
                            val date = currentMonth.atDay(dayOfMonth)
                            val isSelected = date == selectedDate

                            Box(
                                modifier = Modifier
                                    .size(30.dp)
                                    .clip(CircleShape)
                                    .then(
                                        if (isSelected) {
                                            Modifier.background(CalendarWorkoutDay, CircleShape)
                                        } else {
                                            Modifier
                                        }
                                    )
                                    .clickable { onDayClick(date) },
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = "$dayOfMonth",
                                    color = TextOnDark,
                                    fontSize = 13.sp,
                                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SaveAsTemplateDialog(
    defaultName: String,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
) {
    var templateName by remember { mutableStateOf(defaultName) }

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
                text = "Save as Template",
                color = TextOnDark,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "Template Name",
                color = TextOnDarkSecondary,
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(modifier = Modifier.height(8.dp))

            BasicTextField(
                value = templateName,
                onValueChange = { templateName = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(BackgroundCardElevated)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                textStyle = MaterialTheme.typography.bodyLarge.copy(
                    color = TextOnDark,
                ),
                singleLine = true,
                cursorBrush = SolidColor(PrimaryGreen),
                decorationBox = { innerTextField ->
                    Box {
                        if (templateName.isEmpty()) {
                            Text(
                                text = "Workout name",
                                color = TextOnDarkSecondary.copy(alpha = 0.5f),
                                style = MaterialTheme.typography.bodyLarge,
                            )
                        }
                        innerTextField()
                    }
                },
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Cancel / Save buttons
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
                        .background(
                            if (templateName.isNotBlank()) PrimaryGreen
                            else PrimaryGreen.copy(alpha = 0.4f)
                        )
                        .clickable(enabled = templateName.isNotBlank()) {
                            onSave(templateName.trim())
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Save",
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}

@Composable
private fun DeleteWorkoutDialog(
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
                text = "Remove Workout?",
                color = TextOnDark,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "This will permanently delete this workout from your history.",
                color = TextOnDarkSecondary,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(24.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Cancel
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

                // Remove (destructive)
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(DestructiveRed)
                        .clickable { onConfirm() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Remove",
                        color = TextOnDark,
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}

@Composable
private fun SuccessBanner(text: String) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(bottom = 32.dp),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(PrimaryGreen)
                .padding(horizontal = 24.dp, vertical = 12.dp),
        ) {
            Text(
                text = text,
                color = TextOnDark,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

private fun formatWeight(weight: Double): String = formatWeightValue(weight)
