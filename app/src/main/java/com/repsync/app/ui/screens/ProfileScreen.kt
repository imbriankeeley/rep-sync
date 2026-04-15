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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.repsync.app.data.entity.BodyweightEntryEntity
import com.repsync.app.ui.components.ChartDataPoint
import com.repsync.app.ui.components.ProfileAvatar
import com.repsync.app.ui.components.StreakBadge
import com.repsync.app.ui.components.WeightProgressionChart
import com.repsync.app.ui.theme.BackgroundCard
import com.repsync.app.ui.theme.BackgroundCardElevated
import com.repsync.app.ui.theme.BackgroundPrimary
import com.repsync.app.ui.theme.DestructiveRed
import com.repsync.app.ui.theme.InputBackground
import com.repsync.app.ui.theme.PrimaryGreen
import com.repsync.app.ui.theme.TextOnDark
import com.repsync.app.ui.theme.TextOnDarkSecondary
import com.repsync.app.ui.viewmodel.BodyweightTrendSummary
import com.repsync.app.ui.viewmodel.ProfileViewModel
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@Composable
fun ProfileScreen(
    onNavigateToEditProfile: () -> Unit,
    onNavigateToBodyweightEntries: () -> Unit,
    viewModel: ProfileViewModel = viewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    val displayName = uiState.displayName ?: "Guest"
    val workoutCount = uiState.completedWorkoutCount

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp)
                .padding(top = 16.dp),
        ) {
            // Main profile card
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(BackgroundCard)
                    .padding(16.dp),
            ) {
                // "Profile" header centered
                Text(
                    text = "Profile",
                    modifier = Modifier.fillMaxWidth(),
                    color = TextOnDark,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                )

                Spacer(modifier = Modifier.height(20.dp))

                // Profile row: avatar, name/count, chevron
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .clickable { onNavigateToEditProfile() }
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // Avatar (shows saved photo or placeholder icon)
                    ProfileAvatar(
                        avatarPath = uiState.avatarPath,
                        size = 56.dp,
                    )

                    Spacer(modifier = Modifier.width(16.dp))

                    // Name and workout count
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = displayName,
                            color = TextOnDark,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                        )
                        Text(
                            text = "$workoutCount Workouts",
                            color = TextOnDarkSecondary,
                            fontSize = 16.sp,
                        )
                    }

                    // Chevron
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = "Edit profile",
                        tint = TextOnDarkSecondary,
                        modifier = Modifier.size(28.dp),
                    )
                }
            }

            StreakBadge(streak = uiState.currentStreak)

            Spacer(modifier = Modifier.height(12.dp))

            // Bodyweight section
            BodyweightSection(
                latestWeight = uiState.latestBodyweight,
                trendSummary = uiState.bodyweightTrendSummary,
                trendHelperText = uiState.bodyweightTrendHelperText,
                chartData = uiState.bodyweightChartData,
                recentEntries = uiState.bodyweightEntries.reversed().take(3),
                onAddClick = { viewModel.showAddBodyweightDialog() },
                onEditEntry = { viewModel.showEditBodyweightDialog(it) },
                onDeleteEntry = { viewModel.showDeleteBodyweightDialog(it) },
                onViewAllEntries = onNavigateToBodyweightEntries,
                modifier = Modifier.weight(1f),
            )

            // Space for bottom nav
            Spacer(modifier = Modifier.height(4.dp))
        }

        // Add bodyweight dialog overlay
        if (uiState.showAddBodyweightDialog) {
            AddBodyweightDialog(
                onDismiss = { viewModel.dismissAddBodyweightDialog() },
                onSave = { weight -> viewModel.addBodyweightEntry(weight) },
            )
        }

        // Edit bodyweight dialog overlay
        if (uiState.showEditBodyweightDialog && uiState.editingBodyweightEntry != null) {
            EditBodyweightDialog(
                entry = uiState.editingBodyweightEntry!!,
                onDismiss = { viewModel.dismissEditBodyweightDialog() },
                onSave = { id, newWeight -> viewModel.updateBodyweightEntry(id, newWeight) },
            )
        }

        // Delete bodyweight confirmation dialog
        if (uiState.showDeleteBodyweightDialog && uiState.deletingBodyweightEntry != null) {
            DeleteBodyweightDialog(
                onDismiss = { viewModel.dismissDeleteBodyweightDialog() },
                onConfirm = { viewModel.confirmDeleteBodyweightEntry() },
            )
        }
    }
}

