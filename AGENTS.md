# Agent Instructions

## Commit Policy
- Treat each completed feature, fix, or discrete task as its own commit.
- Commit immediately after finishing the change and any relevant verification, before starting the next feature.
- Any task that results in a commit must also include an appropriate version bump as part of that same change before committing.
- Do not batch unrelated work into the same commit.
- If a request contains multiple independent features, complete and commit them one at a time.
- Only commit changes that belong to the current task. If unrelated local changes would make that unsafe, stop and ask the user how to proceed.

## Versioning
- Keep `pubspec.yaml` and `lib/src/app_version.dart` in sync.
- Use a patch bump for bug fixes and tooling-only changes.
- Use a minor bump for user-visible features.
- Keep `CHANGELOG.md` up to date for every version bump.
- Add a concise entry summarizing user-visible changes in the same change that updates the version.

## Git Usage
- Prefer non-interactive git commands.
- Use clear commit messages that describe the completed feature or fix.
- After completing and verifying a task, push its commit to the configured remote by default even if the user did not explicitly ask in that turn.
- If the user explicitly says not to push, do not push.
- Do not rewrite published history unless the user explicitly requests it.
