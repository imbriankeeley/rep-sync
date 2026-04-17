# RepSync iPhone + CloudKit + App Store Plan

This document is the implementation plan for porting RepSync from its current Android-only, offline-first app into a native iPhone app that stays offline-first locally and uses iCloud/CloudKit for Apple-device persistence and restore.

This plan reflects the current product direction:

- Android remains offline-only
- iPhone is developed as a native app in the same repo
- The iPhone app uses local storage first
- iPhone users can keep their data across Apple devices through CloudKit
- No custom cross-platform backend is required for v1

## 1. Goals

Ship a high-quality iPhone app that:

- Matches the Android feature set closely enough to feel like the same product
- Preserves fast workout logging and offline usability
- Stores workout data locally first
- Syncs or restores data across Apple devices through iCloud/CloudKit
- Can be submitted, approved, and maintained successfully on the App Store

Secondary goals:

- Avoid backend complexity and hosting cost for v1
- Keep the iPhone architecture simple and maintainable for a first Apple release
- Preserve the option to add a custom backend later if the product direction changes

## 2. Product Principles

The iPhone port should follow these principles:

- Offline-first remains the core UX
- Fast local writes matter more than cloud immediacy
- iCloud sync is an enhancement, not a requirement for day-to-day usage
- The app should feel native on iPhone, not like a wrapped web app
- Android and iPhone may share product behavior, but they do not need to share cloud infrastructure
- Avoid introducing avoidable operational overhead in v1

## 3. Current State Summary

The Android app currently includes:

- Workout templates
- Quick workout flow
- Active workout tracking
- Completed workout history and calendar day views
- Exercise history
- Bodyweight logging
- Local profile editing
- Reminders
- Rest timer foreground-service behavior
- Room/SQLite persistence and DataStore preferences

The current repo architecture is Android-specific:

- Kotlin + Jetpack Compose
- Room DAOs/entities
- Android ViewModels with `StateFlow`
- Android navigation and service/notification APIs

That means the iPhone version should be treated as a native port, not as a new build target on the current Android codebase.

## 4. Recommended Technical Strategy

Recommendation: build a native iPhone app in SwiftUI with Core Data for local persistence and CloudKit for Apple-device sync/restore, while keeping the current Android app offline-only in Kotlin.

Why this is the recommended path:

- It gives iPhone users device-to-device persistence without building and operating a backend
- It fits the real goal: data survives a new iPhone or multiple Apple devices
- It preserves offline-first behavior because local storage remains primary
- It avoids rewriting the Android app
- It avoids the complexity of custom auth, sync infrastructure, and backend operations for v1

Alternatives considered:

1. Custom backend + accounts + cross-platform sync
   Pros: Android/iPhone could eventually share one account system.
   Cons: much higher complexity, cost, and time for a first iPhone launch.
2. Kotlin Multiplatform rewrite
   Pros: more shared logic long-term.
   Cons: large restructure before shipping iPhone value.
3. PWA-only iOS strategy
   Pros: faster initial iOS presence.
   Cons: weaker native UX, weaker App Store/distribution story, more platform limitations.

Decision:

- Near-term: native SwiftUI iPhone app + Core Data + CloudKit
- Android stays local/offline only
- Revisit a custom backend only if future product needs justify it

## 5. Scope Definition

### In scope for the iPhone launch

- Native iPhone app
- Feature parity with Android core flows
- Offline-first local persistence
- iCloud-backed persistence across Apple devices via CloudKit
- App Store listing, legal/compliance assets, and review-ready build
- Crash reporting and basic operational monitoring

### Out of scope for initial iPhone launch

- Android cloud sync
- Custom RepSync accounts
- Email/password auth
- Cross-platform shared backend
- iPad-optimized layouts
- Social features
- Apple Watch app
- Mandatory subscriptions or monetization

## 6. Target Experience

The shipped iPhone app should support this experience:

- User installs the app and starts logging immediately
- All changes are stored locally first
- App remains usable without network access
- If the user has iCloud available and the app has CloudKit enabled, their data can sync or restore across Apple devices
- If the user gets a new iPhone and signs into the same Apple ID/iCloud account, their workout data can reappear

Core rule:

- Logging a set, editing a workout, or finishing a workout must never require live network access

Important product framing:

