# RepSync Release Agent Prompt

Use this repo's current state as the source of truth and complete the full Android release flow end to end.

## Goal

Bump the app version from whatever it is currently set to, commit all intended local changes, push them to GitHub, create a matching version tag, and publish a GitHub Release that includes the debug APK asset.

## Important Context

- This repo already uses `vX.Y.Z` tags. Keep using that format.
- Do not hardcode a target version. Read the current version values first and bump from there.
- The release artifact should always be the debug APK.
- This repo does not have release-signing material for CI, so do not switch the release flow to signed release APKs.
- Include the existing local changes in the commit unless you find a direct conflict with the release work. If you find a conflict, call it out clearly before proceeding.

## Required Steps

1. Inspect `app/build.gradle.kts` and read the current `versionName` and `versionCode`.
2. Choose the next version based on the current version instead of assuming a fixed target.
3. Update `app/build.gradle.kts` with the bumped `versionName` and `versionCode`.
4. Review release-facing docs and update them only where needed so they match the debug APK GitHub Release flow.
5. Review the current worktree and preserve the intended local changes already present.
6. Run `./gradlew assembleDebug`.
7. Confirm the APK exists at `app/build/outputs/apk/debug/app-debug.apk`.
8. Commit the release-related changes together with the existing intended local changes.
9. Push the branch to GitHub.
10. Create and push a tag named `v<versionName>`.
11. Verify the GitHub Actions release workflow runs for that tag and that the GitHub Release includes the debug APK asset.

## Release Rules

- The GitHub Release tag must exactly match `v<versionName>`.
- The uploaded asset must be `app-debug.apk` from `app/build/outputs/apk/debug/app-debug.apk`.
- If the release body needs text, use a short summary based on the most relevant recent changes or existing release notes.
- If the repo already contains release automation, extend or fix it instead of replacing it unnecessarily.

## Safety Checks

- Do not discard or overwrite unrelated local changes.
- Do not introduce signed-release or Play Store requirements.
- If the build fails, fix the release flow issues before tagging.
- If GitHub authentication or push permissions are blocked, stop and report the exact blocker.
