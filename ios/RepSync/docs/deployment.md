# RepSync Deployment Plan

This document captures the path for taking RepSync from local-only iOS app behavior to an App Store-ready app with Apple ID sign-in, friend connections, and global leaderboard rankings.

## Goals

- Ship RepSync through the App Store.
- Let users sign in with their Apple ID.
- Let users create a public leaderboard username.
- Let users add friends and compare rankings.
- Let users see global and friends leaderboards.
- Keep workout logging fast, local-first, and usable without network access.

## Apple Developer Setup

Create or update the Apple Developer configuration for the production app:

- Enroll in the Apple Developer Program.
- Create the production Bundle ID for RepSync.
- Enable these capabilities:
  - Sign in with Apple
  - iCloud / CloudKit
  - Push Notifications, later, for friend request alerts
- Create App Store Connect app record.
- Add app icon, screenshots, description, privacy policy URL, and privacy nutrition labels.

## Authentication

Use Sign in with Apple as the account identity layer.

The app should:

- Ask for Sign in with Apple when a user opens online leaderboard or friend features.
- Store Apple's stable user identifier locally.
- Keep the Apple identity private.
- Ask the user to create a public leaderboard username.
- Let the user edit their leaderboard username from the leaderboard header card.

The public username should be the searchable social identity. Apple ID details should not be exposed to other users.

## Cloud Backend

Use CloudKit as the first backend because it fits the iOS-only, Apple ID-based direction.

Recommended database split:

- Public CloudKit database:
  - leaderboard profiles
  - public username lookup
  - global leaderboard summary records
- Private CloudKit database:
  - user-owned account metadata if needed
  - sync status or private preferences if needed later
- Shared or public records:
  - friend requests
  - accepted friend relationships

Avoid uploading full workout history by default. Compute ranking and level summaries locally, then upload only the data needed for social comparison.

## Public Leaderboard Profile

Each signed-in user should have one public leaderboard profile record.

Suggested fields:

- `appleUserHash` or private stable owner reference
- `username`
- `displayName`
- `level`
- `totalXP`
- `rank`
- `bodyweightClass`
- `sex`
- `ageRange` or age, depending on privacy decision
- `height`
- `weightClass`
- `movementRanks`
- `updatedAt`

Privacy note: consider showing age range and weight class instead of exact age and bodyweight for public/global contexts.

## Ranking Upload Model

Local data remains source of truth for workouts.

After workout completion or profile/weight changes:

1. Recalculate local XP, level, rank, and movement category ranks.
2. Save locally first.
3. Queue a CloudKit leaderboard profile update.
4. Upload summary fields when network is available.
5. Cache the last successful global/friends leaderboard results locally.

The app should still work if CloudKit is unavailable.

## Global Leaderboard

Global leaderboard should query public leaderboard profiles.

Current intended ordering:

1. Level descending
2. Lift rank descending as tie-breaker
3. Total XP descending as tie-breaker
4. Last updated date as final tie-breaker

The app can display a top 15 preview in the current UI, with room later for expanded leaderboard pages.

## Friend System

Friendship should be based on leaderboard usernames.

Suggested flow:

1. User taps add friend.
2. User enters a leaderboard username.
3. App looks up that username in CloudKit.
4. App creates a friend request record.
5. Recipient sees incoming requests from the leaderboard request icon.
6. Recipient accepts or declines.
7. Accepted requests create a friendship relationship visible to both users.

Friends leaderboard should query only accepted friends plus the current user.

## Notifications

Push notifications are optional for the first online version.

Initial version can show incoming friend requests only when the user opens the leaderboard. Later, add push notifications for:

- incoming friend request
- friend request accepted
- friend passes you in level or rank

## App Store Requirements

Before submission:

- Add a privacy policy.
- Add account deletion support if account data exists.
- Explain synced/public data clearly in onboarding or settings.
- Complete App Store privacy nutrition labels.
- Verify Sign in with Apple works on a real device.
- Verify CloudKit production schema is deployed.
- Test offline behavior.
- Test fresh install, upgrade install, sign out, and account deletion flows.

## Recommended Implementation Phases

1. Add Sign in with Apple and local signed-in state.
2. Add leaderboard username creation and editing.
3. Add CloudKit leaderboard profile sync.
4. Replace placeholder global leaderboard rows with CloudKit query results.
5. Add username search and friend request records.
6. Replace placeholder friends leaderboard rows with accepted-friends query results.
7. Add cached leaderboard fallback for offline use.
8. Add push notifications for friend requests.
9. Harden privacy, account deletion, moderation, and App Store metadata.

## Data Safety Principles

- Keep workout logging local-first.
- Never require sign-in to log workouts.
- Do not upload full workout details unless the user explicitly opts in.
- Upload leaderboard summaries, not raw history.
- Keep public profile fields minimal.
- Design all CloudKit writes to retry safely.
