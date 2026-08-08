import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                RepSyncCard {
                    HStack {
                        Button("<<") { appModel.previousMonth() }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(width: 40, height: 40)
                        Spacer()
                        Text(appModel.homeState.monthTitle)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                        Spacer()
                        Button(">>") { appModel.nextMonth() }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(width: 40, height: 40)
                    }

                    VStack(spacing: 8) {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"], id: \.self) { day in
                                Text(day)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.top, 16)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(appModel.homeState.calendarDays) { day in
                            Button {
                                appModel.showDayView(for: day.date)
                            } label: {
                                Text(day.label)
                                    .font(.system(size: 16, weight: day.hasWorkout ? .semibold : .regular))
                                    .foregroundStyle(day.isInCurrentMonth ? RepSyncTheme.textPrimary : RepSyncTheme.textSecondary.opacity(0.4))
                                    .frame(width: 36, height: 36)
                                    .background(day.hasWorkout ? RepSyncTheme.calendarWorkoutDay : .clear)
                                    .clipShape(Circle())
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 16)

                if appModel.profileState.streak > 0 {
                    RepSyncStreakBadge(streak: appModel.profileState.streak)
                        .padding(.top, 12)
                }

                Spacer(minLength: 12)

                VStack(spacing: 12) {
                    RepSyncPrimaryButton(title: "Workouts", fill: RepSyncTheme.card) {
                        appModel.showWorkouts()
                    }

                    RepSyncPrimaryButton(title: "Quick Go") {
                        appModel.showQuickWorkout()
                    }
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 16)
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .confirmationDialog("Choose Music Provider", isPresented: $appModel.showsMusicProviderPicker) {
            Button("Apple Music") { appModel.selectMusicProvider(.appleMusic) }
            Button("Spotify") { appModel.selectMusicProvider(.spotify) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose Apple Music or Spotify for workout audio controls.")
        }
    }
}

struct LeaderboardScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var showsTrackedLifts = false
    @State private var showsUpperBody = true
    @State private var showsLowerBody = true

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                RepSyncCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Leaderboard")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)

                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Overall")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                Text(appModel.leaderboardState.overallRank.rawValue)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(appModel.leaderboardState.overallRank == .unranked ? RepSyncTheme.textSecondary : RepSyncTheme.primaryGreen)
                            }

                            Spacer()

                            Text(appModel.leaderboardState.overallScoreText)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(RepSyncTheme.cardElevated)
                                .clipShape(Capsule())
                        }

                        Text(appModel.leaderboardState.classSummary)
                            .font(.system(size: 14))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                RepSyncCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showsTrackedLifts.toggle()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Tracked Lifts")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(RepSyncTheme.textPrimary)
                                    Text("\(appModel.trackedLeaderboardLifts.count) of \(CanonicalLift.allCases.count) shown")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: showsTrackedLifts ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if showsTrackedLifts {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                                ForEach(CanonicalLift.allCases) { lift in
                                    trackedLiftToggle(lift)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                VStack(spacing: 10) {
                    if appModel.leaderboardState.rows.isEmpty {
                        RepSyncCard {
                            Text("Select at least one tracked lift to show rankings.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        leaderboardSection(
                            title: LeaderboardLiftSection.upperBody.rawValue,
                            rows: rows(in: .upperBody),
                            isExpanded: $showsUpperBody
                        )
                        leaderboardSection(
                            title: LeaderboardLiftSection.lowerBody.rawValue,
                            rows: rows(in: .lowerBody),
                            isExpanded: $showsLowerBody
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
    }

    private func rows(in section: LeaderboardLiftSection) -> [LeaderboardLiftRow] {
        appModel.leaderboardState.rows.filter { $0.lift.leaderboardSection == section }
    }

    private func leaderboardSection(
        title: String,
        rows: [LeaderboardLiftRow],
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)

                    Text("\(rows.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(RepSyncTheme.cardElevated)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(RepSyncTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                if rows.isEmpty {
                    RepSyncCard {
                        Text("No tracked lifts in this section.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(rows) { row in
                        leaderboardLiftCard(row)
                    }
                }
            }
        }
    }

    private func trackedLiftToggle(_ lift: CanonicalLift) -> some View {
        let isTracked = appModel.trackedLeaderboardLifts.contains(lift)

        return Button {
            appModel.toggleLeaderboardLift(lift)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isTracked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isTracked ? RepSyncTheme.primaryGreen : RepSyncTheme.textSecondary)

                Text(lift.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(isTracked ? RepSyncTheme.primaryGreen.opacity(0.14) : RepSyncTheme.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func leaderboardRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(RepSyncTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func leaderboardLiftCard(_ row: LeaderboardLiftRow) -> some View {
        RepSyncCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.lift.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)

                    Spacer()

                    Text(row.rank.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(row.rank == .unranked ? RepSyncTheme.textSecondary : RepSyncTheme.primaryGreen)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background((row.rank == .unranked ? RepSyncTheme.cardElevated : RepSyncTheme.primaryGreen.opacity(0.15)))
                        .clipShape(Capsule())
                }

                HStack(spacing: 10) {
                    liftMetric(title: "Best", value: row.bestSetText)
                    liftMetric(title: "Est. 1RM", value: row.estimatedOneRepMaxText)
                }

                if let sourceExerciseName = row.sourceExerciseName {
                    Text("Matched from \(sourceExerciseName)")
                        .font(.system(size: 12))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }

                if let nextRankText = row.nextRankText {
                    Text(nextRankText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func liftMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RepSyncTheme.textSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct HomeMusicWidget: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var showsAppleMusicPicker = false

    var body: some View {
        RepSyncCard {
            ScrollView(showsIndicators: true) {
                Group {
                    if appModel.shouldShowMusicConnectPrompt {
                        musicConnectPrompt
                    } else if appModel.selectedMusicProvider == .spotify {
                        spotifyControls
                    } else {
                        appleMusicControls
                    }
                }
            }
            .frame(maxHeight: 360)
        }
        .sheet(isPresented: $showsAppleMusicPicker) {
            AppleMusicPlaylistPickerSheet(
                items: appModel.allAppleMusicBrowseItems,
                onRefresh: { appModel.refreshAppleMusicConnection() },
                onSelect: { item in
                    appModel.playAppleMusicQuickPick(item)
                    showsAppleMusicPicker = false
                }
            )
            .environmentObject(appModel)
            .presentationDetents([.large])
        }
    }

    private var musicConnectPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Audio")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
            Text("Connect Apple Music or Spotify controls here for faster workout sessions.")
                .font(.system(size: 14))
                .foregroundStyle(RepSyncTheme.textSecondary)
            HStack(spacing: 10) {
                Button("Not Now") {
                    appModel.dismissMusicPrompt()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Connect") {
                    appModel.showMusicProviderPicker()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(RepSyncTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var spotifyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spotify")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
            Text(appModel.musicNowPlaying?.title ?? appModel.spotifyStatusText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
            Text(appModel.musicNowPlaying?.artist ?? (appModel.musicMessage ?? "Use Spotify controls directly inside RepSync."))
                .font(.system(size: 13))
                .foregroundStyle(RepSyncTheme.textSecondary)
            if let debugText = appModel.spotifyDebugText,
               !debugText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(debugText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RepSyncTheme.textSecondary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let callbackSummary = appModel.spotifyCallbackSummary,
               !callbackSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(callbackSummary)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(RepSyncTheme.textSecondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if appModel.activeWorkoutState?.musicProvider == .spotify,
               let playlistName = appModel.activeWorkoutState?.musicPlaylistName,
               !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Current mix: \(playlistName)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
            }
            HStack(spacing: 10) {
                Button(appModel.isSpotifyConnected ? (appModel.isSpotifyPlaying ? "Pause" : "Play") : "Connect") {
                    if appModel.isSpotifyConnected {
                        appModel.toggleSpotifyPlayback()
                    } else {
                        appModel.connectSpotify()
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RepSyncTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(appModel.isSpotifyConnected ? "Next" : "Open App") {
                    if appModel.isSpotifyConnected {
                        appModel.skipSpotifyTrack()
                    } else {
                        appModel.openSpotifyApp()
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 10) {
                if appModel.activeWorkoutState?.musicProvider == .spotify {
                    Button("Workout Mix") {
                        appModel.playCurrentWorkoutMix()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(RepSyncTheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button("Change Provider") {
                    appModel.showMusicProviderPicker()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var appleMusicControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                if let artwork = appModel.musicNowPlaying?.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(RepSyncTheme.cardElevated)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundStyle(RepSyncTheme.textSecondary)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Music")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text(appModel.musicNowPlaying?.title ?? appModel.appleMusicStatusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .lineLimit(1)
                    Text(appModel.musicNowPlaying?.artist ?? appModel.appleMusicDisplayMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 10) {
                Button(appModel.isAppleMusicPlaying ? "Pause" : "Play") {
                    appModel.toggleAppleMusicPlayback()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RepSyncTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Next") {
                    appModel.skipAppleMusicTrack()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Open") {
                    appModel.openAppleMusicApp()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 10) {
                if appModel.hasCurrentAppleMusicWorkoutMix {
                    Button("Workout Mix") {
                        appModel.playCurrentWorkoutMix()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(RepSyncTheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button(appModel.isRefreshingAppleMusic ? "Refreshing..." : "Refresh Library") {
                    appModel.refreshAppleMusicConnection()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let refreshSummary = appModel.appleMusicRefreshSummary,
               !refreshSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(refreshSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RepSyncTheme.textSecondary)
            }

            if let playlistName = appModel.currentAppleMusicWorkoutMixLabel {
                HStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RepSyncTheme.primaryGreen)
                    Text("Current workout mix: \(playlistName)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 10) {
                Button("Browse All") {
                    showsAppleMusicPicker = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Change Provider") {
                    appModel.showMusicProviderPicker()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            let libraryPlaylists = Array(appModel.appleMusicLibraryPlaylists.prefix(3))
            let recentItems = Array(appModel.appleMusicRecentItems.filter { item in
                !libraryPlaylists.contains(where: { $0.id == item.id })
            }.prefix(3))

            if !libraryPlaylists.isEmpty || !recentItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Library Playlists")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textSecondary)

                    if libraryPlaylists.isEmpty {
                        Text("No saved library playlists found yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                    } else {
                        ForEach(libraryPlaylists) { item in
                            appleMusicQuickPickRow(item)
                        }
                    }

                    if !recentItems.isEmpty {
                        Text("Recently Played")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .padding(.top, 4)

                        ForEach(recentItems) { item in
                            appleMusicQuickPickRow(item)
                        }
                    }
                }
            }
        }
    }

    private func appleMusicQuickPickRow(_ item: MusicQuickPickItem) -> some View {
        Button {
            appModel.playAppleMusicQuickPick(item)
        } label: {
            HStack(spacing: 12) {
                quickPickArtwork(url: item.artworkURL)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RepSyncTheme.primaryGreen)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RepSyncTheme.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct AppleMusicPlaylistPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: RepSyncAppModel

    let items: [MusicQuickPickItem]
    let onRefresh: () -> Void
    let onSelect: (MusicQuickPickItem) -> Void

    @State private var searchText = ""

    private var filteredItems: [MusicQuickPickItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search playlists", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(RepSyncTheme.input)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 10) {
                    Button(appModel.isRefreshingAppleMusic ? "Refreshing..." : "Refresh Library") {
                        onRefresh()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(RepSyncTheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(RepSyncTheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let refreshSummary = appModel.appleMusicRefreshSummary,
                   !refreshSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(refreshSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }

                ScrollView {
                    VStack(spacing: 8) {
                        if filteredItems.isEmpty {
                            Text(appModel.appleMusicDisplayMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(filteredItems) { item in
                                Button {
                                    onSelect(item)
                                } label: {
                                    HStack(spacing: 12) {
                                        AppleMusicQuickPickArtwork(url: item.artworkURL)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(RepSyncTheme.textPrimary)
                                                .lineLimit(1)
                                            Text(item.subtitle)
                                                .font(.system(size: 12))
                                                .foregroundStyle(RepSyncTheme.textSecondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(RepSyncTheme.primaryGreen)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(RepSyncTheme.cardElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(RepSyncTheme.background.ignoresSafeArea())
            .navigationTitle("Apple Music")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AppleMusicQuickPickArtwork: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(RepSyncTheme.card)
            .overlay(
                Image(systemName: "music.note.list")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textSecondary)
            )
    }
}

private func quickPickArtwork(url: URL?) -> some View {
    AppleMusicQuickPickArtwork(url: url)
}
