# Music Integration Status

RepSync currently has dormant Apple Music and Spotify integration code, but music features are intentionally hidden from the user experience.

## Current Product Decision

Music integration is a distant maybe implementation. For now, RepSync is moving forward without visible workout audio features.

The app should prioritize:

- fast workout logging
- clean workout creation
- active workout reliability
- leaderboard and ranking systems
- profile, biometrics, reminders, and bodyweight tracking

Music controls should not distract from the core workout flow until the rest of the product is stable.

## Hidden Surfaces

The following user-facing music surfaces are hidden:

- Profile Settings Audio section
- Music provider picker from Home
- Workout list music summary labels
- Workout detail music summary labels
- New/Edit Workout audio attachment card
- Active workout music controls

The underlying code can remain in place for now as dormant implementation detail, but users should not see music setup, provider selection, playlist attachment, or playback controls.

## Future Reconsideration

Music integration can be reconsidered later if it supports the core workout experience without adding too much complexity.

Possible future requirements:

- Apple Music only first, before Spotify
- clear privacy and permissions copy
- reliable physical-device testing
- no dependency on music features for workout logging
- no visible UI unless the user explicitly enables audio features
- simple playlist attachment per workout
- compact playback controls during active workouts

## Implementation Guidance

Until this feature is reactivated:

- Do not add new visible music UI.
- Do not prompt users to connect Apple Music or Spotify.
- Do not show playlist names on workout cards.
- Do not show audio controls during active workouts.
- Do not make music provider state part of required workout creation.

If music returns, gate it behind an explicit feature flag or user setting so the default app experience remains focused on workout tracking.
