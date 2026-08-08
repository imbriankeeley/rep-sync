import PhotosUI
import SwiftUI
import UIKit

struct ProfileScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var newBodyweightPhotoSelection: PhotosPickerItem?
    @State private var editingBodyweightPhotoSelection: PhotosPickerItem?
    @State private var showsNewBodyweightCamera = false
    @State private var showsEditingBodyweightCamera = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                RepSyncCard {
                    VStack(spacing: 0) {
                        Text("Profile")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(maxWidth: .infinity)

                        HStack(spacing: 16) {
                            RepSyncProfileAvatar(size: 56, imagePath: appModel.profileState.avatarPath)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appModel.profileState.displayName)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                Text("\(appModel.profileState.workoutCount) Workouts")
                                    .font(.system(size: 16))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        .contentShape(Rectangle())
                        .onTapGesture { appModel.showEditProfile() }
                    }
                }

                RepSyncCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Bodyweight")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                            Spacer()
                            Text(appModel.profileState.latestWeight)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.primaryGreen)
                            Button {
                                appModel.showAddBodyweightSheet()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                    .frame(width: 32, height: 32)
                                    .background(RepSyncTheme.primaryGreen)
                                    .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                        if let trendText = appModel.profileState.bodyweightTrendText ?? appModel.profileState.bodyweightTrendHelperText {
                            Text(trendText)
                                .font(.system(size: 13, weight: appModel.profileState.bodyweightTrendText == nil ? .regular : .medium))
                                .foregroundStyle(
                                    appModel.profileState.bodyweightTrendText != nil && !appModel.profileState.bodyweightTrendIsStable
                                    ? RepSyncTheme.primaryGreen
                                    : RepSyncTheme.textSecondary
                                )
                        }

                        Picker(
                            "Chart Range",
                            selection: Binding(
                                get: { appModel.selectedBodyweightChartRange },
                                set: { appModel.selectBodyweightChartRange($0) }
                            )
                        ) {
                            ForEach(BodyweightChartRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)

                        if appModel.profileState.chartPoints.count >= 2 {
                            RepSyncLineChart(
                                points: appModel.profileState.chartPoints,
                                trendPoints: appModel.profileState.trendChartPoints,
                                label: "lbs"
                            )
                                .frame(height: 140)
                        } else if appModel.profileState.chartPoints.count == 1 {
                            Text("Log one more entry to see your chart")
                                .font(.system(size: 14))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 60)
                        } else {
                            Text("Tap + to log your first bodyweight entry")
                                .font(.system(size: 14))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 60)
                        }

                        if let trendingWeight = appModel.profileState.bodyweightTrendingWeightText {
                            bodyweightStatRow(title: "Trending Weight", value: trendingWeight)
                        }

                        if let tenDayLow = appModel.profileState.bodyweightTenDayLowText {
                            bodyweightStatRow(title: "10 Day Low", value: tenDayLow)
                        }

                        Button {
                            appModel.showBodyweightEntries()
                        } label: {
                            Text("View All Entries")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.primaryGreen)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RepSyncTheme.primaryGreen.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer(minLength: 4)
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .sheet(item: $appModel.editingBodyweight) { entry in
            editWeightSheet(entry: entry)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $appModel.showsAddBodyweightSheet) {
            addWeightSheet
                .presentationDetents([.medium])
        }
        .alert("Delete Entry?", isPresented: Binding(
            get: { appModel.deletingBodyweight != nil },
            set: { if !$0 { appModel.dismissDeleteBodyweightConfirmation() } }
        )) {
            Button("Cancel", role: .cancel) {
                appModel.dismissDeleteBodyweightConfirmation()
            }
            Button("Delete", role: .destructive) {
                if let entry = appModel.deletingBodyweight {
                    appModel.deleteBodyweight(entry)
                }
            }
        } message: {
            Text("This bodyweight entry will be removed permanently.")
        }
        .sheet(isPresented: Binding(
            get: { appModel.previewingBodyweightPhotoPath != nil },
            set: { if !$0 { appModel.dismissBodyweightPhotoPreview() } }
        )) {
            BodyweightPhotoPreview(photoPath: appModel.previewingBodyweightPhotoPath)
        }
    }

    private func bodyweightStatRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RepSyncTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 42)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func editWeightSheet(entry: BodyweightEntryModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Weight")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
            DatePicker("Date", selection: $appModel.editingBodyweightDate, displayedComponents: .date)
                .tint(RepSyncTheme.primaryGreen)
                .foregroundStyle(RepSyncTheme.textPrimary)
            TextField("Weight", text: $appModel.editingBodyweightValue)
                .keyboardType(.decimalPad)
                .foregroundStyle(RepSyncTheme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(RepSyncTheme.input)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            BodyweightPhotoPickerRow(
                title: "Progress Photo",
                photoPath: appModel.editingBodyweightPhotoPath,
                selection: $editingBodyweightPhotoSelection,
                onCamera: { showsEditingBodyweightCamera = true },
                onPreview: { appModel.previewBodyweightPhoto(appModel.editingBodyweightPhotoPath) },
                onRemove: { appModel.removeEditingBodyweightPhoto() }
            )
            Button("Save") { appModel.saveEditedBodyweight() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RepSyncTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer()
        }
        .padding(24)
        .background(RepSyncTheme.background)
        .onChange(of: editingBodyweightPhotoSelection) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    appModel.saveEditingBodyweightPhotoData(data)
                }
                editingBodyweightPhotoSelection = nil
            }
        }
        .sheet(isPresented: $showsEditingBodyweightCamera) {
            BodyweightCameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.9) {
                    appModel.saveEditingBodyweightPhotoData(data)
                }
            }
        }
    }

    private var addWeightSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Log Bodyweight")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                TextField("Weight (lbs)", text: $appModel.newBodyweightValue)
                    .keyboardType(.decimalPad)
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(RepSyncTheme.input)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: appModel.newBodyweightValue) { _, newValue in
                        let sanitized = sanitizeDecimalInput(newValue)
                        if sanitized != newValue {
                            appModel.newBodyweightValue = sanitized
                        }
                    }
            BodyweightPhotoPickerRow(
                title: "Progress Photo",
                photoPath: appModel.newBodyweightPhotoPath,
                selection: $newBodyweightPhotoSelection,
                onCamera: { showsNewBodyweightCamera = true },
                onPreview: { appModel.previewBodyweightPhoto(appModel.newBodyweightPhotoPath) },
                onRemove: { appModel.removeNewBodyweightPhoto() }
            )
            HStack(spacing: 12) {
                Button("Cancel") {
                    appModel.dismissAddBodyweightSheet()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Save") {
                    appModel.addBodyweight()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RepSyncTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Spacer()
        }
        .padding(24)
        .background(RepSyncTheme.background)
        .onChange(of: newBodyweightPhotoSelection) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    appModel.saveNewBodyweightPhotoData(data)
                }
                newBodyweightPhotoSelection = nil
            }
        }
        .sheet(isPresented: $showsNewBodyweightCamera) {
            BodyweightCameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.9) {
                    appModel.saveNewBodyweightPhotoData(data)
                }
            }
        }
    }
}

