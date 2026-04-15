# AGENTS.md

## Purpose

RepSync is an offline-first Android workout tracker. Agents working in this repo should optimize for fast logging, simple flows, and safe local data changes. Keep the app local-only unless a task explicitly asks for sync, accounts, cloud storage, analytics, or network-backed features.

## Product Guardrails

- Android only for current scope.
- Offline-first and guest-first.
- Local data is the source of truth.
- No required sign-in, backend, or cloud dependency unless explicitly requested.
- Preserve the current dark, compact, gym-focused UI style.
- Prefer practical, low-abstraction solutions over architectural rewrites.

## Tech Stack

- Kotlin 2.1
- Android Gradle Plugin 8.7.3
- JDK 17
- Single app module: `app`
- Jetpack Compose + Material 3
- Navigation Compose
- Room + SQLite for persistent app data
- DataStore for lightweight preferences
- Coil for images/GIFs
- Foreground service support for the rest timer

## Repo Map

- `app/src/main/java/com/repsync/app/MainActivity.kt`
  Activity shell, scaffold, bottom nav, active-workout banner, app entrypoint.
- `app/src/main/java/com/repsync/app/navigation/`
  Route definitions in `Screen.kt` and graph wiring in `RepSyncNavHost.kt`.
- `app/src/main/java/com/repsync/app/data/`
  Database, DataStore preferences, DAOs, entities, converters.
- `app/src/main/java/com/repsync/app/ui/screens/`
  Compose screens.
- `app/src/main/java/com/repsync/app/ui/viewmodel/`
  `AndroidViewModel` classes with `StateFlow`-backed UI state.
- `app/src/main/java/com/repsync/app/ui/components/`
  Shared Compose building blocks.
- `app/src/main/java/com/repsync/app/ui/theme/`
  Dark theme tokens and Material theme setup.
- `app/src/main/java/com/repsync/app/service/`
  Long-running workout service logic such as the rest timer.
- `app/src/main/java/com/repsync/app/notification/`
  Reminder receivers and scheduling helpers.
- `2.24plan.md` and `2.24prompts.md`
  Current dated implementation planning docs for the Android app.
- `docs/plan-web.md` and `docs/prompts-web.md`
  Separate web-oriented docs.

## Important Context

- `README.md` references `docs/plan.md` and `docs/prompts.md`, but those exact files are not present. Treat the dated root docs (`2.24plan.md`, `2.24prompts.md`) and the current source code as the primary references.
- The repo currently has no `app/src/test` or `app/src/androidTest` directories. If a task introduces meaningful logic, add tests when it is practical; otherwise provide clear manual verification steps.
- Do not edit generated files under `build/`.

## Architecture Conventions

- Keep features vertical. A typical feature touches:
  - entities/DAOs/database migration when data changes
  - a ViewModel with immutable UI state
  - one or more Compose screens/components
  - navigation routes if a new destination is added
- Most screen state lives in `AndroidViewModel` classes using `MutableStateFlow` and immutable data classes.
- Database access is currently manual via `RepSyncDatabase.getDatabase(application)` inside ViewModels. Do not introduce DI frameworks unless explicitly requested.
- `ActiveWorkoutManager` is activity-scoped and intentionally persists active workout state across navigation.
- Reuse existing theme tokens from `ui/theme/Color.kt` and `ui/theme/Theme.kt` rather than hardcoding new colors in screens.
- Keep reusable UI in `ui/components`; keep screen-specific layout logic in `ui/screens`.

## Data Rules

- Room schema changes must be additive and safe for existing users.
- If you change a Room entity or table shape:
  - bump the database version in `RepSyncDatabase`
  - add a real migration
  - preserve existing local data
- Never solve schema changes with destructive resets unless the task explicitly allows data loss.
- Respect existing ordering fields such as `orderIndex` for workouts, exercises, and sets.
- If a feature only needs lightweight preferences, prefer the existing DataStore pattern in `data/*Preferences.kt` instead of new tables.

## Navigation Rules

- Add or change routes in `navigation/Screen.kt`.
- Wire destinations in `navigation/RepSyncNavHost.kt`.
- Pass navigation lambdas from parent composables instead of navigating deep inside leaf components.
- When adding a screen, inspect a nearby existing screen first and match its structure.

## UI Rules

- Preserve the current dark Material 3 look and feel.
- Reuse `BackgroundCard`, `PrimaryGreen`, `TextOnDark`, and related tokens before inventing new styling.
- Favor clear, touch-friendly layouts for fast workout logging.
- Avoid introducing flashy animations or visual redesigns unless the task is explicitly design-focused.

## Working Style For Agents

1. Read the relevant screen, ViewModel, DAO/entity, and navigation files before editing.
2. Copy existing patterns from neighboring files instead of inventing a new architecture.
3. Make the smallest coherent change that fully delivers the feature.
4. If the feature crosses layers, finish the full path instead of stopping at partial wiring.
5. When requirements are ambiguous, make reasonable assumptions that preserve offline-first behavior and existing UX.

## Verification

- Preferred build check: `./gradlew assembleDebug`
- If you change persistence, manually test creation, editing, app restart behavior, and migration safety when possible.
- If you change navigation, manually exercise the full route flow.
- If you change workout execution, manually test active workout, finish/cancel, and rest timer behavior.
- If you cannot run a check, say so clearly in the final handoff.

## Done Checklist

- Code matches existing package and naming patterns.
- New routes are wired end-to-end.
- Database changes include a migration when needed.
- Styling uses existing theme tokens.
- Build or manual verification was attempted.
- Final handoff includes assumptions, verification, and any remaining risk.
