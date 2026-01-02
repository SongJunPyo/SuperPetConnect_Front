# Repository Guidelines

## Project Structure & Module Organization
- `lib/` holds the app code; feature areas live in subfolders such as `admin/`, `auth/`, `hospital/`, `user/`, and shared layers like `models/`, `services/`, and `utils/`. Keep cross-cutting widgets inside `widgets/` and assets in `images/`.
- `test/` mirrors the structure of `lib/` for unit and widget coverage. Platform folders (`android/`, `ios/`, `web/`, etc.) stay untouched unless you are updating native integrations.
- `firebase_options.dart` and `.env` store environment configuration. Avoid committing secrets—use sample placeholders when documenting new keys.

## Build, Test, and Development Commands
- `flutter pub get` installs Dart dependencies defined in `pubspec.yaml`.
- `flutter run -d chrome` spins up the web target for quick UI checks; use a device ID for mobile builds.
- `flutter test` runs unit and widget suites; add `--coverage` when validating test depth before release.
- `flutter analyze` surfaces lint violations based on `analysis_options.yaml`.
- `flutter build apk --release` produces a production Android bundle; parallel commands exist for other platforms.

## Coding Style & Naming Conventions
- Follow Flutter lints; keep indentation at two spaces and prefer trailing commas to trigger formatter-friendly layouts.
- Use `dart format .` before committing. Favor descriptive lowerCamelCase for variables/functions, UpperCamelCase for types/widgets, and snake_case for file names.
- Centralize shared constants in `utils/` and service endpoints in `services/` to prevent scattering configuration details.

## Testing Guidelines
- Co-locate tests with matching modules (`lib/user/profile.dart` → `test/user/profile_test.dart`). Name files with `_test.dart`.
- Aim for meaningful widget tests when UI state changes; mock Firebase or HTTP layers with the helpers in `utils/`.
- Capture coverage locally via `flutter test --coverage` and review `coverage/lcov.info` before major merges.

## Commit & Pull Request Guidelines
- Recent history favors concise, imperative Korean summaries (e.g., `시간대 중복 문제 해결`); keep commits scoped and rebased.
- Reference issue IDs in the body if applicable, and include screenshots or screen recordings for UI-facing changes.
- PR descriptions should outline intent, testing results, and rollback considerations. Ensure CI passes and resolve analyzer warnings pre-review.

## Environment & Configuration Tips
- Update `.env` and `firebase_options.dart` together when credentials change; document defaults in the PR, not the file.
- Regenerate Firebase config with `flutterfire configure` when onboarding new environments, and verify generated options into source control only when safe.
