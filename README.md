# RepSync

RepSync is a gym-focused workout tracker for **Android and iOS**. It is built for fast logging, reusable workout templates, and progress tracking without forcing accounts or bloated setup.

## Platform Model

- **Android**: offline-first and local-only. Workout data stays on the device with no cloud sync requirement.
- **iOS**: local-first with Core Data persistence. The current iOS project is configured to run without iCloud or push entitlements so it can be installed with a personal Apple development team.

## Features

- **Workout templates**: build repeatable workout plans and start from them anytime.
- **Quick logging**: create a workout on the fly without extra setup.
- **Rest timer**: active workouts on iOS include a configurable rest timer with preset and custom durations.
- **History and progress**: review completed sessions and compare previous performance.
- **Workout audio hooks**: Apple Music playback controls are available on iOS, while Spotify and YouTube Music are currently URL/app-launch bridges.
- **Compact gym UI**: dark, practical screens optimized for logging during training.
- **Guest-friendly**: no required sign-in flow.

## Tech Stack

### Android

- Kotlin 2.1
- Android Gradle Plugin 8.7.3
- Jetpack Compose + Material 3
- Navigation Compose
- Room + SQLite
- DataStore

### iOS

- SwiftUI
- Core Data
- `NSPersistentCloudKitContainer` configured in local-only mode unless project capabilities are re-enabled

## Requirements

### Android

- Android Studio
- JDK 17+
- Min SDK 26

### iOS

- Xcode 16+ recommended
- iOS simulator or physical iPhone/iPad for local testing
- Physical iPhone recommended for Apple Music and device-only behavior such as haptics

## Building

### Android

Debug build:

```bash
./gradlew assembleDebug
```

Install to a connected device or emulator:

```bash
./gradlew installDebug
```

Release build:

```bash
./gradlew assembleRelease
```

Output paths:

- `app/build/outputs/apk/debug/app-debug.apk`
- `app/build/outputs/apk/release/app-release-unsigned.apk`

### iOS

Open the Xcode project:

```bash
open ios/RepSync/RepSync.xcodeproj
```

Then build and run the `RepSync` scheme in Xcode on a simulator or device.

For personal-team installs on iPhone:

1. Open `ios/RepSync/RepSync.xcodeproj` in Xcode.
2. Select your Apple development team in `Signing & Capabilities`.
3. Use a unique bundle identifier if Xcode asks for one.
4. Build and run on the connected device.

## Data Behavior

- **Android** uses local storage only. Room and SQLite are the source of truth.
- **iOS** currently uses Core Data locally.
- CloudKit can be wired back in later, but the checked-in iOS project is set up for local installs without paid-team entitlements.

## Distribution

### Android

Android releases can be distributed as APKs, including through GitHub Releases / Obtainium workflows already in this repo.

### iOS

iOS distribution is expected through standard Apple tooling such as local Xcode installs, TestFlight, or App Store delivery when configured.

## Repo Structure

```text
RepSync/
├── app/                      # Android app module
├── ios/RepSync/             # iOS app project
├── docs/
│   ├── RELEASE_NOTES.md
│   ├── plan-web.md
│   └── prompts-web.md
├── 2.24plan.md              # Android planning reference
├── 2.24prompts.md           # Android implementation prompts
├── plan.md                  # Current iOS planning reference
├── assets/
├── build.gradle.kts
└── settings.gradle.kts
```

## Notes

- The Android app remains intentionally offline-only.
- The iOS app currently targets local-first installs and testing.
- Current source code and dated plan docs should be treated as the most accurate references for active development.

## License

See [LICENSE](LICENSE) if present.
