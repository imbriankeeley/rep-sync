import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var showsMonthPicker = false
    @State private var selectedMonth = Date()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let monthSymbols = DateFormatter().monthSymbols ?? []

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                RepSyncCard {
                    HStack {
                        Button {
                            appModel.previousMonth()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(width: 40, height: 40)
                                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            selectedMonth = appModel.homeState.currentMonth
                            showsMonthPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 15, weight: .bold))
                                Text(appModel.homeState.monthTitle)
                                    .font(.system(size: 21, weight: .bold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Choose month and year")

                        Spacer()

                        Button {
                            appModel.nextMonth()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(width: 40, height: 40)
                                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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
                                    .foregroundStyle(calendarDayTextColor(day))
                                    .frame(width: 36, height: 36)
                                    .repsyncGlassButtonBackground(calendarDayFill(day), shape: .circle)
                                    .overlay(
                                        Circle()
                                            .stroke(calendarDayBorder(day), lineWidth: 1)
                                    )
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(DateFormatter.repsyncLongDate.string(from: day.date))")
                        }
                    }
                }
                .padding(.top, 16)

                if appModel.profileState.streak > 0 {
                    RepSyncStreakBadge(
                        streak: appModel.profileState.streak,
                        workoutCount: appModel.profileState.workoutCount
                    )
                        .padding(.top, 12)
                }

                Spacer(minLength: 12)

                VStack(spacing: 12) {
                    RepSyncPrimaryButton(title: "Workouts", fill: RepSyncTheme.card) {
                        appModel.showWorkouts()
                    }

                    Button {
                        appModel.showQuickWorkout()
                    } label: {
                        Text("Quick Go")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen.opacity(0.58), shape: .roundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 16)
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .overlay {
            if showsMonthPicker {
                RepSyncCenteredOverlay(maxWidth: 390, onDismiss: { showsMonthPicker = false }) {
                    monthPickerOverlay
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: showsMonthPicker)
    }

    private var monthPickerOverlay: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose Month")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text(DateFormatter.repsyncMonthYear.string(from: selectedMonth))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.primaryGreen)
                }

                Spacer()
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("Month")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                    Text("Year")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 12) {
                    Picker(
                        "Month",
                        selection: Binding(
                            get: { Calendar.repsync.component(.month, from: selectedMonth) },
                            set: { updateSelectedMonth(month: $0) }
                        )
                    ) {
                        ForEach(1...12, id: \.self) { month in
                            Text(monthSymbols[month - 1]).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker(
                        "Year",
                        selection: Binding(
                            get: { Calendar.repsync.component(.year, from: selectedMonth) },
                            set: { updateSelectedMonth(year: $0) }
                        )
                    ) {
                        ForEach(selectableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 150)
            }
            .padding(12)
            .background(RepSyncTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
            )

            Button {
                appModel.selectMonth(containing: selectedMonth)
                showsMonthPicker = false
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func calendarDayFill(_ day: CalendarDayModel) -> Color {
        if day.hasWorkout {
            return RepSyncTheme.primaryGreen.opacity(0.58)
        }
        return day.isInCurrentMonth ? RepSyncTheme.cardElevated.opacity(0.78) : RepSyncTheme.cardElevated.opacity(0.28)
    }

    private func calendarDayBorder(_ day: CalendarDayModel) -> Color {
        day.hasWorkout ? RepSyncTheme.primaryGreen.opacity(0.35) : RepSyncTheme.divider.opacity(day.isInCurrentMonth ? 0.42 : 0.16)
    }

    private func calendarDayTextColor(_ day: CalendarDayModel) -> Color {
        if day.hasWorkout {
            return RepSyncTheme.textPrimary
        }
        return day.isInCurrentMonth ? RepSyncTheme.textPrimary : RepSyncTheme.textSecondary.opacity(0.45)
    }

    private var selectableYears: [Int] {
        let currentYear = Calendar.repsync.component(.year, from: Date())
        return Array((currentYear - 20)...(currentYear + 5))
    }

    private func updateSelectedMonth(month: Int? = nil, year: Int? = nil) {
        let currentMonth = Calendar.repsync.component(.month, from: selectedMonth)
        let currentYear = Calendar.repsync.component(.year, from: selectedMonth)
        let components = DateComponents(
            year: year ?? currentYear,
            month: month ?? currentMonth,
            day: 1
        )

        if let date = Calendar.repsync.date(from: components) {
            selectedMonth = date
        }
    }
}

private enum LeaderboardStandingsScope: String, CaseIterable, Identifiable {
    case global = "Global"
    case friends = "Friends"

    var id: String { rawValue }
}

private struct LeaderboardStandingRow: Identifiable {
    let id = UUID()
    let placement: Int
    let username: String
    let rank: StrengthRankLevel
    let level: Int
    let isCurrentUser: Bool
}

struct LeaderboardScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var selectedLeaderboardScope = LeaderboardStandingsScope.global
    @State private var showsLeaderboardUsernameSheet = false
    @State private var leaderboardUsernameDraft = ""
    @State private var showsAddFriendSheet = false
    @State private var friendUsernameDraft = ""
    @State private var showsFriendRequestsSheet = false

    private let leaderboardAccent = RepSyncTheme.primaryGreenDark
    private var leaderboardDisplayName: String {
        appModel.leaderboardUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "You" : appModel.leaderboardUsername
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                RepSyncCard {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Leaderboard")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                            Text(appModel.leaderboardState.classSummary)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                                .allowsTightening(true)

                            Button {
                                leaderboardUsernameDraft = appModel.leaderboardUsername
                                showsLeaderboardUsernameSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "at")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(leaderboardDisplayName)
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)

                        HStack(spacing: 8) {
                            liftingRankMetric
                            levelMetric
                        }

                        leaderboardStandingsCard
                    }
                }

                Button {
                    appModel.showRankedMovements()
                } label: {
                    RepSyncCard {
                        HStack(spacing: 12) {
                            Image(systemName: "scope")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(leaderboardAccent)
                                .frame(width: 36, height: 36)
                                .background(leaderboardAccent.opacity(0.14))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Ranked Movements")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                Text("\(StrengthMovementCategory.allCases.count) categories from \(CanonicalLift.allCases.count) standardized exercises")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(leaderboardAccent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .onAppear {
            if appModel.leaderboardUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                leaderboardUsernameDraft = ""
                showsLeaderboardUsernameSheet = true
            }
        }
        .overlay {
            if showsLeaderboardUsernameSheet {
                RepSyncCenteredOverlay(
                    onDismiss: {
                        if !appModel.leaderboardUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            showsLeaderboardUsernameSheet = false
                        }
                    }
                ) {
                    leaderboardUsernameOverlay
                }
            }

            if showsAddFriendSheet {
                RepSyncCenteredOverlay(onDismiss: { showsAddFriendSheet = false }) {
                    addFriendOverlay
                }
            }

            if showsFriendRequestsSheet {
                RepSyncCenteredOverlay(onDismiss: { showsFriendRequestsSheet = false }) {
                    friendRequestsOverlay
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: showsLeaderboardUsernameSheet)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: showsAddFriendSheet)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: showsFriendRequestsSheet)
    }

    private var liftingRankMetric: some View {
        let rank = appModel.leaderboardState.overallRank

        return HStack(spacing: 10) {
            Image(systemName: rankIconName(for: rank))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(width: 34, height: 34)
                .repsyncGlassButtonBackground(rank != .unranked ? leaderboardAccent.opacity(0.58) : RepSyncTheme.cardElevated, shape: .circle)

            VStack(alignment: .leading, spacing: 5) {
                Text("Rank")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .lineLimit(1)
                Text(rank.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(rank != .unranked ? leaderboardAccent : RepSyncTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 62)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(appModel.leaderboardState.overallRank != .unranked ? leaderboardAccent.opacity(0.28) : RepSyncTheme.divider.opacity(0.24), lineWidth: 1)
        )
    }

    private var levelMetric: some View {
        let progress = appModel.leaderboardState.xpProgress

        return HStack(spacing: 10) {
            Image(systemName: progress.iconName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(width: 34, height: 34)
                .repsyncGlassButtonBackground(leaderboardAccent.opacity(0.58), shape: .circle)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(progress.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("\(progress.totalXP) XP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(RepSyncTheme.background.opacity(0.72))
                        Capsule()
                            .fill(leaderboardAccent.opacity(0.74))
                            .frame(width: max(proxy.size.width * progress.progress, 6))
                    }
                }
                .frame(height: 7)

                Text(progress.level >= 100 ? "Max level" : progress.xpSummary)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 62)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(leaderboardAccent.opacity(0.28), lineWidth: 1)
        )
    }

    private var leaderboardStandingsCard: some View {
        let rows = Array(standingsRows(for: selectedLeaderboardScope).prefix(15))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(LeaderboardStandingsScope.allCases) { scope in
                    Button {
                        selectedLeaderboardScope = scope
                    } label: {
                        Text(scope.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .repsyncGlassButtonBackground(selectedLeaderboardScope == scope ? leaderboardAccent.opacity(0.58) : RepSyncTheme.card, shape: .roundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selectedLeaderboardScope == scope ? leaderboardAccent.opacity(0.35) : RepSyncTheme.divider.opacity(0.24), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    friendUsernameDraft = ""
                    showsAddFriendSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(width: 34, height: 34)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .repsyncGlassButtonBackground(RepSyncTheme.card, shape: .roundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(RepSyncTheme.divider.opacity(0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Friend")

                Button {
                    showsFriendRequestsSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: appModel.incomingFriendRequests.isEmpty ? "tray" : "tray.full")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)

                        if !appModel.incomingFriendRequests.isEmpty {
                            Text("\(appModel.incomingFriendRequests.count)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(width: 14, height: 14)
                                .background(RepSyncTheme.primaryGreen)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .repsyncGlassButtonBackground(appModel.incomingFriendRequests.isEmpty ? RepSyncTheme.card : leaderboardAccent.opacity(0.42), shape: .roundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(appModel.incomingFriendRequests.isEmpty ? RepSyncTheme.divider.opacity(0.24) : leaderboardAccent.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Friend Requests")
            }

            if rows.count > 6 {
                ScrollView {
                    leaderboardChart(rows: rows)
                }
                .frame(height: 268)
            } else {
                leaderboardChart(rows: rows)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RepSyncTheme.divider.opacity(0.24), lineWidth: 1)
        )
    }

    private func leaderboardChart(rows: [LeaderboardStandingRow]) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("Place")
                    .frame(width: 52, alignment: .leading)
                Text("Username")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Rank")
                    .frame(width: 74, alignment: .leading)
                Text("Level")
                    .frame(width: 52, alignment: .leading)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(RepSyncTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.top, 2)

            ForEach(rows) { row in
                standingsRow(row)
            }
        }
    }

    private func standingsRow(_ row: LeaderboardStandingRow) -> some View {
        HStack(spacing: 8) {
            placementLabel(for: row)
                .frame(width: 52, alignment: .leading)

            Text(row.username)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.rank.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(row.rank == .unranked ? RepSyncTheme.textSecondary : leaderboardAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(width: 74, alignment: .leading)

            Text("Lv \(row.level)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .lineLimit(1)
                .frame(width: 52, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(row.isCurrentUser ? leaderboardAccent.opacity(0.14) : RepSyncTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(row.isCurrentUser ? leaderboardAccent.opacity(0.35) : RepSyncTheme.divider.opacity(0.18), lineWidth: 1)
        )
    }

    private func placementLabel(for row: LeaderboardStandingRow) -> some View {
        HStack(spacing: 4) {
            Text("#\(row.placement)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(row.isCurrentUser ? leaderboardAccent : RepSyncTheme.textSecondary)

            if let iconName = placementIconName(for: row.placement) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(placementIconColor(for: row.placement))
            }
        }
    }

    private func placementIconName(for placement: Int) -> String? {
        placement == 1 ? "crown.fill" : nil
    }

    private func placementIconColor(for placement: Int) -> Color {
        placement == 1 ? RepSyncTheme.warningOrange : RepSyncTheme.textSecondary
    }

    private func standingsRows(for scope: LeaderboardStandingsScope) -> [LeaderboardStandingRow] {
        let userRow = LeaderboardStandingRow(
            placement: 0,
            username: leaderboardDisplayName,
            rank: appModel.leaderboardState.overallRank,
            level: appModel.leaderboardState.xpProgress.level,
            isCurrentUser: true
        )
        let rows: [LeaderboardStandingRow]

        switch scope {
        case .global:
            rows = [
                LeaderboardStandingRow(placement: 0, username: "ironatlas", rank: .advanced, level: max(userRow.level + 8, 18), isCurrentUser: false),
                LeaderboardStandingRow(placement: 0, username: "tempoqueen", rank: .intermediate, level: max(userRow.level + 3, 12), isCurrentUser: false),
                userRow,
                LeaderboardStandingRow(placement: 0, username: "platesetter", rank: .novice, level: max(userRow.level - 2, 1), isCurrentUser: false),
                LeaderboardStandingRow(placement: 0, username: "repforge", rank: .novice, level: max(userRow.level - 4, 1), isCurrentUser: false),
                LeaderboardStandingRow(placement: 0, username: "barpath", rank: .intermediate, level: max(userRow.level + 1, 10), isCurrentUser: false),
                LeaderboardStandingRow(placement: 0, username: "lockout", rank: .novice, level: max(userRow.level - 3, 1), isCurrentUser: false),
                LeaderboardStandingRow(placement: 0, username: "hypertrophy", rank: .advanced, level: max(userRow.level + 6, 16), isCurrentUser: false),
                LeaderboardStandingRow(placement: 0, username: "setsandreps", rank: .untrained, level: max(userRow.level - 6, 1), isCurrentUser: false),
                LeaderboardStandingRow(placement: 0, username: "chalkline", rank: .intermediate, level: max(userRow.level + 4, 14), isCurrentUser: false)
            ]
        case .friends:
            let friendRows = appModel.leaderboardFriends.map { friendStandingRow(username: $0, userLevel: userRow.level) }
            rows = friendRows + [userRow]
        }

        return rows
            .sorted { lhs, rhs in
                if lhs.level == rhs.level {
                    return lhs.rank.score > rhs.rank.score
                }
                return lhs.level > rhs.level
            }
            .enumerated()
            .map { index, row in
                LeaderboardStandingRow(
                    placement: index + 1,
                    username: row.username,
                    rank: row.rank,
                    level: row.level,
                    isCurrentUser: row.isCurrentUser
                )
            }
    }

    private func friendStandingRow(username: String, userLevel: Int) -> LeaderboardStandingRow {
        let score = username.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let rankOptions: [StrengthRankLevel] = [.untrained, .novice, .intermediate, .advanced]
        let rank = rankOptions[score % rankOptions.count]
        let levelDelta = (score % 11) - 5

        return LeaderboardStandingRow(
            placement: 0,
            username: username,
            rank: rank,
            level: max(1, userLevel + levelDelta),
            isCurrentUser: false
        )
    }

    private var addFriendOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Friend")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)

            Text("Send a request by leaderboard username.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RepSyncTheme.textSecondary)

            TextField("username", text: $friendUsernameDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(RepSyncTheme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(RepSyncTheme.input)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
                )

            Button {
                appModel.sendLeaderboardFriendRequest(to: friendUsernameDraft)
                if !friendUsernameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    friendUsernameDraft = ""
                    showsAddFriendSheet = false
                }
            } label: {
                Text("Send Request")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if !appModel.sentFriendRequests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textSecondary)

                    ForEach(appModel.sentFriendRequests, id: \.self) { username in
                        HStack(spacing: 10) {
                            Text(username)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                appModel.cancelLeaderboardFriendRequest(to: username)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                    .frame(width: 28, height: 28)
                                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .circle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Cancel friend request to \(username)")
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(RepSyncTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private var friendRequestsOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Friend Requests")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)

            if appModel.incomingFriendRequests.isEmpty {
                Text("No incoming requests.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RepSyncTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RepSyncTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ForEach(appModel.incomingFriendRequests, id: \.self) { username in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(username)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                            Text("Wants to compare leaderboard progress")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            appModel.declineLeaderboardFriendRequest(from: username)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(width: 34, height: 34)
                                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .circle)
                        }
                        .buttonStyle(.plain)

                        Button {
                            appModel.acceptLeaderboardFriendRequest(from: username)
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(width: 34, height: 34)
                                .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen.opacity(0.58), shape: .circle)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(RepSyncTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var leaderboardUsernameOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Leaderboard Username")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)

            Text("This is the name shown in future global and friend leaderboard rankings.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RepSyncTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("username", text: $leaderboardUsernameDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(RepSyncTheme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(RepSyncTheme.input)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
                )

            Button {
                appModel.saveLeaderboardUsername(leaderboardUsernameDraft)
                if !leaderboardUsernameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    showsLeaderboardUsernameSheet = false
                }
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func rankIconName(for rank: StrengthRankLevel) -> String {
        switch rank {
        case .unranked: return "questionmark"
        case .untrained: return "figure.walk"
        case .novice: return "leaf.fill"
        case .intermediate: return "bolt.fill"
        case .advanced: return "flame.fill"
        case .elite: return "trophy.fill"
        }
    }

    @ViewBuilder
    private func rankPill(_ rank: StrengthRankLevel) -> some View {
        if rank == .unranked {
            Text(rank.rawValue)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RepSyncTheme.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RepSyncTheme.cardElevated)
                .clipShape(Capsule())
        } else {
            RepSyncSelectedChip(title: rank.rawValue, height: 30)
        }
    }

    private func rows(in section: LeaderboardLiftSection) -> [LeaderboardLiftRow] {
        appModel.leaderboardState.rows.filter { $0.category.leaderboardSection == section }
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                        Text(sectionSummary(for: rows))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                    }

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
                        .foregroundStyle(leaderboardAccent)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(RepSyncTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                if rows.isEmpty {
                    RepSyncCard {
                        emptyLeaderboardMessage("No ranked movements in this section.")
                    }
                } else {
                    ForEach(rows) { row in
                        leaderboardLiftCard(row)
                    }
                }
            }
        }
    }

    private func sectionSummary(for rows: [LeaderboardLiftRow]) -> String {
        let ranked = rows.filter { $0.rank != .unranked }.count
        return ranked == 0 ? "No ranked lifts yet" : "\(ranked) ranked"
    }

    private func trackedLiftToggle(_ lift: CanonicalLift) -> some View {
        let isTracked = appModel.trackedLeaderboardLifts.contains(lift)

        return Button {
            appModel.toggleLeaderboardLift(lift)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isTracked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isTracked ? leaderboardAccent : RepSyncTheme.textSecondary)

                Text(lift.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(isTracked ? leaderboardAccent.opacity(0.22) : RepSyncTheme.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isTracked ? leaderboardAccent.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func leaderboardLiftCard(_ row: LeaderboardLiftRow) -> some View {
        RepSyncCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.category.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .lineLimit(1)

                        if let sourceExerciseName = row.sourceExerciseName {
                            Text("Best from \(sourceExerciseName)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    rankPill(row.rank)
                }

                HStack(spacing: 10) {
                    liftMetric(title: "Best", value: row.bestSetText)
                    liftMetric(title: "Est. 1RM", value: row.estimatedOneRepMaxText)
                }

                Text(row.contributingExercisesText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RepSyncTheme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let nextRankText = row.nextRankText {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(leaderboardAccent)
                            .padding(.top, 2)
                        Text(nextRankText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RepSyncTheme.cardElevated.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
                    )
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
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
        )
    }

    private func emptyLeaderboardMessage(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textSecondary)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RepSyncTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RankedMovementsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: RepSyncAppModel

    private let accent = RepSyncTheme.primaryGreenDark

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerCard

                ForEach(LeaderboardLiftSection.allCases) { section in
                    movementSection(section)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private var headerCard: some View {
        RepSyncCard {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(width: 42, height: 42)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ranked Movements")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text("\(StrengthMovementCategory.allCases.count) strength categories from \(CanonicalLift.allCases.count) standardized exercises")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func movementSection(_ section: LeaderboardLiftSection) -> some View {
        let rows = appModel.leaderboardState.rows.filter { $0.category.leaderboardSection == section }

        return RepSyncCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text(sectionSubtitle(for: section))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        movementRow(row)
                    }
                }
            }
        }
    }

    private func movementRow(_ row: LeaderboardLiftRow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName(for: row.category))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(width: 34, height: 34)
                    .repsyncGlassButtonBackground(accent.opacity(0.45), shape: .circle)

                VStack(alignment: .leading, spacing: 3) {
                    Text(row.category.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text(row.contributingExercisesText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                rankPill(row.rank)
            }

            if let sourceExerciseName = row.sourceExerciseName {
                HStack(spacing: 8) {
                    liftMetric(title: "Best From", value: sourceExerciseName)
                    liftMetric(title: "Est. 1RM", value: row.estimatedOneRepMaxText)
                }
            } else if let nextRankText = row.nextRankText {
                Text(nextRankText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RepSyncTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 42)
                    .background(RepSyncTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(RepSyncTheme.divider.opacity(0.22), lineWidth: 1)
                    )
            }
        }
        .padding(12)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RepSyncTheme.divider.opacity(0.24), lineWidth: 1)
        )
    }

    private func sectionSubtitle(for section: LeaderboardLiftSection) -> String {
        switch section {
        case .upperBody:
            return "Pressing and pulling patterns"
        case .lowerBody:
            return "Squat, hinge, and leg patterns"
        case .accessories:
            return "Arms, calves, and core work"
        }
    }

    @ViewBuilder
    private func rankPill(_ rank: StrengthRankLevel) -> some View {
        if rank == .unranked {
            Text(rank.rawValue)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RepSyncTheme.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RepSyncTheme.cardElevated)
                .clipShape(Capsule())
        } else {
            RepSyncSelectedChip(title: rank.rawValue, height: 30)
        }
    }

    private func liftMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RepSyncTheme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .frame(height: 50)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func iconName(for category: StrengthMovementCategory) -> String {
        switch category {
        case .horizontalPress, .verticalPress:
            return "arrow.up.forward"
        case .horizontalPull, .verticalPull:
            return "arrow.down.backward"
        case .squat, .kneeExtension:
            return "figure.strengthtraining.traditional"
        case .hinge, .hipExtension:
            return "figure.strengthtraining.functional"
        case .kneeFlexion, .armFlexion, .armExtension:
            return "dumbbell.fill"
        case .calvesCore:
            return "circle.hexagongrid.fill"
        }
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
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))

                Button("Connect") {
                    appModel.showMusicProviderPicker()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 10))
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
                .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 10))

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
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
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
                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
                }

                Button("Change Provider") {
                    appModel.showMusicProviderPicker()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
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
                .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 10))

                Button("Next") {
                    appModel.skipAppleMusicTrack()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))

                Button("Open") {
                    appModel.openAppleMusicApp()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
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
                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
                }

                Button(appModel.isRefreshingAppleMusic ? "Refreshing..." : "Refresh Library") {
                    appModel.refreshAppleMusicConnection()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
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
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))

                Button("Change Provider") {
                    appModel.showMusicProviderPicker()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
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
                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
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
                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))

                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
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
                                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
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
