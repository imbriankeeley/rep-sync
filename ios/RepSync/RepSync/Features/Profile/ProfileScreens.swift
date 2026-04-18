import PhotosUI
import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

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

                RepSyncStreakBadge(streak: appModel.profileState.streak)

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

                        if appModel.profileState.chartPoints.count >= 2 {
                            RepSyncLineChart(points: appModel.profileState.chartPoints, label: "lbs")
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

                        Text("Recent Entries")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textSecondary)

                        ForEach(appModel.profileState.recentEntries) { entry in
                            HStack(spacing: 12) {
                                Text(entry.dateText)
                                    .font(.system(size: 14))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(entry.weightText)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                    .frame(minWidth: 84, alignment: .trailing)
                                Button {
                                    appModel.beginEditBodyweight(entry)
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                        .frame(width: 28, height: 28)
                                        .background(RepSyncTheme.card)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                Button {
                                    appModel.confirmDeleteBodyweight(entry)
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(RepSyncTheme.textPrimary)
                                        .frame(width: 28, height: 28)
                                        .background(RepSyncTheme.destructive.opacity(0.8))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RepSyncTheme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    }
}

struct EditProfileScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var avatarSelection: PhotosPickerItem?

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
                        Text("Connect a music provider for quick controls on the home screen during workouts.")
                            .font(.system(size: 12))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(appModel.selectedMusicProvider?.rawValue ?? "No provider selected")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)

                            Text(appModel.musicMessage ?? appModel.appleMusicStatusText)
                                .font(.system(size: 13))
                                .foregroundStyle(RepSyncTheme.textSecondary)

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

                                HStack(spacing: 10) {
                                    Button("Spotify") {
                                        appModel.selectMusicProvider(.spotify)
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(appModel.selectedMusicProvider == .spotify ? RepSyncTheme.textOnLight : RepSyncTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(appModel.selectedMusicProvider == .spotify ? RepSyncTheme.primaryGreen : RepSyncTheme.cardElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    Button("YouTube Music") {
                                        appModel.selectMusicProvider(.youtubeMusic)
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(appModel.selectedMusicProvider == .youtubeMusic ? RepSyncTheme.textOnLight : RepSyncTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(appModel.selectedMusicProvider == .youtubeMusic ? RepSyncTheme.primaryGreen : RepSyncTheme.cardElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
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
}

struct BodyweightEntriesScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

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

            ScrollView {
                VStack(spacing: 8) {
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

                    ForEach(appModel.bodyweightEntriesState.filteredEntries) { entry in
                        HStack(spacing: 12) {
                            Text(entry.dateText)
                                .font(.system(size: 14))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(entry.weightText)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(minWidth: 84, alignment: .trailing)
                            Button {
                                appModel.beginEditBodyweight(entry)
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                    .frame(width: 28, height: 28)
                                    .background(RepSyncTheme.cardElevated)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            Button {
                                appModel.confirmDeleteBodyweight(entry)
                            } label: {
                                Text("X")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(RepSyncTheme.destructive.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RepSyncTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
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
}
