package com.repsync.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.repsync.app.data.entity.ExerciseTrackingType
import com.repsync.app.ui.components.WeightProgressionChart
import com.repsync.app.ui.theme.BackgroundCard
import com.repsync.app.ui.theme.BackgroundCardElevated
import com.repsync.app.ui.theme.BackgroundPrimary
import com.repsync.app.ui.theme.DestructiveRed
import com.repsync.app.ui.theme.InputBackground
import com.repsync.app.ui.theme.PrimaryGreen
import com.repsync.app.ui.theme.TextOnDark
import com.repsync.app.ui.theme.TextOnDarkSecondary
import com.repsync.app.ui.viewmodel.ExerciseHistoryViewModel
import com.repsync.app.ui.viewmodel.ExerciseSession
import com.repsync.app.util.formatDurationValue
import com.repsync.app.util.formatTrackedSetSummary
import com.repsync.app.util.formatWeightValue
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@Composable
fun ExerciseHistoryScreen(
    exerciseName: String,
    onNavigateBack: () -> Unit,
    viewModel: ExerciseHistoryViewModel = viewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(exerciseName) {
        viewModel.loadExercise(exerciseName)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(BackgroundPrimary),
    ) {
        // Header
        ExerciseHistoryHeader(
            exerciseName = exerciseName,
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
        } else if (uiState.allSessions.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "No history for this exercise",
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
                // Stats row
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                    StatsRow(
                        trackingType = uiState.trackingType,
                        allTimePR = uiState.allTimePR,
                        totalVolume = uiState.totalVolume,
                        sessionCount = uiState.sessionCount,
                    )
                }

                // Chart
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                    WeightProgressionChart(
                        dataPoints = uiState.chartDataPoints,
                        label = when (uiState.trackingType) {
                            ExerciseTrackingType.WEIGHT_REPS -> "lbs"
                            ExerciseTrackingType.DURATION -> "sec"
                            ExerciseTrackingType.DURATION_DISTANCE -> "mi"
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(180.dp),
                    )
                }

                // History header + filter controls
                item {
                    Spacer(modifier = Modifier.height(20.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(
                            text = "History",
                            color = TextOnDark,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                        )

                        // Filter / Clear button
                        if (uiState.isDateRangeMode) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(DestructiveRed.copy(alpha = 0.8f))
                                    .clickable { viewModel.clearDateRange() }
                                    .padding(horizontal = 12.dp, vertical = 6.dp),
                            ) {
                                Text(
                                    text = "Clear Filter",
                                    color = TextOnDark,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                        } else {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(BackgroundCardElevated)
                                    .clickable { viewModel.showDatePicker() }
                                    .padding(horizontal = 12.dp, vertical = 6.dp),
                            ) {
                                Text(
                                    text = "Filter by Date",
                                    color = TextOnDarkSecondary,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                        }
                    }

                    // Show active range info
                    if (uiState.isDateRangeMode && uiState.rangeStartDate != null && uiState.rangeEndDate != null) {
                        Spacer(modifier = Modifier.height(6.dp))

                        val fmt = DateTimeFormatter.ofPattern("MMM d, yyyy")
                        Text(
                            text = "${uiState.rangeStartDate!!.format(fmt)} – ${uiState.rangeEndDate!!.format(fmt)}",
                            color = PrimaryGreen,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                        )
                    }

                    // Show "most recent" label in default mode
                    if (!uiState.isDateRangeMode && uiState.allSessions.size > uiState.sessions.size) {
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Showing last ${uiState.sessions.size} of ${uiState.sessionCount} sessions",
                            color = TextOnDarkSecondary,
                            fontSize = 11.sp,
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))
                }

                // Session cards (or empty state for filtered range)
                if (uiState.sessions.isEmpty() && uiState.isDateRangeMode) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 24.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "No sessions in this date range",
                                color = TextOnDarkSecondary,
                                fontSize = 14.sp,
                            )
                        }
                    }
                } else {
                    items(
                        items = uiState.sessions,
                        key = { "${it.date}_${it.workoutName}" },
                    ) { session ->
                        SessionCard(session = session)
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }

                item {
                    Spacer(modifier = Modifier.height(24.dp))
                }
            }
        }
    }

    // Date picker dialog overlay
    if (uiState.showDatePicker) {
        DateRangePickerDialog(
            onDismiss = { viewModel.dismissDatePicker() },
            onConfirm = { startDate -> viewModel.setDateRange(startDate) },
        )
    }
}

