# Knowledge

A Flutter app for collecting notes inside a single tree and turning selected nodes into flashcards.

## Current draft

- One main tree view with nested nodes and drag-to-nest reorganization
- Markdown-style note body per node
- Flashcard toggle on any node
- Due-card review flow with `Forgot`, `Hard`, `Good`, and `Easy`
- Local persistence in `shared_preferences`
- Automatic JSON backups with restore support
- Clipboard export and pasted-JSON import
- Optional Supabase bootstrap wiring for future cloud sync work

## Project structure

- `lib/main.dart`: app entry
- `lib/src/app.dart`: app shell and theme
- `lib/src/app_version.dart`: in-app version/changelog link
- `lib/src/supabase_bootstrap.dart`: optional Supabase startup
- `lib/src/features/knowledge/domain`: node and review models
- `lib/src/features/knowledge/data`: persistence and backup services
- `lib/src/features/knowledge/presentation`: main screen and dialogs

## Getting started

```bash
flutter pub get
flutter run
```

Optional Supabase bootstrap:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## Quality checks

```bash
flutter analyze
flutter test
```