- This is iCloud persistence, not a custom RepSync account system
- Users do not need to create an app-specific login for v1

## 7. Platform + Architecture Plan

### iPhone app stack

- Swift 6.x-compatible toolchain
- SwiftUI for UI
- Core Data for local persistence
- CloudKit integration for Apple-device sync/persistence
- Keychain only for secure local secrets if any are introduced later
- Local notifications and background-capable Apple APIs where appropriate
- Native charts/media loading where needed

Recommendation:

- Create the Xcode app with `SwiftUI` + `Core Data`
- Use `NSPersistentCloudKitContainer` as the persistence foundation

Why Core Data over SwiftData here:

- More mature and battle-tested
- Better migration/versioning control
- Better support for CloudKit-backed persistence patterns
- Easier to find examples and troubleshooting help for offline-first app data

### CloudKit role in this app

CloudKit is used to provide:

- Apple-device data persistence
- Restore on new iPhone
- Multi-device iCloud-backed sync if the user uses the same Apple account

CloudKit is not being used as:

- A cross-platform backend
- A custom login/account system
- A replacement for future server-side product features if those are added later

## 8. Data Model and Persistence Plan

The current Android local model should be the source reference for the iPhone local model:

- workouts
- exercises
- exercise sets
- completed workouts
- completed exercises
- completed sets
- user profile
- bodyweight entries
- lightweight preferences/reminders

### iPhone local model rules

- Local database is the source of truth for user interaction
- Every screen should read and write against local persistence first
- CloudKit sync should happen through the persistence layer, not through ad hoc screen logic
- Schema design should stay close to the Android concepts so parity work stays manageable

### CloudKit sync model

For v1, the sync model should be intentionally simple:

- User edits local data
- Core Data persists immediately
- CloudKit sync is handled by the persistent container
- iCloud restore/sync is treated as system-backed persistence, not a manually built sync engine

### Data safety expectations

- Treat local writes as authoritative for on-device use
- Expect eventual sync, not instant network confirmation
- Provide clear UX if iCloud is unavailable or disabled
- Consider manual export/import later as a recovery feature, but it is not required for the first pass

## 9. iCloud / CloudKit Product Decisions

Decisions for v1:

- No custom RepSync account creation
- No email/password login
- No Sign in with Apple requirement for app-specific authentication, because there is no custom app account system in v1
- Use the user’s Apple/iCloud environment for cloud persistence

Important implications:

- Users who do not use iCloud may only have local-on-device persistence
- Cloud continuity is tied to Apple ecosystem usage
- This is acceptable because the iPhone version is intentionally Apple-only in its cloud story

UX requirements:

- Explain iCloud sync in simple language
- Avoid presenting it like a full account system
- Tell users what happens if iCloud is unavailable or disabled

## 10. App Store / Apple Program Plan

### Developer account setup

1. Decide whether the app is published under an individual or organization Apple Developer account.
2. Secure legal entity, D-U-N-S number, and public support contact if publishing as an organization.
3. Enable role-based access for owner, engineering, release manager, and support.
4. Enable 2FA on all privileged Apple accounts.
5. Store signing access, recovery contacts, and renewal reminders in an internal runbook.

### App Store Connect setup

- Reserve app name, subtitle, and bundle identifier
- Configure app record, age rating, categories, support URL, privacy URL, and marketing URL
- Prepare screenshots for supported iPhone sizes
- Create TestFlight groups
- Configure app capabilities, including iCloud/CloudKit
- Configure App Privacy answers to reflect actual iCloud-backed storage behavior

### Compliance and policy work

- Privacy policy
- Terms if needed for distribution/support
- Export compliance answers
- Medical/fitness wording review to avoid unsafe claims
- App Privacy disclosure review for locally stored data and iCloud-backed sync

## 11. Feature Parity Workstream

The iPhone app needs explicit parity tracking for each Android area.

### Core parity checklist

- Home/dashboard
- Workout templates list
- New/edit workout template flow
- Quick workout flow
- Active workout flow
- Rest timer
- Calendar and day view
- Exercise history
- Bodyweight entries
- Profile and avatar
- Reminders
- Theme/styling parity
- iCloud persistence behavior messaging/settings where appropriate

### Platform adaptation notes