@Composable
private fun ExerciseHistoryHeader(
    exerciseName: String,
    onBackClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(BackgroundCard)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
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

        Spacer(modifier = Modifier.width(16.dp))

        Text(
            text = exerciseName,
            color = TextOnDark,
            style = MaterialTheme.typography.headlineLarge,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun StatsRow(
    trackingType: ExerciseTrackingType,
    allTimePR: Double?,
    totalVolume: Double,
    sessionCount: Int,
) {
    val prValue = when (trackingType) {
        ExerciseTrackingType.WEIGHT_REPS -> allTimePR?.let { "${formatWeight(it)} lbs" } ?: "-"
        ExerciseTrackingType.DURATION -> allTimePR?.toInt()?.let(::formatDurationValue) ?: "-"
        ExerciseTrackingType.DURATION_DISTANCE -> allTimePR?.let { "${formatDistance(it)} mi" } ?: "-"
    }
    val totalValue = when (trackingType) {
        ExerciseTrackingType.WEIGHT_REPS -> formatVolume(totalVolume)
        ExerciseTrackingType.DURATION -> formatDurationValue(totalVolume.toInt())
        ExerciseTrackingType.DURATION_DISTANCE -> "${formatDistance(totalVolume)} mi"
    }
    val prLabel = when (trackingType) {
        ExerciseTrackingType.WEIGHT_REPS -> "PR"
        ExerciseTrackingType.DURATION -> "Best Time"
        ExerciseTrackingType.DURATION_DISTANCE -> "Best Dist"
    }
    val totalLabel = when (trackingType) {
        ExerciseTrackingType.WEIGHT_REPS -> "Volume"
        ExerciseTrackingType.DURATION -> "Total Time"
        ExerciseTrackingType.DURATION_DISTANCE -> "Total Dist"
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        StatCard(
            label = prLabel,
            value = prValue,
            modifier = Modifier.weight(1f),
        )
        StatCard(
            label = totalLabel,
            value = totalValue,
            modifier = Modifier.weight(1f),
        )
        StatCard(
            label = "Sessions",
            value = sessionCount.toString(),
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun StatCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(BackgroundCard)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = value,
            color = PrimaryGreen,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            color = TextOnDarkSecondary,
            fontSize = 12.sp,
        )
    }
}

@Composable
private fun SessionCard(session: ExerciseSession) {
    val dateText = session.date.format(DateTimeFormatter.ofPattern("MMM d, yyyy"))

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(BackgroundCard)
            .padding(12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = dateText,
                color = TextOnDark,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = session.workoutName,
                color = TextOnDarkSecondary,
                fontSize = 12.sp,
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        session.sets.forEachIndexed { index, set ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Set ${index + 1}",
                    color = TextOnDarkSecondary,
                    fontSize = 13.sp,
                    modifier = Modifier.width(48.dp),
                )
                Text(
                    text = formatTrackedSetSummary(
                        trackingType = session.trackingType,
                        weight = set.weight,
                        reps = set.reps,
                        durationSeconds = set.durationSeconds,
                        distanceMiles = set.distanceMiles,
                        speedMph = set.speedMph,
                    ),
                    color = TextOnDark,
                    fontSize = 13.sp,
                )
            }
        }
    }
}

/**
 * Dialog for picking a start date. The end date is auto-calculated as start + 13 days
 * (2-week window), capped at today's date.
 */
