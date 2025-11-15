## Purpose
This repo is a Flutter app (mobile + web) called `manager` — a small fleet/traccar manager. These instructions surface the important, discoverable patterns and workflows an AI coding agent should follow to be productive quickly.

**Big picture**
- **Frontend-only Flutter app**: UI lives in `lib/` (pages, widgets, theme). Entry point is `lib/main.dart`.
- **Service layer**: network and auth code in `lib/services/` (e.g. `api_service.dart`, `auth_service.dart`). Use these files to understand server integration and auth flows.
- **Models**: DTOs live in `lib/models/` (e.g. `device.dart`, `position.dart`). Prefer using their `fromJson` constructors when modifying API clients.
- **Map integration**: map code lives under `map/` and `assets/map/` (see `map/styles.dart` and `assets/map/icons/`). Map rendering uses `maplibre_gl` declared in `pubspec.yaml`.

**Platform-specific behavior to respect**
- The app branches on `kIsWeb` in multiple places: `lib/main.dart` (login flow) and `lib/services/api_service.dart` (auth headers). On web the app expects a token in the URL; on native it uses cookie-based session. Preserve these differences when editing auth or API logic.
- Conditional import pattern is used for web helpers: e.g. `web_helper_stub.dart if (dart.library.html) 'web_helper_web.dart'`. Follow this pattern for platform-specific helpers.

**Build / run / CI hints**
- Get dependencies: `flutter pub get`.
- Run app locally: `flutter run -d <device>` (or use VSCode/Android Studio). For web: `flutter run -d chrome`.
- Run tests: `flutter test`.
- iOS build (used by repo): see `build.sh` — it runs `scripts/generate_icons.sh`, `flutter pub get`, then `flutter build ios --config-only --no-codesign` with required `--dart-define` values. When adding build-time config, mirror this approach.

**Project-specific conventions**
- Folder layout is conventional but opinionated: keep UI in `lib/pages` and business/network code in `lib/services`.
- Localization: `pubspec.yaml` sets `flutter.generate: true` and `lib/l10n/` contains ARB and generated localization files. Use `flutter gen-l10n` or `flutter pub get` to regenerate translations; prefer the existing `app_localizations.*` helpers.
- Assets: icon generation is scripted (`scripts/generate_icons.sh`) and `assets/map/icons/` is referenced in `pubspec.yaml`. Changes to icons should use the script.

**APIs and integration points**
- Base URL and authentication: see `lib/services/auth_service.dart` and `lib/services/api_service.dart`. API calls use either `Authorization: Bearer <token>` (web) or `Cookie` (native). Don't replace one with the other without handling both paths.
- Websocket and background message patterns: dependencies include `web_socket_channel` and `http`. Check services for usage; prefer existing patterns for connection lifecycle.

**Files to consult when making changes**
- `lib/main.dart` — app entry and `AuthGate` behavior.
- `lib/services/api_service.dart` — HTTP client patterns, conditional imports, error logging.
- `lib/services/auth_service.dart` — session and cookie handling (native) and base URL configuration.
- `lib/models/*.dart` — canonical JSON parsing for API objects.
- `map/styles.dart` and `assets/map/icons/` — map styling and icon assets.
- `pubspec.yaml` and `build.sh` — dependency, asset, and build-time config.

**What not to change without coordination**
- Authentication switching: do not convert web token flow into native cookie flow (or vice versa) without handling both branches and updating `AuthGate` and `api_service` together.
- Localization file names / keys: conform to the existing ARB keys; regenerate using `flutter gen-l10n` if changing ARB.
- Icon generation: keep using `scripts/generate_icons.sh` for consistent asset sizes.

If any section above is unclear or you want more detail (examples of API requests, auth flow diagram, or a list of important tests), tell me which part to expand and I will update this file.

---
Generated/updated by AI assistant while scanning repository files: `lib/main.dart`, `lib/services/api_service.dart`, `pubspec.yaml`, `build.sh`, `lib/l10n/`.
