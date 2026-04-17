# RepSync

RepSync is a gym-focused workout tracker for **Android and iOS**. It is built for fast logging, reusable workout templates, and progress tracking without forcing accounts or bloated setup.

## Platform Model

- **Android**: offline-first and local-only. Workout data stays on the device with no cloud sync requirement.
- **iOS**: local-first with Core Data persistence and CloudKit-backed sync between devices when iCloud is available.

## Features

- **Workout templates**: build repeatable workout plans and start from them anytime.
- **Quick logging**: create a workout on the fly without extra setup.
- **History and progress**: review completed sessions and compare previous performance.
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
- CloudKit integration through `NSPersistentCloudKitContainer`

## Requirements

### Android

- Android Studio
- JDK 17+
- Min SDK 26

### iOS

- Xcode 16+ recommended
- iOS simulator or physical iPhone/iPad for local testing
- iCloud account enabled on device/simulator for CloudKit sync testing

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

For CloudKit/device-to-device persistence verification on iOS:

1. Sign into the same iCloud account on both devices.
2. Run the app with iCloud/CloudKit enabled.
3. Create or edit workout data on one device.
4. Confirm the change appears on the other device after sync completes.

## Data Behavior

- **Android** uses local storage only. Room and SQLite are the source of truth.
- **iOS** uses Core Data locally and can mirror data through CloudKit across devices.
- If CloudKit is unavailable on iOS, the app still uses local persistence on that device.

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
- The iOS app supports persistence between devices through CloudKit when available.
- Current source code and dated plan docs should be treated as the most accurate references for active development.

## License

See [LICENSE](LICENSE) if present.