@Composable
private fun BodyweightSection(
    latestWeight: Double?,
    trendSummary: BodyweightTrendSummary?,
    trendHelperText: String?,
    chartData: List<ChartDataPoint>,
    recentEntries: List<BodyweightEntryEntity>,
    onAddClick: () -> Unit,
    onEditEntry: (BodyweightEntryEntity) -> Unit,
    onDeleteEntry: (BodyweightEntryEntity) -> Unit,
    onViewAllEntries: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val displayFmt = remember { DateTimeFormatter.ofPattern("MMM d, yyyy") }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(BackgroundCard)
            .padding(16.dp),
    ) {
        // Header row: title + latest weight + add button
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = "Bodyweight",
                color = TextOnDark,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
            )

            Row(verticalAlignment = Alignment.CenterVertically) {
                if (latestWeight != null) {
                    Text(
                        text = "${formatBodyweight(latestWeight)} lbs",
                        color = PrimaryGreen,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                }

                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(PrimaryGreen)
                        .clickable { onAddClick() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "+",
                        color = TextOnDark,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }

        if (trendSummary != null || trendHelperText != null) {
            Spacer(modifier = Modifier.height(6.dp))

            Text(
                text = trendSummary?.text ?: trendHelperText.orEmpty(),
                color = if (trendSummary != null && !trendSummary.isStable) {
                    PrimaryGreen
                } else {
                    TextOnDarkSecondary
                },
                fontSize = 13.sp,
                fontWeight = if (trendSummary != null) FontWeight.Medium else FontWeight.Normal,
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Chart or placeholder
        if (chartData.size >= 2) {
            WeightProgressionChart(
                dataPoints = chartData,
                label = "lbs",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp),
            )
        } else if (chartData.size == 1) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Log one more entry to see your chart",
                    color = TextOnDarkSecondary,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                )
            }
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Tap + to log your first bodyweight entry",
                    color = TextOnDarkSecondary,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                )
            }
        }

        // Recent Entries — measure available space and show as many as fit
        if (recentEntries.isNotEmpty()) {
            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "Recent Entries",
                color = TextOnDarkSecondary,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Each entry row is ~48dp (10dp vertical padding * 2 + 28dp icon) + 4dp gap
            // Use weight(1f) Column to fill remaining space, no scroll
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                recentEntries.forEach { entry ->
                    val dateText = runCatching {
                        LocalDate.parse(entry.date).format(displayFmt)
                    }.getOrDefault(entry.date)

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(BackgroundCardElevated)
                            .padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = dateText,
                            color = TextOnDarkSecondary,
                            fontSize = 14.sp,
                            modifier = Modifier.weight(1f),
                        )

                        Text(
                            text = "${formatBodyweight(entry.weight)} lbs",
                            color = TextOnDark,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium,
                        )

                        Spacer(modifier = Modifier.width(12.dp))

                        // Edit button
                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .clip(CircleShape)
                                .background(BackgroundCard)
                                .clickable { onEditEntry(entry) },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "\u270E",
                                color = TextOnDarkSecondary,
                                fontSize = 14.sp,
                            )
                        }

                        Spacer(modifier = Modifier.width(8.dp))

                        // Delete button
                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .clip(CircleShape)
                                .background(DestructiveRed.copy(alpha = 0.8f))
                                .clickable { onDeleteEntry(entry) },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "X",
                                color = TextOnDark,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
            }
        } else {
            Spacer(modifier = Modifier.weight(1f))
        }

        // View All Entries button
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(PrimaryGreen.copy(alpha = 0.15f))
                .clickable { onViewAllEntries() }
                .padding(vertical = 10.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "View All Entries",
                color = PrimaryGreen,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun AddBodyweightDialog(
    onDismiss: () -> Unit,
    onSave: (Double) -> Unit,
) {
    var weightText by remember { mutableStateOf("") }

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
                .clickable { /* Consume clicks so they don't dismiss */ }
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Log Bodyweight",
                color = TextOnDark,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Weight input
            BasicTextField(
                value = weightText,
                onValueChange = { newValue ->
                    // Allow digits and one decimal point
                    if (newValue.isEmpty() || newValue.matches(Regex("^\\d*\\.?\\d*$"))) {
                        weightText = newValue
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(InputBackground)
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                textStyle = androidx.compose.ui.text.TextStyle(
                    color = TextOnDark,
                    fontSize = 18.sp,
                    textAlign = TextAlign.Center,
                ),
                cursorBrush = SolidColor(PrimaryGreen),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                singleLine = true,
                decorationBox = { innerTextField ->
                    Box(contentAlignment = Alignment.Center) {
                        if (weightText.isEmpty()) {
                            Text(
                                text = "Weight (lbs)",
                                color = TextOnDarkSecondary,
                                fontSize = 18.sp,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                        innerTextField()
                    }
                },
            )

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
                        .background(PrimaryGreen)
                        .clickable {
                            val weight = weightText.toDoubleOrNull()
                            if (weight != null && weight > 0) {
                                onSave(weight)
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Save",
                        color = TextOnDark,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
    }
}

@Composable
private fun EditBodyweightDialog(
    entry: BodyweightEntryEntity,
    onDismiss: () -> Unit,
    onSave: (Long, Double) -> Unit,
) {
    var weightText by remember { mutableStateOf(formatBodyweight(entry.weight)) }
    val displayFmt = remember { DateTimeFormatter.ofPattern("MMM d, yyyy") }

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
                text = "Edit Weight",
                color = TextOnDark,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(8.dp))

            val dateText = runCatching {
                LocalDate.parse(entry.date).format(displayFmt)
            }.getOrDefault(entry.date)
            Text(
                text = dateText,
                color = TextOnDarkSecondary,
                fontSize = 14.sp,
            )

            Spacer(modifier = Modifier.height(20.dp))

            BasicTextField(
                value = weightText,
                onValueChange = { newValue ->
                    if (newValue.isEmpty() || newValue.matches(Regex("^\\d*\\.?\\d*$"))) {
                        weightText = newValue
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(InputBackground)
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                textStyle = androidx.compose.ui.text.TextStyle(
                    color = TextOnDark,
                    fontSize = 18.sp,
                    textAlign = TextAlign.Center,
                ),
                cursorBrush = SolidColor(PrimaryGreen),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                singleLine = true,
                decorationBox = { innerTextField ->
                    Box(contentAlignment = Alignment.Center) {
                        if (weightText.isEmpty()) {
                            Text(
                                text = "Weight (lbs)",
                                color = TextOnDarkSecondary,
                                fontSize = 18.sp,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                        innerTextField()
                    }
                },
            )

            Spacer(modifier = Modifier.height(20.dp))

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
                        .background(PrimaryGreen)
                        .clickable {
                            val weight = weightText.toDoubleOrNull()
                            if (weight != null && weight > 0) {
                                onSave(entry.id, weight)
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Save",
                        color = TextOnDark,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
    }
}

@Composable
private fun DeleteBodyweightDialog(
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
                .clip(RoundedCornerShape(16.dp))
                .background(BackgroundCard)
                .clickable { /* Consume clicks */ }
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Delete Entry?",
                color = TextOnDark,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "This will permanently remove this bodyweight entry.",
                color = TextOnDarkSecondary,
                fontSize = 14.sp,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(20.dp))

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
                        .background(DestructiveRed)
                        .clickable { onConfirm() },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Delete",
                        color = TextOnDark,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
    }
}

private fun formatBodyweight(weight: Double): String {
    return if (weight == weight.toLong().toDouble()) {
        weight.toLong().toString()
    } else {
        "%.1f".format(weight)
    }
}
