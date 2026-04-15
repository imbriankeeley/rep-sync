package com.repsync.app.ui.viewmodel

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.repsync.app.data.ReminderPreferences
import com.repsync.app.data.RepSyncDatabase
import com.repsync.app.data.WorkoutDaysPreferences
import com.repsync.app.data.entity.BodyweightEntryEntity
import com.repsync.app.data.entity.UserProfileEntity
import com.repsync.app.notification.ReminderScheduler
import com.repsync.app.ui.components.ChartDataPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.time.format.DateTimeFormatter
import java.util.Locale

data class BodyweightTrendSummary(
    val text: String,
    val isStable: Boolean = false,
)

data class ProfileUiState(
    val displayName: String? = null,
    val avatarPath: String? = null,
    val completedWorkoutCount: Int = 0,
    val currentStreak: Int = 0,
    val bodyweightEntries: List<BodyweightEntryEntity> = emptyList(),
    val bodyweightChartData: List<ChartDataPoint> = emptyList(),
    val latestBodyweight: Double? = null,
    val bodyweightTrendSummary: BodyweightTrendSummary? = null,
    val bodyweightTrendHelperText: String? = null,
    val showAddBodyweightDialog: Boolean = false,
    val showEditBodyweightDialog: Boolean = false,
    val editingBodyweightEntry: BodyweightEntryEntity? = null,
    val showDeleteBodyweightDialog: Boolean = false,
    val deletingBodyweightEntry: BodyweightEntryEntity? = null,
    // Workout schedule days (source of truth for streaks AND reminders)
    val workoutDays: Set<DayOfWeek> = emptySet(),
    // Reminder settings (uses workoutDays for scheduling)
    val reminderEnabled: Boolean = false,
    val reminderHour: Int = ReminderPreferences.DEFAULT_HOUR,
    val reminderMinute: Int = ReminderPreferences.DEFAULT_MINUTE,
    val reminderMessage: String = ReminderPreferences.DEFAULT_MESSAGE,
    val showTimePicker: Boolean = false,
)

class ProfileViewModel(application: Application) : AndroidViewModel(application) {

    private val db = RepSyncDatabase.getDatabase(application)
    private val userProfileDao = db.userProfileDao()
    private val completedWorkoutDao = db.completedWorkoutDao()
    private val bodyweightDao = db.bodyweightDao()
    private val reminderPrefs = ReminderPreferences.getInstance(application)
    private val reminderScheduler = ReminderScheduler(application)
    private val workoutDaysPrefs = WorkoutDaysPreferences.getInstance(application)

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    private var cachedWorkoutDates: Set<LocalDate> = emptySet()
    private var cachedScheduledDays: Set<DayOfWeek> = emptySet()

    init {
        observeProfile()
        observeWorkoutCount()
        observeBodyweight()
        observeReminderPrefs()
        observeWorkoutDays()
        observeStreakData()
    }

    private fun observeProfile() {
        viewModelScope.launch {
            userProfileDao.getProfile().collect { profile ->
                _uiState.value = _uiState.value.copy(
                    displayName = profile?.displayName,
                    avatarPath = profile?.avatarPath,
                )
            }
        }
    }

    private fun observeWorkoutCount() {
        viewModelScope.launch {
            completedWorkoutDao.getCompletedWorkoutCount().collect { count ->
                _uiState.value = _uiState.value.copy(
                    completedWorkoutCount = count
                )
            }
        }
    }

    fun updateDisplayName(name: String) {
        viewModelScope.launch {
            val trimmed = name.trim()
            val current = userProfileDao.getProfileOnce()
            val profile = UserProfileEntity(
                id = 1,
                displayName = trimmed.ifEmpty { null },
                avatarPath = current?.avatarPath,
            )
            userProfileDao.upsertProfile(profile)
        }
    }

