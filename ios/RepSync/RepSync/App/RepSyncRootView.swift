import SwiftUI

struct RepSyncRootView: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

    var body: some View {
        NavigationStack(path: $appModel.navigationPath) {
            ZStack(alignment: .bottom) {
                RepSyncTheme.background.ignoresSafeArea()

                Group {
                    switch appModel.selectedTab {
                    case .home:
                        HomeScreen()
                    case .profile:
                        ProfileScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top, spacing: 0) {
                if let banner = appModel.activeWorkoutBanner, !appModel.isOnActiveWorkoutScreen {
                    RepSyncActiveWorkoutBanner(
                        model: banner,
                        action: { appModel.resumeActiveWorkout() }
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if appModel.showsBottomBar {
                    RepSyncBottomNavBar(selectedTab: $appModel.selectedTab)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .background(RepSyncTheme.background.opacity(0.95))
                }
            }
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
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
