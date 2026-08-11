import SwiftUI
import UIKit

struct RepSyncRootView: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

    var body: some View {
        NavigationStack(path: $appModel.navigationPath) {
            VStack(spacing: 0) {
                if let banner = appModel.activeWorkoutBanner, !appModel.isOnActiveWorkoutScreen {
                    RepSyncActiveWorkoutBanner(
                        model: banner,
                        action: { appModel.resumeActiveWorkout() }
                    )
                    .padding(.bottom, 8)
                    .background(RepSyncTheme.background)
                }

                ZStack {
                    RepSyncTheme.background.ignoresSafeArea()

                    TabView(selection: $appModel.selectedTab) {
                    HomeScreen()
                        .tag(RepSyncTab.home)
                        .tabItem {
                            Label("Home", systemImage: "chart.bar")
                        }

                    LeaderboardScreen()
                        .tag(RepSyncTab.leaderboard)
                        .tabItem {
                            Label("Leaderboard", systemImage: "trophy")
                        }

                    ProfileScreen()
                        .tag(RepSyncTab.profile)
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle")
                        }
                    }
                    .tint(RepSyncTheme.primaryGreen)
                    .toolbar(appModel.showsBottomBar ? .visible : .hidden, for: .tabBar)
                    .background(RepSyncTheme.background)
                    .onChange(of: appModel.selectedTab) { _, _ in
                        appModel.navigationPath.removeAll()
                    }
                    .onAppear {
                        configureLegacyTabBarAppearance()
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: RepSyncRoute.self) { route in
                switch route {
                case .workouts:
                    WorkoutsListScreen()
                case .workoutEditor:
                    WorkoutEditorScreen()
                case .activeWorkout:
                    ActiveWorkoutScreen()
                case .dayView:
                    DayViewScreen()
                case .exerciseHistory:
                    ExerciseHistoryScreen()
                case .bodyweightEntries:
                    BodyweightEntriesScreen()
                case .editProfile:
                    EditProfileScreen()
                case .rankedMovements:
                    RankedMovementsScreen()
                }
            }
        }
        .preferredColorScheme(.dark)
        .overlay {
            if let levelUpEvent = appModel.levelUpEvent {
                LevelUpOverlay(
                    event: levelUpEvent,
                    onDismiss: { appModel.dismissLevelUp() },
                    onViewLeaderboard: { appModel.viewLeaderboardFromLevelUp() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: appModel.levelUpEvent)
    }

    private func configureLegacyTabBarAppearance() {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tabBarAppearance.backgroundColor = UIColor(RepSyncTheme.background).withAlphaComponent(0.18)
        tabBarAppearance.shadowColor = UIColor.white.withAlphaComponent(0.10)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

private struct LevelUpOverlay: View {
    let event: LevelUpEvent
    let onDismiss: () -> Void
    let onViewLeaderboard: () -> Void

    @State private var isPresented = false
    @State private var iconCelebrationPhase = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.64)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    ZStack {
                        Circle()
                            .fill(RepSyncTheme.primaryGreen.opacity(0.22))
                            .frame(width: 104, height: 104)
                            .scaleEffect(iconCelebrationPhase ? 1.22 : (isPresented ? 1.08 : 0.82))
                            .opacity(iconCelebrationPhase ? 0.78 : 1)

                        Circle()
                            .fill(RepSyncTheme.primaryGreen.opacity(0.58))
                            .frame(width: 78, height: 78)
                            .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen.opacity(0.58), shape: .circle)
                            .scaleEffect(iconCelebrationPhase ? 1.06 : 1)

                        Image(systemName: event.iconName)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .scaleEffect(iconCelebrationPhase ? 1.22 : (isPresented ? 1 : 0.72))
                            .rotationEffect(.degrees(iconCelebrationPhase ? 8 : -8))
                            .symbolEffect(.bounce, value: iconCelebrationPhase)
                    }
                }
                .frame(width: 184, height: 142)
                .padding(.top, -4)

                VStack(spacing: 6) {
                    Text("Level Up")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)

                    Text("You reached Level \(event.newLevel)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.primaryGreen)

                    Text("Level \(event.previousLevel) -> Level \(event.newLevel)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }

                HStack(spacing: 10) {
                    Button {
                        onDismiss()
                    } label: {
                        Text("OK")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onViewLeaderboard()
                    } label: {
                        Text("View Leaderboard")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(RepSyncTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(RepSyncTheme.primaryGreen.opacity(0.34), lineWidth: 1)
            )
            .shadow(color: RepSyncTheme.primaryGreen.opacity(0.18), radius: 24, x: 0, y: 14)
            .padding(.horizontal, 24)
            .scaleEffect(isPresented ? 1 : 0.88)
            .opacity(isPresented ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.68)) {
                isPresented = true
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.42).delay(0.12)) {
                iconCelebrationPhase = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                    iconCelebrationPhase = false
                }
            }
        }
    }
}