    fun updateAvatar(uri: Uri) {
        viewModelScope.launch {
            val context = getApplication<Application>()
            val avatarFile = File(context.filesDir, "profile_avatar.jpg")
            try {
                withContext(Dispatchers.IO) {
                    // Copy the raw file first
                    context.contentResolver.openInputStream(uri)?.use { input ->
                        avatarFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }

                    // Read EXIF orientation and correct if needed
                    val exif = ExifInterface(avatarFile.absolutePath)
                    val orientation = exif.getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL,
                    )

                    val rotation = when (orientation) {
                        ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                        ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                        ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                        else -> 0f
                    }

                    if (rotation != 0f) {
                        val original = BitmapFactory.decodeFile(avatarFile.absolutePath)
                        if (original != null) {
                            val matrix = Matrix().apply { postRotate(rotation) }
                            val rotated = Bitmap.createBitmap(
                                original, 0, 0,
                                original.width, original.height,
                                matrix, true,
                            )
                            avatarFile.outputStream().use { out ->
                                rotated.compress(Bitmap.CompressFormat.JPEG, 90, out)
                            }
                            if (rotated !== original) rotated.recycle()
                            original.recycle()
                        }
                    }
                }

                val current = userProfileDao.getProfileOnce()
                val profile = UserProfileEntity(
                    id = 1,
                    displayName = current?.displayName,
                    avatarPath = avatarFile.absolutePath,
                )
                userProfileDao.upsertProfile(profile)
            } catch (_: Exception) {
                // Silently fail if image processing fails
            }
        }
    }

    private fun observeBodyweight() {
        viewModelScope.launch {
            bodyweightDao.getAllEntriesChronological().collect { entries ->
                val chartData = entries.map { entry ->
                    ChartDataPoint(
                        date = LocalDate.parse(entry.date, DateTimeFormatter.ISO_LOCAL_DATE),
                        value = entry.weight,
                    )
                }
                val trendSummary = calculateBodyweightTrend(entries)
                _uiState.value = _uiState.value.copy(
                    bodyweightEntries = entries,
                    bodyweightChartData = chartData,
                    latestBodyweight = entries.lastOrNull()?.weight,
                    bodyweightTrendSummary = trendSummary,
                    bodyweightTrendHelperText = if (entries.isNotEmpty() && trendSummary == null) {
                        "Log entries on different days to see your trend"
                    } else {
                        null
                    },
                )
            }
        }
    }

    private fun calculateBodyweightTrend(entries: List<BodyweightEntryEntity>): BodyweightTrendSummary? {
        val validEntries = entries.mapNotNull { entry ->
            val date = runCatching {
                LocalDate.parse(entry.date, DateTimeFormatter.ISO_LOCAL_DATE)
            }.getOrNull()
            val weight = entry.weight.takeIf { it > 0 }
            if (date != null && weight != null) {
                entry to date
            } else {
                null
            }
        }

        if (validEntries.size < 2) return null

        val oldest = validEntries.first()
        val newest = validEntries.last()
        val elapsedDays = ChronoUnit.DAYS.between(oldest.second, newest.second)
        if (elapsedDays < 1) return null

        val weightDelta = newest.first.weight - oldest.first.weight
        val weeklyRate = (weightDelta / elapsedDays.toDouble()) * 7.0
        val absoluteRate = kotlin.math.abs(weeklyRate)
        val formattedRate = String.format(Locale.US, "%.1f", absoluteRate)

        return when {
            absoluteRate < BODYWEIGHT_STABLE_THRESHOLD_LBS_PER_WEEK -> {
                BodyweightTrendSummary(
                    text = "Holding steady",
                    isStable = true,
                )
            }
            weeklyRate > 0 -> BodyweightTrendSummary(text = "Gaining $formattedRate lbs/week")
            else -> BodyweightTrendSummary(text = "Losing $formattedRate lbs/week")
        }
    }

    fun showAddBodyweightDialog() {
        _uiState.value = _uiState.value.copy(showAddBodyweightDialog = true)
    }

    fun dismissAddBodyweightDialog() {
        _uiState.value = _uiState.value.copy(showAddBodyweightDialog = false)
    }

    fun addBodyweightEntry(weight: Double) {
        viewModelScope.launch {
            val today = LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE)
            bodyweightDao.insert(
                BodyweightEntryEntity(
                    date = today,
                    weight = weight,
                )
            )
            _uiState.value = _uiState.value.copy(showAddBodyweightDialog = false)
        }
    }

    fun showDeleteBodyweightDialog(entry: BodyweightEntryEntity) {
        _uiState.value = _uiState.value.copy(
            deletingBodyweightEntry = entry,
            showDeleteBodyweightDialog = true,
        )
    }

    fun dismissDeleteBodyweightDialog() {
        _uiState.value = _uiState.value.copy(
            deletingBodyweightEntry = null,
            showDeleteBodyweightDialog = false,
        )
    }

    fun confirmDeleteBodyweightEntry() {
        val entry = _uiState.value.deletingBodyweightEntry ?: return
        viewModelScope.launch {
            bodyweightDao.delete(entry)
            dismissDeleteBodyweightDialog()
        }
    }

    fun showEditBodyweightDialog(entry: BodyweightEntryEntity) {
        _uiState.value = _uiState.value.copy(
            editingBodyweightEntry = entry,
            showEditBodyweightDialog = true,
        )
    }

    fun dismissEditBodyweightDialog() {
        _uiState.value = _uiState.value.copy(
            editingBodyweightEntry = null,
            showEditBodyweightDialog = false,
        )
    }

    fun updateBodyweightEntry(id: Long, newWeight: Double) {
        viewModelScope.launch {
            bodyweightDao.updateWeight(id, newWeight)
            dismissEditBodyweightDialog()
        }
    }

    private fun observeStreakData() {
        viewModelScope.launch {
            completedWorkoutDao.getDatesWithCompletedWorkouts().collect { dateStrings ->
                val dates = dateStrings.mapNotNull { str ->
                    runCatching { LocalDate.parse(str) }.getOrNull()
                }.toSet()
                cachedWorkoutDates = dates
                _uiState.value = _uiState.value.copy(
                    currentStreak = calculateStreak(dates, cachedScheduledDays),
                )
            }
        }
        viewModelScope.launch {
            workoutDaysPrefs.days.collect { days ->
                cachedScheduledDays = days
                _uiState.value = _uiState.value.copy(
                    currentStreak = calculateStreak(cachedWorkoutDates, days),
                )
            }
        }
    }

    private fun calculateStreak(dates: Set<LocalDate>, scheduledDays: Set<DayOfWeek>): Int {
        if (dates.isEmpty()) return 0
        val today = LocalDate.now()

        if (scheduledDays.isEmpty()) {
            var checkDate = if (dates.contains(today)) today else today.minusDays(1)
            if (!dates.contains(checkDate)) return 0
            var streak = 0
            while (dates.contains(checkDate)) {
                streak++
                checkDate = checkDate.minusDays(1)
            }
            return streak
        }

        var checkDate = today
        if (!dates.contains(checkDate)) {
            checkDate = checkDate.minusDays(1)
        }

        var streak = 0
        while (true) {
            val isScheduled = scheduledDays.contains(checkDate.dayOfWeek)
            val workedOut = dates.contains(checkDate)

            if (isScheduled) {
                if (workedOut) {
                    streak++
                    checkDate = checkDate.minusDays(1)
                } else {
                    break
                }
            } else {
                if (workedOut) {
                    streak++
                }
                checkDate = checkDate.minusDays(1)
            }
        }
        return streak
    }

    private fun observeWorkoutDays() {
        viewModelScope.launch {
            workoutDaysPrefs.days.collect { days ->
                _uiState.value = _uiState.value.copy(workoutDays = days)
            }
        }
    }

    private companion object {
        private const val BODYWEIGHT_STABLE_THRESHOLD_LBS_PER_WEEK = 0.1
    }

    fun toggleWorkoutDay(day: DayOfWeek) {
        viewModelScope.launch {
            val current = _uiState.value.workoutDays.toMutableSet()
            if (current.contains(day)) current.remove(day) else current.add(day)
            workoutDaysPrefs.setDays(current)
            // If reminders are enabled, reschedule with the updated workout days
            if (_uiState.value.reminderEnabled) {
                if (current.isNotEmpty()) {
                    reminderScheduler.scheduleReminders(
                        current, _uiState.value.reminderHour, _uiState.value.reminderMinute,
                    )
                } else {
                    reminderScheduler.cancelAllReminders()
                }
            }
        }
    }

    private fun observeReminderPrefs() {
        viewModelScope.launch {
            combine(
                reminderPrefs.enabled,
                reminderPrefs.hour,
                reminderPrefs.minute,
                reminderPrefs.message,
            ) { enabled, hour, minute, message ->
                ReminderState(
                    enabled = enabled as Boolean,
                    hour = hour as Int,
                    minute = minute as Int,
                    message = message as String,
                )
            }.collect { state ->
                _uiState.value = _uiState.value.copy(
                    reminderEnabled = state.enabled,
                    reminderHour = state.hour,
                    reminderMinute = state.minute,
                    reminderMessage = state.message,
                )
            }
        }
    }

    fun toggleReminderEnabled() {
        viewModelScope.launch {
            val newEnabled = !_uiState.value.reminderEnabled
            reminderPrefs.setEnabled(newEnabled)
            if (newEnabled) {
                val state = _uiState.value
                if (state.workoutDays.isNotEmpty()) {
                    reminderScheduler.scheduleReminders(
                        state.workoutDays, state.reminderHour, state.reminderMinute,
                    )
                }
            } else {
                reminderScheduler.cancelAllReminders()
            }
        }
    }


    fun setReminderTime(hour: Int, minute: Int) {
        viewModelScope.launch {
            reminderPrefs.setHour(hour)
            reminderPrefs.setMinute(minute)
            _uiState.value = _uiState.value.copy(showTimePicker = false)
            if (_uiState.value.reminderEnabled && _uiState.value.workoutDays.isNotEmpty()) {
                reminderScheduler.scheduleReminders(
                    _uiState.value.workoutDays, hour, minute,
                )
            }
        }
    }

    fun showTimePicker() {
        _uiState.value = _uiState.value.copy(showTimePicker = true)
    }

    fun dismissTimePicker() {
        _uiState.value = _uiState.value.copy(showTimePicker = false)
    }

    fun setReminderMessage(message: String) {
        viewModelScope.launch {
            reminderPrefs.setMessage(message)
        }
    }
}

private data class ReminderState(
    val enabled: Boolean,
    val hour: Int,
    val minute: Int,
    val message: String,
)