struct EditProfileScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var avatarSelection: PhotosPickerItem?
    @State private var isEditingBirthdate = false

    var body: some View {
        let hasDraftAvatar = appModel.profileDraftAvatarPath != nil
        let draftAvatarPath = appModel.profileDraftAvatarPath

        ScrollView {
            VStack(spacing: 0) {
                RepSyncCard {
                    VStack(spacing: 0) {
                        HStack {
                            RepSyncHeaderButton(title: "<") { appModel.pop() }
                            Spacer()
                            Text("Edit Profile")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                            Spacer()
                            Button("Save") { appModel.saveProfile() }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                        }

                        VStack(spacing: 4) {
                            PhotosPicker(selection: $avatarSelection, matching: .images) {
                                RepSyncProfileAvatar(size: 80, imagePath: draftAvatarPath)
                            }
                            .buttonStyle(.plain)
                            Text(hasDraftAvatar ? "Tap to change photo" : "Tap to choose photo")
                                .font(.system(size: 12))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                            TextField("Enter display name", text: $appModel.profileDraftName)
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .padding(.horizontal, 16)
                                .frame(height: 48)
                                .background(RepSyncTheme.input)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.top, 20)

                        Text("\(appModel.profileState.workoutCount) Workouts Completed")
                            .font(.system(size: 14))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)

                        sectionTitle("Biometrics")
                        Text("Used later for leaderboard classes and strength rankings.")
                            .font(.system(size: 12))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                biometricMenu(
                                    title: "Feet",
                                    value: "\(appModel.profileDraftHeightFeet)'"
                                ) {
                                    ForEach(3...8, id: \.self) { feet in
                                        Button("\(feet)'") {
                                            appModel.profileDraftHeightFeet = feet
                                        }
                                    }
                                }

                                biometricMenu(
                                    title: "Inches",
                                    value: "\(formatWeight(appModel.profileDraftHeightInches))\""
                                ) {
                                    ForEach(halfInchOptions, id: \.self) { inches in
                                        Button("\(formatWeight(inches))\"") {
                                            appModel.profileDraftHeightInches = inches
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Birthdate")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                    Spacer()
                                    Text(appModel.profileDraftHasBirthdate ? numericBirthdateText : "-")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(RepSyncTheme.textPrimary)
                                    if isEditingBirthdate {
                                        Button("Done") {
                                            isEditingBirthdate = false
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(RepSyncTheme.primaryGreen)
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 46)
                                .background(RepSyncTheme.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !isEditingBirthdate {
                                        appModel.profileDraftHasBirthdate = true
                                        isEditingBirthdate = true
                                    }
                                }

                                if isEditingBirthdate {
                                    HStack(spacing: 8) {
                                        biometricMenu(title: "Month", value: "\(birthdateComponents.month)") {
                                            ForEach(1...12, id: \.self) { month in
                                                Button("\(month)") {
                                                    updateDraftBirthdate(month: month)
                                                }
                                            }
                                        }

                                        biometricMenu(title: "Day", value: "\(birthdateComponents.day)") {
                                            ForEach(1...birthdateDayCount, id: \.self) { day in
                                                Button("\(day)") {
                                                    updateDraftBirthdate(day: day)
                                                }
                                            }
                                        }

                                        biometricMenu(title: "Year", value: "\(birthdateComponents.year)") {
                                            ForEach(Array(birthdateYearRange.reversed()), id: \.self) { year in
                                                Button("\(year)") {
                                                    updateDraftBirthdate(year: year)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if appModel.profileDraftHasBirthdate {
                                HStack {
                                    Text("Age")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                    Spacer()
                                    Text(calculatedDraftAgeText)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(RepSyncTheme.textPrimary)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 46)
                                .background(RepSyncTheme.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else {
                                Button("Set Birthdate") {
                                    appModel.profileDraftHasBirthdate = true
                                    isEditingBirthdate = true
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.primaryGreen)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(RepSyncTheme.primaryGreen.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .buttonStyle(.plain)
                            }

                            HStack {
                                Text("Weight")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                Spacer()
                                Text(appModel.profileState.latestWeight)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 46)
                            .background(RepSyncTheme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Picker("Sex", selection: $appModel.profileDraftSex) {
                                ForEach(BiologicalSex.allCases) { sex in
                                    Text(sex.rawValue).tag(sex)
                                }
                            }
                            .pickerStyle(.segmented)

                            Picker("Training Age", selection: $appModel.profileDraftTrainingAge) {
                                ForEach(TrainingAge.allCases) { trainingAge in
                                    Text(trainingAge.rawValue).tag(trainingAge)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.top, 12)

                        sectionTitle("Workout Schedule")
                        Text("Days you plan to work out. Used for reminders.")
                            .font(.system(size: 12))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        HStack(spacing: 8) {
                            ForEach(WorkoutWeekday.allCases) { day in
                                Button {
                                    appModel.toggleProfileWorkoutDay(day)
                                } label: {
                                    Text(day.shortLabel)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(appModel.profileDraftWorkoutDays.contains(day) ? RepSyncTheme.textOnLight : RepSyncTheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(appModel.profileDraftWorkoutDays.contains(day) ? RepSyncTheme.primaryGreen : RepSyncTheme.cardElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 12)

                        sectionTitle("Workout Reminders")

                        Toggle(isOn: $appModel.profileDraftReminderEnabled) {
                            Text("Reminders")
                                .font(.system(size: 16))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                        }
                        .tint(RepSyncTheme.primaryGreen)
                        .padding(.top, 12)

                        if appModel.profileDraftReminderEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notification Message")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textSecondary)

                                TextField("e.g. Push Day!", text: $appModel.profileDraftReminderMessage)
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                    .padding(.horizontal, 16)
                                    .frame(height: 48)
                                    .background(RepSyncTheme.input)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .padding(.top, 16)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Time")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textSecondary)

                                DatePicker(
                                    "Reminder Time",
                                    selection: Binding(
                                        get: { appModel.profileReminderTimeDate() },
                                        set: { appModel.updateProfileReminderTime($0) }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .tint(RepSyncTheme.primaryGreen)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .frame(height: 48)
                                .background(RepSyncTheme.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .padding(.top, 16)
                        }

                        sectionTitle("Workout Audio")
                        Text("Connect a music provider for workout audio controls.")
                            .font(.system(size: 12))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(appModel.selectedMusicProvider?.rawValue ?? "No provider selected")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)

                            Text(appModel.selectedMusicProvider == .spotify ? (appModel.musicMessage ?? appModel.spotifyStatusText) : appModel.appleMusicDisplayMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(RepSyncTheme.textSecondary)

                            if appModel.selectedMusicProvider == .spotify,
                               let debugText = appModel.spotifyDebugText,
                               !debugText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(debugText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                            }
                            if appModel.selectedMusicProvider == .spotify,
                               let callbackSummary = appModel.spotifyCallbackSummary,
                               !callbackSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(callbackSummary)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                            }

                            if appModel.selectedMusicProvider == .spotify {
                                Button(appModel.isSpotifyConnected ? "Reconnect Spotify" : "Connect Spotify") {
                                    appModel.connectSpotify()
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(RepSyncTheme.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }

                            if appModel.selectedMusicProvider == .appleMusic {
                                Button(appModel.isRefreshingAppleMusic ? "Refreshing Apple Music..." : "Refresh Apple Music") {
                                    appModel.refreshAppleMusicConnection()
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(RepSyncTheme.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                if let refreshSummary = appModel.appleMusicRefreshSummary,
                                   !refreshSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(refreshSummary)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                }
                            }

                            VStack(spacing: 10) {
                                Button("Apple Music") {
                                    appModel.selectMusicProvider(.appleMusic)
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(appModel.selectedMusicProvider == .appleMusic ? RepSyncTheme.textOnLight : RepSyncTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(appModel.selectedMusicProvider == .appleMusic ? RepSyncTheme.primaryGreen : RepSyncTheme.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Button("Spotify") {
                                    appModel.selectMusicProvider(.spotify)
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(appModel.selectedMusicProvider == .spotify ? RepSyncTheme.textOnLight : RepSyncTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(appModel.selectedMusicProvider == .spotify ? RepSyncTheme.primaryGreen : RepSyncTheme.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(.top, 12)

                        sectionTitle("Cloud Continuity")
                        Text(appModel.cloudKitMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onChange(of: avatarSelection) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    appModel.saveProfileAvatarData(data)
                }
                avatarSelection = nil
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().overlay(RepSyncTheme.divider)
                .padding(.top, 24)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
        }
    }

    private var halfInchOptions: [Double] {
        stride(from: 0.0, through: 11.5, by: 0.5).map { $0 }
    }

    private var calculatedDraftAgeText: String {
        let age = Calendar.repsync.dateComponents([.year], from: appModel.profileDraftBirthdate, to: Date()).year ?? 0
        return age >= 0 ? "\(age)" : "-"
    }

    private var birthdateComponents: (month: Int, day: Int, year: Int) {
        let components = Calendar.repsync.dateComponents([.month, .day, .year], from: appModel.profileDraftBirthdate)
        return (
            month: components.month ?? 1,
            day: components.day ?? 1,
            year: components.year ?? currentYear
        )
    }

    private var birthdateDayCount: Int {
        let components = birthdateComponents
        return dayCount(month: components.month, year: components.year)
    }

    private var birthdateYearRange: ClosedRange<Int> {
        1900...currentYear
    }

    private var currentYear: Int {
        Calendar.repsync.component(.year, from: Date())
    }

    private var numericBirthdateText: String {
        let components = birthdateComponents
        return "\(components.month)/\(components.day)/\(components.year)"
    }

    private func updateDraftBirthdate(month: Int? = nil, day: Int? = nil, year: Int? = nil) {
        let current = birthdateComponents
        let newMonth = month ?? current.month
        let newYear = year ?? current.year
        let newDay = min(day ?? current.day, dayCount(month: newMonth, year: newYear))

        if let date = Calendar.repsync.date(from: DateComponents(year: newYear, month: newMonth, day: newDay)) {
            appModel.profileDraftBirthdate = min(date, Date())
            appModel.profileDraftHasBirthdate = true
        }
    }

    private func dayCount(month: Int, year: Int) -> Int {
        guard let date = Calendar.repsync.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = Calendar.repsync.range(of: .day, in: .month, for: date) else {
            return 31
        }
        return range.count
    }

    private func biometricMenu<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(RepSyncTheme.primaryGreen)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(RepSyncTheme.input)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct BodyweightPhotoPickerRow: View {
    let title: String
    let photoPath: String?
    @Binding var selection: PhotosPickerItem?
    let onCamera: () -> Void
    let onPreview: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let canUseCamera = UIImagePickerController.isSourceTypeAvailable(.camera)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onPreview) {
                    BodyweightPhotoThumbnail(photoPath: photoPath)
                        .frame(width: 54, height: 54)
                }
                .buttonStyle(.plain)
                .disabled(bodyweightPhotoImage(from: photoPath) == nil)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text(photoPath == nil ? "Optional" : "Tap photo to view")
                        .font(.system(size: 12))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    onCamera()
                } label: {
                    BodyweightPhotoActionLabel(title: "Camera")
                }
                .buttonStyle(.plain)
                .disabled(!canUseCamera)
                .opacity(canUseCamera ? 1 : 0.5)

                PhotosPicker(selection: $selection, matching: .images) {
                    BodyweightPhotoActionLabel(title: photoPath == nil ? "Library" : "Change")
                }
                .buttonStyle(.plain)

                if photoPath != nil {
                    Button {
                        onRemove()
                    } label: {
                        BodyweightPhotoActionLabel(title: "Remove", isDestructive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct BodyweightPhotoActionLabel: View {
    let title: String
    var isDestructive = false

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(RepSyncTheme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(isDestructive ? RepSyncTheme.destructive.opacity(0.85) : RepSyncTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct BodyweightCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

private struct BodyweightPhotoThumbnail: View {
    let photoPath: String?

    var body: some View {
        Group {
            if let image = bodyweightPhotoImage(from: photoPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(RepSyncTheme.card)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct BodyweightPhotoPreview: View {
    let photoPath: String?

    var body: some View {
        ZStack {
            RepSyncTheme.background.ignoresSafeArea()
            if let image = bodyweightPhotoImage(from: photoPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
            }
        }
    }
}

struct BodyweightEntriesScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var editingPhotoSelection: PhotosPickerItem?
    @State private var showsEditingCamera = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                RepSyncHeaderButton(title: "<") { appModel.pop() }
                Text("Bodyweight Entries")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RepSyncTheme.card)

            List {
                Section {
                    HStack(alignment: .center) {
                        Text(appModel.bodyweightEntriesState.filterText)
                            .font(.system(size: appModel.bodyweightEntriesState.startDate == nil ? 14 : 13, weight: appModel.bodyweightEntriesState.startDate == nil ? .regular : .medium))
                            .foregroundStyle(appModel.bodyweightEntriesState.startDate == nil ? RepSyncTheme.textSecondary : RepSyncTheme.primaryGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if appModel.bodyweightEntriesState.startDate == nil {
                            Button("Filter by Date") {
                                appModel.showBodyweightFilter()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(RepSyncTheme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            Button("Clear") {
                                appModel.clearBodyweightFilter()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(RepSyncTheme.destructive.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(RepSyncTheme.background)
                    .listRowSeparator(.hidden)

                    Button {
                        appModel.showBodyweightCompare()
                    } label: {
                        Text("Compare Progress")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(appModel.bodyweightPhotoEntries.count >= 2 ? RepSyncTheme.primaryGreen : RepSyncTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(appModel.bodyweightPhotoEntries.count >= 2 ? RepSyncTheme.primaryGreen.opacity(0.15) : RepSyncTheme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(appModel.bodyweightPhotoEntries.count < 2)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(RepSyncTheme.background)
                    .listRowSeparator(.hidden)

                    ForEach(appModel.bodyweightEntriesState.filteredEntries) { entry in
                        HStack(spacing: 10) {
                            Button {
                                appModel.beginEditBodyweight(entry)
                            } label: {
                                Text(entry.dateText)
                                    .font(.system(size: 14))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                    .frame(alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            if entry.photoPath != nil {
                                Button {
                                    appModel.previewBodyweightPhoto(entry.photoPath)
                                } label: {
                                    BodyweightPhotoThumbnail(photoPath: entry.photoPath)
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                appModel.beginEditBodyweight(entry)
                            } label: {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit bodyweight entry")

                            Button {
                                appModel.beginEditBodyweight(entry)
                            } label: {
                                Text(entry.weightText)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                    .frame(minWidth: 84, alignment: .trailing)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RepSyncTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                appModel.confirmDeleteBodyweight(entry)
                            } label: {
                                Text("Remove")
                            }
                            .tint(RepSyncTheme.destructive)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(RepSyncTheme.background)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(RepSyncTheme.background)
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .sheet(item: $appModel.editingBodyweight) { entry in
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Weight")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                DatePicker("Date", selection: $appModel.editingBodyweightDate, displayedComponents: .date)
                    .tint(RepSyncTheme.primaryGreen)
                    .foregroundStyle(RepSyncTheme.textPrimary)
                TextField("Weight", text: $appModel.editingBodyweightValue)
                    .keyboardType(.decimalPad)
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(RepSyncTheme.input)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: appModel.editingBodyweightValue) { _, newValue in
                        let sanitized = sanitizeDecimalInput(newValue)
                        if sanitized != newValue {
                            appModel.editingBodyweightValue = sanitized
                        }
                    }
                BodyweightPhotoPickerRow(
                    title: "Progress Photo",
                    photoPath: appModel.editingBodyweightPhotoPath,
                    selection: $editingPhotoSelection,
                    onCamera: { showsEditingCamera = true },
                    onPreview: { appModel.previewBodyweightPhoto(appModel.editingBodyweightPhotoPath) },
                    onRemove: { appModel.removeEditingBodyweightPhoto() }
                )
                Button("Save") { appModel.saveEditedBodyweight() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RepSyncTheme.primaryGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
            }
            .padding(24)
            .background(RepSyncTheme.background)
            .presentationDetents([.medium])
            .onChange(of: editingPhotoSelection) { _, newItem in
                guard let newItem else { return }
                Task { @MainActor in
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        appModel.saveEditingBodyweightPhotoData(data)
                    }
                    editingPhotoSelection = nil
                }
            }
            .sheet(isPresented: $showsEditingCamera) {
                BodyweightCameraPicker { image in
                    if let data = image.jpegData(compressionQuality: 0.9) {
                        appModel.saveEditingBodyweightPhotoData(data)
                    }
                }
            }
        }
        .sheet(isPresented: $appModel.showsBodyweightFilterSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Filter by Date Range")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)

                DatePicker("Start Date", selection: $appModel.bodyweightFilterStartDate, displayedComponents: .date)
                    .tint(RepSyncTheme.primaryGreen)
                    .foregroundStyle(RepSyncTheme.textPrimary)

                DatePicker("End Date", selection: $appModel.bodyweightFilterEndDate, displayedComponents: .date)
                    .tint(RepSyncTheme.primaryGreen)
                    .foregroundStyle(RepSyncTheme.textPrimary)

                HStack(spacing: 12) {
                    Button("Clear") {
                        appModel.clearBodyweightFilter()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RepSyncTheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("Apply") {
                        appModel.applyBodyweightFilter()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RepSyncTheme.primaryGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Spacer()
            }
            .padding(24)
            .background(RepSyncTheme.background)
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $appModel.showsBodyweightCompareSheet) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Compare Progress")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)

                    if appModel.bodyweightPhotoEntries.count >= 2 {
                        VStack(spacing: 10) {
                            compareDateMenu(
                                title: "First Date",
                                selection: Binding(
                                    get: { appModel.bodyweightCompareFirstEntry?.id ?? appModel.bodyweightPhotoEntries[0].id },
                                    set: { appModel.bodyweightCompareFirstEntryID = $0 }
                                )
                            )

                            compareDateMenu(
                                title: "Second Date",
                                selection: Binding(
                                    get: { appModel.bodyweightCompareSecondEntry?.id ?? appModel.bodyweightPhotoEntries[1].id },
                                    set: { appModel.bodyweightCompareSecondEntryID = $0 }
                                )
                            )
                        }

                        HStack(alignment: .top, spacing: 10) {
                            comparePhotoColumn(entry: appModel.bodyweightCompareFirstEntry)
                            comparePhotoColumn(entry: appModel.bodyweightCompareSecondEntry)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Add photos to at least two bodyweight entries to compare progress.")
                            .font(.system(size: 14))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .presentationDetents([.large])
        }
        .sheet(isPresented: Binding(
            get: { appModel.previewingBodyweightPhotoPath != nil },
            set: { if !$0 { appModel.dismissBodyweightPhotoPreview() } }
        )) {
            BodyweightPhotoPreview(photoPath: appModel.previewingBodyweightPhotoPath)
        }
        .alert("Delete Entry?", isPresented: Binding(
            get: { appModel.deletingBodyweight != nil },
            set: { if !$0 { appModel.dismissDeleteBodyweightConfirmation() } }
        )) {
            Button("Cancel", role: .cancel) {
                appModel.dismissDeleteBodyweightConfirmation()
            }
            Button("Delete", role: .destructive) {
                if let entry = appModel.deletingBodyweight {
                    appModel.deleteBodyweight(entry)
                }
            }
        } message: {
            Text("This bodyweight entry will be removed permanently.")
        }
    }

    private func compareDateMenu(title: String, selection: Binding<UUID>) -> some View {
        let selectedDateText = appModel.bodyweightPhotoEntries.first { $0.id == selection.wrappedValue }?.dateText ?? "Select"

        return Menu {
            ForEach(appModel.bodyweightPhotoEntries) { entry in
                Button(entry.dateText) {
                    selection.wrappedValue = entry.id
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RepSyncTheme.textSecondary)
                Spacer(minLength: 8)
                Text(selectedDateText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RepSyncTheme.primaryGreen)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RepSyncTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func comparePhotoColumn(entry: BodyweightEntryModel?) -> some View {
        VStack(spacing: 8) {
            Text(entry?.dateText ?? "-")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .lineLimit(1)

            Button {
                appModel.previewBodyweightPhoto(entry?.photoPath)
            } label: {
                GeometryReader { proxy in
                    BodyweightPhotoThumbnail(photoPath: entry?.photoPath)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .aspectRatio(0.72, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(entry?.weightText ?? "-")
                .font(.system(size: 13))
                .foregroundStyle(RepSyncTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(RepSyncTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private func sanitizeDecimalInput(_ value: String) -> String {
    var result = ""
    var hasDecimalSeparator = false

    for character in value {
        if character.isNumber {
            result.append(character)
        } else if character == "." && !hasDecimalSeparator {
            hasDecimalSeparator = true
            result.append(character)
        }
    }

    return result
}

private func sanitizeIntegerInput(_ value: String) -> String {
    value.filter(\.isNumber)
}

private func bodyweightPhotoImage(from storedValue: String?) -> UIImage? {
    guard let storedValue, !storedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }

    let fileManager = FileManager.default
    let directURL = URL(fileURLWithPath: storedValue)

    if fileManager.fileExists(atPath: directURL.path),
       let image = UIImage(contentsOfFile: directURL.path) {
        return image
    }

    let filename = directURL.lastPathComponent
    guard !filename.isEmpty else { return nil }

    guard let directory = try? fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    ).appendingPathComponent("RepSyncBodyweightPhotos", isDirectory: true) else {
        return nil
    }

    let resolvedURL = directory.appendingPathComponent(filename)
    guard fileManager.fileExists(atPath: resolvedURL.path) else { return nil }
    return UIImage(contentsOfFile: resolvedURL.path)
}
