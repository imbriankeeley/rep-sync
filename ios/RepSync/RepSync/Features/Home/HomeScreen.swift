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

                if appModel.shouldShowMusicWidget {
                    HomeMusicWidget()
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
            Button("YouTube Music") { appModel.selectMusicProvider(.youtubeMusic) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apple Music has native playback controls here. Spotify and YouTube Music can be saved as providers and opened from workout mixes through URL bridges.")
        }
    }
}

private struct HomeMusicWidget: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

    var body: some View {
        RepSyncCard {
            if appModel.shouldShowMusicConnectPrompt {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workout Audio")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text("Connect Apple Music, Spotify, or YouTube Music controls here for faster workout sessions.")
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
            } else if appModel.selectedMusicProvider == .spotify {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Spotify")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text(appModel.musicMessage ?? "Spotify is ready as your workout audio provider.")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                    if appModel.activeWorkoutState?.musicProvider == .spotify,
                       let playlistName = appModel.activeWorkoutState?.musicPlaylistName,
                       !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Current mix: \(playlistName)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                    }
                    HStack(spacing: 10) {
                        if appModel.activeWorkoutState?.musicProvider == .spotify {
                            Button("Open Workout Mix") {
                                appModel.playCurrentWorkoutMix()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(RepSyncTheme.primaryGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Button("Open Spotify") {
                            appModel.openSpotifyApp()
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
            } else if appModel.selectedMusicProvider == .youtubeMusic {
                VStack(alignment: .leading, spacing: 10) {
                    Text("YouTube Music")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text(appModel.musicMessage ?? "YouTube Music is ready as your workout audio provider.")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                    if appModel.activeWorkoutState?.musicProvider == .youtubeMusic,
                       let playlistName = appModel.activeWorkoutState?.musicPlaylistName,
                       !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Current mix: \(playlistName)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                    }
                    HStack(spacing: 10) {
                        if appModel.activeWorkoutState?.musicProvider == .youtubeMusic {
                            Button("Open Workout Mix") {
                                appModel.playCurrentWorkoutMix()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(RepSyncTheme.primaryGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Button("Open YT Music") {
                            appModel.openYouTubeMusicApp()
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
            } else {
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
                            Text(appModel.musicNowPlaying?.artist ?? (appModel.musicMessage ?? "Use the widget to control your workout audio."))
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

                    if appModel.activeWorkoutState?.musicProvider == .appleMusic,
                       let playlistName = appModel.activeWorkoutState?.musicPlaylistName,
                       !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Play Workout Mix: \(playlistName)") {
                            appModel.playCurrentWorkoutMix()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(RepSyncTheme.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    let quickPicks = Array((appModel.appleMusicLibraryPlaylists + appModel.appleMusicRecentItems).uniquedByID().prefix(3))
                    if !quickPicks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Picks")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textSecondary)

                            ForEach(quickPicks) { item in
                                Button {
                                    appModel.playAppleMusicQuickPick(item)
                                } label: {
                                    HStack {
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
        }
    }
}

private extension Array where Element == MusicQuickPickItem {
    func uniquedByID() -> [MusicQuickPickItem] {
        var seen = Set<String>()
        return filter { item in
            seen.insert(item.id).inserted
        }
    }
}