- Android foreground-service rest timer behavior must be redesigned with iOS-native notification/background handling
- Reminder scheduling must be rebuilt with iOS notification APIs
- Image/GIF loading should be implemented with iOS-friendly caching
- Navigation must be rethought in SwiftUI, not copied literally
- Cloud status or iCloud availability messaging should be centralized, not scattered across screens

## 12. Repo and Delivery Structure

Recommended repo evolution:

- Keep current Android app in `app/`
- Add `ios/` for the iPhone app
- Keep shared docs in `docs/`
- Do not add a `backend/` folder for v1 unless the product direction changes

Suggested structure:

```text
RepSync/
├── app/                    # Existing Android app
├── ios/                    # Native iPhone app
│   └── RepSync/
├── docs/
│   ├── ios/
│   ├── launch/
│   ├── privacy/
│   └── operations/
├── plan.md
└── README.md
```

## 13. Phased Execution Plan

## Phase 0: Product and architecture decisions

Deliverables:

- Final decision on native SwiftUI + Core Data + CloudKit approach
- iPhone launch scope freeze
- Written parity checklist from current Android app
- Written iCloud product expectations

Tasks:

- Audit every Android flow and data entity
- Define which Android behaviors must match exactly on iPhone
- Define iCloud/CloudKit user-facing behavior
- Define offline behavior rules
- Decide how much sync status is visible to users

Exit criteria:

- Team can describe how local data, iCloud persistence, and offline behavior work without ambiguity

## Phase 1: iPhone project foundation

Deliverables:

- Xcode project in `ios/`
- App target with Core Data
- CloudKit capability enabled
- Base design system and app shell

Tasks:

- Create SwiftUI app with Core Data scaffold
- Save it under `ios/RepSync/`
- Enable iCloud and CloudKit entitlements
- Set up build configurations, bundle ID, and signing
- Establish app folder structure for features, models, services, and design system

Exit criteria:

- App launches on iPhone, stores sample data locally, and the persistence container is configured correctly

## Phase 2: Local feature parity

Deliverables:

- Core local features working without CloudKit dependency

Tasks:

- Build home screen
- Build workouts list and template editor
- Build quick workout
- Build active workout flow
- Build history/calendar/day details
- Build exercise history views
- Build profile, bodyweight, reminders
- Match dark compact visual identity

Exit criteria:

- Internal testers can complete the full workout lifecycle on iPhone fully offline

## Phase 3: CloudKit integration and data continuity

Deliverables:

- CloudKit-backed persistence working on real Apple devices
- New-device restore behavior validated

Tasks:

- Connect Core Data store to CloudKit
- Validate iCloud availability handling
- Test initial device sync
- Test reinstall behavior
- Test new iPhone restore behavior using the same Apple ID
- Add UX messaging for iCloud unavailable/disabled states

Exit criteria:

- A user can log workouts on one iPhone and recover them on another supported Apple device path using the same Apple account

## Phase 4: TestFlight and launch prep

Deliverables:

- TestFlight build
- App Store assets and copy
- Support/legal pages

Tasks:

- Create app icon set, screenshots, preview copy, and metadata
- Finalize privacy policy and support page
- Run accessibility and performance passes
- Add crash reporting and release monitoring
- Prepare review notes for Apple, including how iCloud persistence works

Exit criteria:

- External beta can run with monitored stability and clear product messaging

## Phase 5: App Store submission and rollout

Deliverables:

- Approved App Store release
- Post-launch monitoring plan

Tasks:

- Submit release candidate
- Answer App Review questions quickly
- Monitor crash-free sessions, storage/persistence issues, and iCloud-related support issues
- Roll out updates deliberately after launch

Exit criteria:

- App is live on the App Store and operational metrics are healthy

## 14. CloudKit MVP Checklist

Minimum CloudKit-related capabilities:

- iCloud capability enabled in the app target
- CloudKit container configured
- Core Data store backed by `NSPersistentCloudKitContainer`
- Basic handling for iCloud unavailable/disabled states
- Real-device validation on the same Apple ID across devices or restore scenarios

Recommended implementation boundaries:

- Keep CloudKit logic near the persistence stack
- Avoid hand-written per-screen sync logic unless clearly needed
- Keep the user-facing message simple: data is stored locally and can sync through iCloud when available

## 15. Security and Privacy Plan

