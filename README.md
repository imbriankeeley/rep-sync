# RepSync

A simple, **offline-first** Android workout app. Log workouts, build templates, track progress—all on your device. No account required.

## Features

- **Guest-first** — Use the app immediately; optional local profile (name, avatar) only.
- **Workout templates** — Create and save workouts with exercises and sets; start from a template anytime.
- **Quick Workout** — Add exercises on the fly without a template.
- **Calendar** — Month view with completed workouts; tap a day to see details, copy workouts to other days, or save a day's workout as a template.
- **Progress** — "Previous" weight/reps per exercise from your history.
- **Local only** — All data stays on your device (Room/SQLite). No cloud, no sign-in in v1.

## Requirements

- **Android** only (no iOS in initial scope).
- Min SDK 26; target SDK 35.
- **Architecture:** Kotlin, Jetpack Compose, single-activity, MVVM.

## Building the App

### Prerequisites

- [Android Studio](https://developer.android.com/studio) (or the Android SDK + command-line tools).
- JDK 17+.

### Build Commands

**Debug (development):**
```bash
./gradlew assembleDebug
```
Output: `app/build/outputs/apk/debug/app-debug.apk`

**Release (unsigned):**
```bash
./gradlew assembleRelease
```
Output: `app/build/outputs/apk/release/app-release-unsigned.apk`

**Release (signed, local only — see [Signing for Release](#signing-for-release) below):**
```bash
./gradlew assembleRelease
```
Output: `app/build/outputs/apk/release/app-release.apk`

**Debug APK (GitHub Releases / CI):**
```bash
./gradlew assembleDebug
```
Output: `app/build/outputs/apk/debug/app-debug.apk`

### Run on a Device

Install the debug APK directly:
```bash
./gradlew installDebug
```
Or open the project in Android Studio and run on an emulator or connected device.

## Signing for Release

To produce a signed APK suitable for distribution you need a Java keystore. **Never commit your keystore or passwords to the repo.**

### 1. Generate a Keystore (one-time)

```bash
keytool -genkeypair -v \
  -keystore repsync-release.jks \
  -alias repsync \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```

Store the `.jks` file somewhere safe outside the repo.

### 2. Configure Signing Properties

Create (or edit) `~/.gradle/gradle.properties` and add:

```properties
REPSYNC_KEYSTORE_FILE=/absolute/path/to/repsync-release.jks
REPSYNC_KEYSTORE_PASSWORD=your_store_password
REPSYNC_KEY_ALIAS=repsync
REPSYNC_KEY_PASSWORD=your_key_password
```

The `app/build.gradle.kts` already reads these properties. When they are set, `assembleRelease` produces a signed APK. When they are absent, the build falls back to an unsigned APK.

### 3. Build the Signed APK

```bash
./gradlew assembleRelease
```

The signed APK is at:
```
app/build/outputs/apk/release/app-release.apk
```

> **Note:** GitHub release automation in this repo publishes the debug APK and does not require signing secrets.

## Distribution via Obtainium

[Obtainium](https://github.com/ImranR98/Obtainium) installs and updates Android apps directly from GitHub Releases—no app store required.

### For Users

1. Install [Obtainium](https://github.com/ImranR98/Obtainium) on your Android device.
2. Open Obtainium and tap **Add App**.
3. Enter this repo's URL as the source (e.g. `https://github.com/<user>/RepSync`).
4. Obtainium will find the latest GitHub Release and its APK asset.
5. Install (and later update) from there.

### For Maintainers — Publishing a Release

1. Bump `versionCode` and `versionName` in `app/build.gradle.kts`.
2. Push your changes to GitHub.
3. Create and push a tag matching the version, for example `v1.0.5`.
4. GitHub Actions will build `app/build/outputs/apk/debug/app-debug.apk` and publish it to a GitHub Release for that tag.
5. Confirm the release contains the debug APK asset. Obtainium users who added this repo will see the update.

## Repo Structure

```
RepSync/
├── docs/
│   └── plan.md              # Full product and technical plan
├── prompts.md                # Phased prompts for implementation
├── assets/
│   ├── repSyncLogo.png      # App logo
│   └── references/          # Design reference screens (do not delete)
│       └── IMG_1505.PNG … IMG_1538.PNG
├── app/                      # Android app module
│   ├── src/main/
│   │   ├── java/com/repsync/app/   # Kotlin source
│   │   ├── res/                     # Resources (drawables, values, themes)
│   │   └── AndroidManifest.xml
│   └── build.gradle.kts
├── build.gradle.kts          # Root build file
└── settings.gradle.kts
```

- **Spec:** See [docs/plan.md](docs/plan.md) for the single source of truth (flows, data model, UI, distribution).
- **Implementation guide:** See [prompts.md](docs/prompts.md) for step-by-step prompts keyed to the plan.

## License

See [LICENSE](LICENSE) in this repo, if present.