@Composable
private fun DateRangePickerDialog(
    onDismiss: () -> Unit,
    onConfirm: (LocalDate) -> Unit,
) {
    val today = LocalDate.now()
    var monthText by remember { mutableStateOf(today.monthValue.toString()) }
    var dayText by remember { mutableStateOf("1") }
    var yearText by remember { mutableStateOf(today.year.toString()) }

    // Compute the preview end date for display
    val startDate = remember(monthText, dayText, yearText) {
        runCatching {
            LocalDate.of(
                yearText.toInt(),
                monthText.toInt(),
                dayText.toInt(),
            )
        }.getOrNull()
    }
    val endDate = startDate?.let {
        minOf(it.plusDays(13), today)
    }

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
                .clip(RoundedCornerShape(16.dp))
                .background(BackgroundCard)
                .clickable { /* Consume clicks */ }
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Filter by Date Range",
                color = TextOnDark,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "Pick a start date. Shows 2 weeks of history.",
                color = TextOnDarkSecondary,
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Date input: MM / DD / YYYY
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                // Month
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(text = "MM", color = TextOnDarkSecondary, fontSize = 10.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    DateInputField(
                        value = monthText,
                        onValueChange = { newVal ->
                            if (newVal.isEmpty() || (newVal.all { it.isDigit() } && newVal.length <= 2)) {
                                val num = newVal.toIntOrNull()
                                if (num == null || num in 0..12) monthText = newVal
                            }
                        },
                        width = 48,
                    )
                }

                Text(
                    text = "/",
                    color = TextOnDarkSecondary,
                    fontSize = 20.sp,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 0.dp),
                )

                // Day
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(text = "DD", color = TextOnDarkSecondary, fontSize = 10.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    DateInputField(
                        value = dayText,
                        onValueChange = { newVal ->
                            if (newVal.isEmpty() || (newVal.all { it.isDigit() } && newVal.length <= 2)) {
                                val num = newVal.toIntOrNull()
                                if (num == null || num in 0..31) dayText = newVal
                            }
                        },
                        width = 48,
                    )
                }

                Text(
                    text = "/",
                    color = TextOnDarkSecondary,
                    fontSize = 20.sp,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 0.dp),
                )

                // Year
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(text = "YYYY", color = TextOnDarkSecondary, fontSize = 10.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    DateInputField(
                        value = yearText,
                        onValueChange = { newVal ->
                            if (newVal.isEmpty() || (newVal.all { it.isDigit() } && newVal.length <= 4)) {
                                yearText = newVal
                            }
                        },
                        width = 72,
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Preview the computed range
            if (startDate != null && endDate != null) {
                val fmt = DateTimeFormatter.ofPattern("MMM d, yyyy")
                Text(
                    text = "${startDate.format(fmt)} – ${endDate.format(fmt)}",
                    color = PrimaryGreen,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                )
            } else {
                Text(
                    text = "Enter a valid date",
                    color = DestructiveRed,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(44.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(BackgroundCardElevated)
                        .clickable { onDismiss() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Cancel",
                        color = TextOnDarkSecondary,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }

                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(44.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (startDate != null) PrimaryGreen else BackgroundCardElevated)
                        .clickable {
                            if (startDate != null) {
                                onConfirm(startDate)
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Apply",
                        color = if (startDate != null) TextOnDark else TextOnDarkSecondary,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
    }
}

@Composable
private fun DateInputField(
    value: String,
    onValueChange: (String) -> Unit,
    width: Int,
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier
            .width(width.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(InputBackground)
            .padding(horizontal = 8.dp, vertical = 12.dp),
        textStyle = TextStyle(
            color = TextOnDark,
            fontSize = 18.sp,
            textAlign = TextAlign.Center,
        ),
        cursorBrush = SolidColor(PrimaryGreen),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        singleLine = true,
    )
}

private fun formatWeight(weight: Double): String = formatWeightValue(weight)

private fun formatDistance(distance: Double): String {
    return if (distance == distance.toLong().toDouble()) {
        distance.toLong().toString()
    } else {
        "%.2f".format(distance)
    }
}

private fun formatVolume(volume: Double): String {
    return when {
        volume >= 1_000_000 -> "%.1fM".format(volume / 1_000_000)
        volume >= 1_000 -> "%.1fK".format(volume / 1_000)
        else -> formatWeight(volume)
    }
}
