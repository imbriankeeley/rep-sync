import SwiftUI
import UIKit

struct RepSyncCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder var content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RepSyncTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct RepSyncHeaderButton: View {
    let title: String
    var background: Color = RepSyncTheme.cardElevated
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(width: 40, height: 40)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct RepSyncPrimaryButton: View {
    let title: String
    var fill: Color = RepSyncTheme.primaryGreen
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct RepSyncBottomNavBar: View {
    @Binding var selectedTab: RepSyncTab

    var body: some View {
        HStack(spacing: 16) {
            ForEach(RepSyncTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundStyle(selectedTab == tab ? RepSyncTheme.textPrimary : RepSyncTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedTab == tab ? RepSyncTheme.cardElevated : RepSyncTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RepSyncActiveWorkoutBanner: View {
    let model: ActiveWorkoutBannerModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(model.workoutName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(model.elapsedText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RepSyncTheme.primaryGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

struct RepSyncProfileAvatar: View {
    var size: CGFloat
    var imagePath: String? = nil

    var body: some View {
        ZStack {
            Circle().fill(RepSyncTheme.cardLight)
            if let imagePath,
               let image = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(RepSyncTheme.textOnLightSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct RepSyncExerciseTypeBadge: View {
    let trackingType: ExerciseTrackingKind

    var body: some View {
        Text(trackingType.displayName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(RepSyncTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RepSyncTheme.cardElevated)
            .clipShape(Capsule())
    }
}

struct RepSyncSuggestionList: View {
    let suggestions: [ExerciseSuggestion]
    let action: (ExerciseSuggestion) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(suggestions) { suggestion in
                Button {
                    action(suggestion)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(suggestion.trackingType.displayName)
                                .font(.system(size: 12))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RepSyncTheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RepSyncStreakBadge: View {
    let streak: Int

    var body: some View {
        if streak > 0 {
            HStack(spacing: 8) {
                Text("🔥")
                    .font(.system(size: 24))
                Text(streak == 1 ? "1 Day Streak" : "\(streak) Day Streak")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RepSyncTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct RepSyncLineChart: View {
    let points: [ChartPoint]
    let label: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(RepSyncTheme.cardElevated)

                if points.count < 2 {
                    Text("No data yet")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                } else {
                    let values = points.map(\.value)
                    let minValue = values.min() ?? 0
                    let maxValue = values.max() ?? 1
                    let range = max(maxValue - minValue, 1)

                    Path { path in
                        for (index, point) in points.enumerated() {
                            let x = geometry.size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                            let normalizedY = (point.value - minValue) / range
                            let y = geometry.size.height - CGFloat(normalizedY) * (geometry.size.height - 24) - 12
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(RepSyncTheme.primaryGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        let x = geometry.size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                        let normalizedY = (point.value - minValue) / range
                        let y = geometry.size.height - CGFloat(normalizedY) * (geometry.size.height - 24) - 12
                        Circle()
                            .fill(RepSyncTheme.primaryGreen)
                            .frame(width: 10, height: 10)
                            .position(x: x, y: y)
                    }

                    VStack {
                        HStack {
                            Text("\(Int(maxValue)) \(label)")
                                .font(.system(size: 12))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Text("\(Int(minValue)) \(label)")
                                .font(.system(size: 12))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                            Spacer()
                        }
                    }
                    .padding(12)
                }
            }
        }
    }
}

struct RepSyncField: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(RepSyncTheme.textSecondary)
            Text(value)
                .foregroundStyle(RepSyncTheme.textPrimary)
            Spacer()
        }
        .font(.system(size: 16))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RepSyncTheme.input)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct MotivationalCard: View {
    private let gifURLs = [
        URL(string: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExMHNqeXd3am00MzV1aDltaHlxNXk0enk5dWpsdW52cXZ5MmQ1cXdibSZlcD12MV9naWZzX3NlYXJjaCZjdD1n/fqrXU5bfnbQg9bCAKI/giphy.gif"),
        URL(string: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExcTBjYmRsdmMyY2xic2traTJwZ2Nub20ydGdtc2RsdndhbzE5bGRwMCZlcD12MV9naWZzX3NlYXJjaCZjdD1n/rzHpW6vWZX3ghRP2Cc/giphy.gif"),
        URL(string: "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExZHE0eGFnODhkdDV0amRkejNlMnZ2amxqYzNqazNiczhxOWdkeWdxZiZlcD12MV9naWZzX3NlYXJjaCZjdD1n/12bF3AWU423YeA/giphy.gif"),
    ].compactMap { $0 }

    var body: some View {
        let url = gifURLs.first
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RepSyncTheme.card)
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .padding(8)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    default:
                        VStack(spacing: 8) {
                            Text("✨💪")
                                .font(.system(size: 48))
                            Text("Connect to internet for daily GIFs!")
                                .font(.system(size: 12))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
