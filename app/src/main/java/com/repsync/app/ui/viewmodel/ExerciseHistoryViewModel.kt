package com.repsync.app.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.repsync.app.data.RepSyncDatabase
import com.repsync.app.data.entity.ExerciseTrackingType
import com.repsync.app.data.entity.ExerciseHistoryRow
import com.repsync.app.ui.components.ChartDataPoint
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate

data class ExerciseSessionSet(
    val weight: Double?,
    val reps: Int?,
    val durationSeconds: Int?,
    val distanceMiles: Double?,
    val speedMph: Double?,
)

data class ExerciseSession(
    val date: LocalDate,
    val workoutName: String,
    val trackingType: ExerciseTrackingType,
    val sets: List<ExerciseSessionSet>,
)

data class ExerciseHistoryUiState(
    val exerciseName: String = "",
    val isLoading: Boolean = true,
    val trackingType: ExerciseTrackingType = ExerciseTrackingType.WEIGHT_REPS,
    val allTimePR: Double? = null,
    val totalVolume: Double = 0.0,
    val sessionCount: Int = 0,
    val chartDataPoints: List<ChartDataPoint> = emptyList(),
    val sessions: List<ExerciseSession> = emptyList(),
    // Date range filtering
    val isDateRangeMode: Boolean = false,
    val rangeStartDate: LocalDate? = null,
    val rangeEndDate: LocalDate? = null,
    val showDatePicker: Boolean = false,
    // All sessions (unfiltered) for navigating ranges
    val allSessions: List<ExerciseSession> = emptyList(),
)

class ExerciseHistoryViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        const val DEFAULT_SESSION_LIMIT = 10
        const val DATE_RANGE_DAYS = 14
    }

    private val completedWorkoutDao = RepSyncDatabase.getDatabase(application).completedWorkoutDao()

    private val _uiState = MutableStateFlow(ExerciseHistoryUiState())
    val uiState: StateFlow<ExerciseHistoryUiState> = _uiState.asStateFlow()

    fun loadExercise(name: String) {
        _uiState.value = ExerciseHistoryUiState(exerciseName = name, isLoading = true)

        viewModelScope.launch {
            val rows = completedWorkoutDao.getExerciseHistory(name)
            val maxWeight = completedWorkoutDao.getExerciseMaxWeight(name)

            if (rows.isEmpty()) {
                _uiState.value = _uiState.value.copy(isLoading = false)
                return@launch
            }

            val trackingType = ExerciseTrackingType.fromStorage(rows.first().trackingType)
            // Group rows into sessions (by date + workoutName)
            val allSessions = groupIntoSessions(rows)

            val totalVolume = rows.sumOf { row ->
                when (trackingType) {
                    ExerciseTrackingType.WEIGHT_REPS -> (row.weight ?: 0.0) * (row.reps ?: 0)
                    ExerciseTrackingType.DURATION -> (row.durationSeconds ?: 0).toDouble()
                    ExerciseTrackingType.DURATION_DISTANCE -> row.distanceMiles ?: 0.0
                }
            }

            // Chart data uses the most useful primary metric for the tracking type.
            val chartDataPoints = rows
                .groupBy { it.date }
                .mapNotNull { (dateStr, dateRows) ->
                    val date = runCatching { LocalDate.parse(dateStr) }.getOrNull()
                        ?: return@mapNotNull null
                    val maxValue = when (trackingType) {
                        ExerciseTrackingType.WEIGHT_REPS -> dateRows.mapNotNull { it.weight }.maxOrNull()
                        ExerciseTrackingType.DURATION -> dateRows.mapNotNull { it.durationSeconds?.toDouble() }.maxOrNull()
                        ExerciseTrackingType.DURATION_DISTANCE -> dateRows.mapNotNull { it.distanceMiles }.maxOrNull()
                    } ?: return@mapNotNull null
                    ChartDataPoint(date = date, value = maxValue)
                }
                .sortedBy { it.date }

            // Default: show only the most recent 10 sessions
            val displayedSessions = allSessions.take(DEFAULT_SESSION_LIMIT)

            _uiState.value = _uiState.value.copy(
                isLoading = false,
                trackingType = trackingType,
                allTimePR = maxWeight,
                totalVolume = totalVolume,
                sessionCount = allSessions.size,
                chartDataPoints = chartDataPoints,
                sessions = displayedSessions,
                allSessions = allSessions,
                isDateRangeMode = false,
                rangeStartDate = null,
                rangeEndDate = null,
            )
        }
    }

    /**
     * Show the date picker for selecting a range start date.
     */
    fun showDatePicker() {
        _uiState.value = _uiState.value.copy(showDatePicker = true)
    }

    fun dismissDatePicker() {
        _uiState.value = _uiState.value.copy(showDatePicker = false)
    }

    /**
     * Set a date range filter. The start date is user-selected, the end date is
     * automatically start + 14 days (or today, whichever is earlier).
     * Shows up to 10 sessions within that range.
     */
    fun setDateRange(startDate: LocalDate) {
        val today = LocalDate.now()
        val endDate = minOf(startDate.plusDays(DATE_RANGE_DAYS.toLong() - 1), today)
        val allSessions = _uiState.value.allSessions

        val filtered = allSessions
            .filter { session ->
                !session.date.isBefore(startDate) && !session.date.isAfter(endDate)
            }
            .take(DEFAULT_SESSION_LIMIT)

        _uiState.value = _uiState.value.copy(
            isDateRangeMode = true,
            rangeStartDate = startDate,
            rangeEndDate = endDate,
            sessions = filtered,
            showDatePicker = false,
        )
    }

    /**
     * Clear the date range filter and go back to showing the last 10 sessions.
     */
    fun clearDateRange() {
        val allSessions = _uiState.value.allSessions
        _uiState.value = _uiState.value.copy(
            isDateRangeMode = false,
            rangeStartDate = null,
            rangeEndDate = null,
            sessions = allSessions.take(DEFAULT_SESSION_LIMIT),
        )
    }

    private fun groupIntoSessions(rows: List<ExerciseHistoryRow>): List<ExerciseSession> {
        val grouped = mutableListOf<ExerciseSession>()
        var currentKey: Pair<String, String>? = null
        var currentTrackingType = ExerciseTrackingType.WEIGHT_REPS
        var currentSets = mutableListOf<ExerciseSessionSet>()

        for (row in rows) {
            val key = row.date to row.workoutName
            if (key != currentKey) {
                if (currentKey != null && currentSets.isNotEmpty()) {
                    val date = runCatching { LocalDate.parse(currentKey!!.first) }
                        .getOrDefault(LocalDate.now())
                    grouped.add(ExerciseSession(date, currentKey!!.second, currentTrackingType, currentSets.toList()))
                }
                currentKey = key
                currentTrackingType = ExerciseTrackingType.fromStorage(row.trackingType)
                currentSets = mutableListOf()
            }
            currentSets.add(
                ExerciseSessionSet(
                    weight = row.weight,
                    reps = row.reps,
                    durationSeconds = row.durationSeconds,
                    distanceMiles = row.distanceMiles,
                    speedMph = row.speedMph,
                )
            )
        }
        if (currentKey != null && currentSets.isNotEmpty()) {
            val date = runCatching { LocalDate.parse(currentKey!!.first) }
                .getOrDefault(LocalDate.now())
            grouped.add(ExerciseSession(date, currentKey!!.second, currentTrackingType, currentSets.toList()))
        }

        return grouped
    }
}