- Keep workout data local-first
- Use Apple-managed iCloud/CloudKit infrastructure for synced persistence
- Only use Keychain for secure local secrets if needed later
- Limit app data collection to what is necessary
- Ensure privacy disclosures accurately describe local storage and iCloud-backed persistence
- Limit privileged Apple Developer/App Store Connect access to named maintainers only

## 16. QA Plan

### Automated

- iPhone unit tests for local persistence logic where practical
- Basic UI smoke tests on iPhone
- Persistence/migration tests for major data model changes when practical

### Manual

- Full guest-style flow on iPhone
- Workout logging offline
- App restart persistence
- Reminder and rest timer behavior
- iCloud enabled device behavior
- iCloud disabled device behavior
- Reinstall and restore checks
- New-device continuity checks
- Timezone/date-boundary checks

## 17. Launch Assets Checklist

- Apple Developer account secured
- Bundle ID and signing configured
- iCloud/CloudKit capability configured
- App icon and screenshots
- App description, subtitle, keywords
- Support URL
- Privacy policy URL
- TestFlight feedback channel
- App Review notes explaining iCloud-backed persistence if needed

## 18. Risks and Mitigations

### Risk: iCloud/CloudKit behavior feels opaque to users

Mitigation:

- Keep the message simple
- Do not market it like a custom account system
- Add clear UX for unavailable or disabled iCloud states

### Risk: iOS timer/background behavior differs from Android

Mitigation:

- Design iOS-specific timer UX early
- Test notification delivery on real devices
- Avoid assuming Android service patterns translate directly

### Risk: CloudKit edge cases slow development

Mitigation:

- Keep local-first functionality fully usable before layering in CloudKit
- Test on real devices, not simulator only
- Keep the first implementation narrow and boring

### Risk: future cross-platform sync needs change direction

Mitigation:

- Keep domain models clean
- Keep the Android and iPhone feature concepts aligned
- Reevaluate a custom backend later only if product value clearly justifies it

## 19. Suggested Milestones

### Milestone A: Architecture locked

- SwiftUI + Core Data + CloudKit approach approved
- Repo structure approved

### Milestone B: iPhone local alpha

- Core local flows working on iPhone

### Milestone C: iCloud continuity beta

- CloudKit persistence validated across device/restore scenarios

### Milestone D: TestFlight beta

- External testers can use the app reliably

### Milestone E: App Store launch

- Approved, released, monitored

## 20. Team / Role Needs

Minimum realistic ownership:

- 1 iOS engineer
- 1 designer/product owner for parity and App Store assets
- 1 QA owner or strong beta coordination process

Android engineering remains relevant only for parity reference and future separate Android work, not for shared sync infrastructure in this plan.

## 21. First 30 Days

Recommended first month output:

1. Freeze iPhone launch scope and write a parity checklist from the current Android app.
2. Create `ios/RepSync/` and scaffold the SwiftUI + Core Data project.
3. Set up bundle ID, signing, Apple Developer account access, and CloudKit capability.
4. Mirror the main local data model from the Android app into the iPhone project.
5. Build the basic navigation shell and first two or three core screens.
6. Validate local persistence before doing any CloudKit-specific refinement.
7. Test iCloud/CloudKit behavior on real hardware once the local model is stable.

## 22. Definition of Done

This initiative is done when:

- iPhone users can install a native RepSync app from the App Store
- They can use the app fully offline for normal workout logging
- Their data persists locally and can continue across Apple devices through iCloud/CloudKit when available
- App Review requirements and privacy disclosures are complete
- Operational monitoring and support processes exist for launch

## 23. Recommended Immediate Next Docs

After this plan, the next documents to create should be:

1. `docs/ios/feature-parity-checklist.md`
2. `docs/ios/core-data-model-plan.md`
3. `docs/ios/cloudkit-setup-checklist.md`
4. `docs/launch/app-store-checklist.md`
5. `docs/privacy/data-handling-matrix.md`

## 24. Final Recommendation

Do not build a custom backend for the first iPhone release if the only cloud goal is Apple-device persistence.

The highest-probability path is:

- Keep Android as the current offline-only product
- Build a native SwiftUI iPhone app in this same repo
- Use Core Data for local storage
- Use CloudKit for Apple-device continuity
- Prove the local experience first, then layer on iCloud behavior
- Ship through TestFlight before App Store launch
