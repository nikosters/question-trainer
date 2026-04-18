# AGENTS.md

Guidance for coding agents working in this repository.

## 1) Project Context
- Tech stack: Flutter + Dart (`sdk: ^3.9.2`).
- App purpose: local quiz training from imported JSON packages.
- Entrypoints: `lib/main.dart` -> `lib/app.dart`.
- Architecture: simple layered app (`models/`, `services/`, `screens/`, `widgets/`, `utils/`).
- Persistence: package metadata in `SharedPreferences`, package content as JSON files in app support directory.
- Lints: `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`.

## 2) Repo Map
- `lib/app.dart` - app shell/theme/home screen.
- `lib/screens/package_list_page.dart` - package list + import/update/delete actions.
- `lib/screens/quiz_page.dart` - quiz flow, answer selection, score screen.
- `lib/services/package_storage.dart` - parsing/import/persist/load/delete.
- `lib/models/question_item.dart` - question model + strict JSON validation.
- `lib/models/question_package_meta.dart` - package metadata model.
- `lib/widgets/formula_text.dart` - inline LaTeX text rendering.
- `lib/utils/date_time_format.dart` - date formatting helper.
- `test/app_test.dart` - baseline widget test.

## 3) Build / Lint / Test Commands
Run from repo root (`/home/nkstr/dev/ege_app`).

### Setup
```bash
flutter pub get
```

### Run App
```bash
flutter run
flutter run -d <device-id>
```

### Lint / Analyze
```bash
flutter analyze
```

### Format
```bash
dart format lib test
dart format --output=none --set-exit-if-changed lib test
```

### Tests
Run all tests:
```bash
flutter test
```

Run one file:
```bash
flutter test test/app_test.dart
```

Run a single test by name (important):
```bash
flutter test --plain-name "Main screen is shown"
```

Run a single named test within one file:
```bash
flutter test test/app_test.dart --plain-name "Main screen is shown"
```

Verbose test output:
```bash
flutter test -r expanded
```

### Build
```bash
flutter build apk
flutter build appbundle
flutter build web
flutter build linux
flutter build windows
flutter build macos
flutter build ios
```

## 4) Code Style Guidelines
### Imports
- Prefer `package:` imports, including internal files (`package:question_trainer/...`).
- Group imports in this order:
  1. `dart:*`
  2. third-party packages
  3. `package:question_trainer/...`
- Keep groups alphabetized where practical.
- Remove unused imports.

### Formatting and Structure
- Always use `dart format` for final formatting.
- Keep functions focused; extract private helpers when methods get long.
- Use trailing commas in multiline widget trees/constructors.
- Keep build methods readable via local variables for intermediate state.
- Avoid unnecessary comments; prefer self-explanatory names.

### Types and Immutability
- Use explicit types for public APIs and model fields.
- Prefer `final` for fields/locals unless mutation is required.
- Prefer `const` constructors/widgets where possible.
- Avoid `dynamic` except at JSON boundaries.
- Validate untrusted/parsing input aggressively.

### Naming Conventions
- Classes/types: `PascalCase`.
- Methods/variables/params: `lowerCamelCase`.
- Private members: leading underscore (e.g., `_loadPackages`).
- Constants: keep existing repo style (`static const`/`const` with lowerCamelCase names).
- Test names: behavior-oriented sentence strings.

### Error Handling
- Throw `FormatException` for invalid JSON/package payloads.
- Surface errors to users in UI via snackbar/error state text.
- In `StatefulWidget`, check `mounted` before `setState` after `await`.
- Use `try/catch/finally` for async operations with loading flags.
- Do not silently swallow exceptions.

### Flutter/UI Patterns in This Repo
- Keep state minimal and explicit in stateful screens.
- Preserve Material 3 + seed color theming unless task requests otherwise.
- Keep current Russian-language UX copy consistent.
- Use helper methods for repeated UX patterns (`_showMessage`, dialogs, etc.).
- Maintain deterministic quiz behavior (lock answer after selection, then advance).

### Testing Expectations
- Use `flutter_test` and `testWidgets` for UI behavior.
- Add/adjust tests when changing parsing logic or user-facing flows.
- Prefer targeted tests for changed behavior before broad regressions.

## 5) Agent Workflow
- Read related `model + service + screen` files before editing behavior.
- After edits: run `dart format lib test`, then `flutter analyze`.
- Run at least one relevant test (`flutter test ... --plain-name ...` when possible).
- Do not edit generated build outputs (`build/`, `.dart_tool/`, platform ephemeral files).
- Keep patches minimal and consistent with existing code style.

## 6) Cursor / Copilot Rules
Checked rule locations in this repo:

- `.cursor/rules/` -> not found.
- `.cursorrules` -> not found.
- `.github/copilot-instructions.md` -> not found.

If any of these files are added later, treat them as high-priority local instructions.
