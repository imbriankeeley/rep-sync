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
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
        )
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
                .repsyncGlassButtonBackground(background, shape: .roundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct RepSyncSaveButton: View {
    let action: () -> Void

    var body: some View {
        Button("Save", action: action)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(RepSyncTheme.textPrimary)
            .frame(width: 64, height: 40)
            .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 10))
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
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .repsyncGlassButtonBackground(fill, shape: .roundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct RepSyncCenteredOverlay<Content: View>: View {
    var maxWidth: CGFloat = 360
    var onDismiss: (() -> Void)?
    @ViewBuilder var content: Content

    init(maxWidth: CGFloat = 360, onDismiss: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss?()
                }

            content
                .padding(20)
                .frame(maxWidth: maxWidth)
                .background(RepSyncTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 18)
                .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(20)
    }
}

struct RepSyncSelectedChip: View {
    let title: String
    var height: CGFloat = 24

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(RepSyncTheme.textPrimary)
            .padding(.horizontal, 9)
            .frame(height: height)
            .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen.opacity(0.58), shape: .capsule)
            .overlay(
                Capsule()
                    .stroke(RepSyncTheme.primaryGreen.opacity(0.35), lineWidth: 1)
            )
    }
}

struct RepSyncGhostAddCard: View {
    let title: String
    var widthRatio: CGFloat = 0.75
    var textSize: CGFloat = 18
    var iconSize: CGFloat = 18
    var iconFrame: CGFloat = 34
    var height: CGFloat = 66
    let action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Button(action: action) {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)

                    Image(systemName: "plus")
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(RepSyncTheme.primaryGreen)
                        .frame(width: iconFrame, height: iconFrame)
                        .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen.opacity(0.58), shape: .circle)

                    Text(title)
                        .font(.system(size: textSize, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(RepSyncTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                        .foregroundStyle(RepSyncTheme.primaryGreen.opacity(0.42))
                )
                .frame(width: proxy.size.width * widthRatio)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(height: height)
    }
}

enum RepSyncGlassButtonShape {
    case capsule
    case circle
    case roundedRectangle(cornerRadius: CGFloat)
}

extension View {
    @ViewBuilder
    func repsyncGlassButtonBackground(_ fill: Color, shape: RepSyncGlassButtonShape = .capsule) -> some View {
        switch shape {
        case .capsule:
            if #available(iOS 26.0, *) {
                glassEffect(.regular.tint(fill.opacity(0.26)).interactive(), in: .capsule)
                    .contentShape(Capsule())
            } else {
                background(fill)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
        case .circle:
            if #available(iOS 26.0, *) {
                glassEffect(.regular.tint(fill.opacity(0.26)).interactive(), in: .circle)
                    .contentShape(Circle())
            } else {
                background(fill)
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
        case .roundedRectangle(let cornerRadius):
            if #available(iOS 26.0, *) {
                glassEffect(.regular.tint(fill.opacity(0.26)).interactive(), in: .rect(cornerRadius: cornerRadius))
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                background(fill)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
            .frame(maxWidth: .infinity)
            .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
               let image = profileAvatarImage(from: imagePath) {
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

    private func profileAvatarImage(from storedValue: String) -> UIImage? {
        let fileManager = FileManager.default
        let directURL = URL(fileURLWithPath: storedValue)

        if fileManager.fileExists(atPath: directURL.path),
           let image = UIImage(contentsOfFile: directURL.path) {
            return image
        }

        let filename = directURL.lastPathComponent
        guard !filename.isEmpty else {
            return nil
        }

        guard let directory = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("RepSync", isDirectory: true) else {
            return nil
        }

        let resolvedURL = directory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: resolvedURL.path) else { return nil }
        return UIImage(contentsOfFile: resolvedURL.path)
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
            .overlay(
                Capsule()
                    .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
            )
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RepSyncStreakBadge: View {
    let streak: Int
    let workoutCount: Int

    var body: some View {
        if streak > 0 {
            HStack(spacing: 10) {
                metricCard(
                    title: "Current Streak",
                    value: streak == 1 ? "1 Day" : "\(streak) Days",
                    icon: "flame.fill",
                    accent: RepSyncTheme.warningOrange
                )

                metricCard(
                    title: "Total Workouts",
                    value: "\(workoutCount)",
                    icon: "figure.strengthtraining.traditional",
                    accent: RepSyncTheme.primaryGreen
                )
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func metricCard(title: String, value: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textSecondary)

                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
            }
        }
        .padding(16)
        .background(RepSyncTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

struct RepSyncLineChart: View {
    let points: [ChartPoint]
    var trendPoints: [ChartPoint] = []
    let label: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(RepSyncTheme.cardElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
                    )

                if points.count < 2 {
                    Text("No data yet")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                } else {
                    let visibleTrendPoints = trendPoints.count >= 2 ? trendPoints : []
                    let values = points.map(\.value) + visibleTrendPoints.map(\.value)
                    let minValue = values.min() ?? 0
                    let maxValue = values.max() ?? 1
                    let range = max(maxValue - minValue, 1)

                    if visibleTrendPoints.count >= 2 {
                        Path { path in
                            for (index, point) in visibleTrendPoints.enumerated() {
                                let x = geometry.size.width * CGFloat(index) / CGFloat(max(visibleTrendPoints.count - 1, 1))
                                let normalizedY = (point.value - minValue) / range
                                let y = geometry.size.height - CGFloat(normalizedY) * (geometry.size.height - 24) - 12
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            RepSyncTheme.textPrimary.opacity(0.72),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                    }

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
                            if visibleTrendPoints.count >= 2 {
                                HStack(spacing: 5) {
                                    Capsule()
                                        .fill(RepSyncTheme.textPrimary.opacity(0.72))
                                        .frame(width: 16, height: 2)
                                    Text("Trend")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                }
                            }
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
