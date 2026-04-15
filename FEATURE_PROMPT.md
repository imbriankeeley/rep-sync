# RepSync Feature Prompt

Use this when you want an agent to build a new feature in this repo with minimal back-and-forth.

## Copy/Paste Prompt

```text
You are working in the RepSync repository, an offline-first Android workout app.

Read AGENTS.md first and follow it. Then inspect the relevant files before making changes. Reuse the existing architecture and UI patterns already present in the repo.

Implement the feature below end-to-end in code, not just as a plan.

Feature request:
[Describe the feature in one paragraph.]

User outcome:
[Describe what the user should be able to do after this change.]

Acceptance criteria:
- [Criterion 1]
- [Criterion 2]
- [Criterion 3]

Non-goals:
- [What should explicitly stay unchanged]

Constraints:
- Keep the app offline-first and local-only unless I explicitly ask otherwise.
- Keep the existing dark Material 3 visual style.
- Avoid unnecessary new dependencies.
- Prefer the repo's current patterns: Compose screens, StateFlow-backed ViewModels, Room/DataStore persistence, and Navigation Compose.

Likely files or areas to inspect first:
- [screen file]
- [viewmodel file]
- [dao/entity/database file]
- [navigation file]

Data impact:
- [None / describe any schema or preference change]

Navigation impact:
- [None / describe new or changed route]

Verification required:
- Run ./gradlew assembleDebug after the change if possible.
- List any manual test flows that should be checked.

Implementation rules:
1. Read the affected screen, ViewModel, DAO/entity, navigation, and theme files before editing.
2. Make the smallest coherent change that completely delivers the feature.
3. If Room schema changes are needed, add a migration and preserve user data.
4. If a new screen or route is needed, update both Screen.kt and RepSyncNavHost.kt.
5. Keep reusable UI in ui/components and screen-specific code in ui/screens.
6. State any assumptions you make, but do not stop for clarification unless the risk is high.
7. After coding, summarize what changed, which files were touched, what was verified, and any remaining risks.

Deliverables:
- Implemented code changes
- Short summary
- Assumptions made
- Verification results
- Any follow-up suggestions only if they are truly important
```

## Recommended Way To Fill It Out

- Keep the feature request concrete and user-facing.
- Write 3 to 6 acceptance criteria, not 20.
- Call out what should not change so the agent does not over-edit.
- Name the likely files if you already know them.
- Say whether the feature touches Room, DataStore, navigation, notifications, or services.

## Example Starter

```text
Feature request:
Add a filter on the bodyweight history screen so users can quickly switch between 30-day, 90-day, and all-time views.

User outcome:
Users can narrow the chart and entries list to a useful time range without deleting data.

Acceptance criteria:
- The bodyweight history screen shows 30-day, 90-day, and all-time filter options.
- Changing the filter updates both the chart and the entries list.
- The default filter is all-time.
- Existing entry creation, edit, and delete behavior still works.

Non-goals:
- Do not redesign the whole profile flow.
- Do not add cloud sync or export.

Likely files or areas to inspect first:
- app/src/main/java/com/repsync/app/ui/screens/BodyweightEntriesScreen.kt
- app/src/main/java/com/repsync/app/ui/viewmodel/BodyweightEntriesViewModel.kt
- app/src/main/java/com/repsync/app/ui/components/WeightProgressionChart.kt
```
