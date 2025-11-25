# Repository Guidelines

## Project Structure & Module Organization
- SwiftUI sources live at the repo root beside `Flow.xcodeproj`: entry points (`LearningTimerApp.swift`, `ContentView.swift`), feature views (`MiniTimerView.swift`, `StatsView.swift`, `TimerView.swift`), and observable objects/services (`TimerViewModel.swift`, `SessionStore.swift`, `FlowNotifications.swift`).
- Shared models are in `Models.swift`; window helpers in `FloatingWindowManager.swift` and `WindowAccessor.swift`.
- Assets and entitlements sit in `Assets.xcassets` and `Flow.entitlements`; packaging scripts (`build_release.sh`, `package_app.sh`, `create_dmg.sh`) are in the root.
- Tests live under `Tests/` (e.g., `Tests/FlowTests/EffectiveFocusCalculatorTests.swift`). CSV seed data is alongside the root files.

## Build, Test, and Development Commands
- `xcodebuild -project Flow.xcodeproj -scheme Flow -configuration Debug build` — primary macOS build.
- `swift build` / `swift run Flow` — fast CLI builds/runs via Package.swift.
- `./build_release.sh` — produce a clean Release app at `build/Build/Products/Release/Flow.app`.
- `./package_app.sh` — bundle resources, compile icons, and generate the DMG (uses `create_dmg.sh`).

## Coding Style & Naming Conventions
- Swift 5.9 defaults: 4-space indent, prefer trailing commas where Xcode suggests, explicit `private`/`internal`.
- Types use UpperCamelCase; functions/bindings lowerCamelCase. Favor value semantics for models and declarative SwiftUI.
- Keep side effects isolated in observable objects; place related files together to preserve the flat target layout.

## Testing Guidelines
- No XCTest target historically; current tests live under `Tests/`. Add cases as `testScenarioExpectedResult` and run with `swift test`.
- For manual smoke tests, launch the Debug app and verify both the main timer window and floating mini timer; `test_floating_window.scpt` provides automation hints.
- Use `sessions-test.json` for deterministic stats/streak validation.

## Commit & Pull Request Guidelines
- Follow `<type>: <imperative>` messages (`fix`, `feat`, `chore`), noting UI-impacting files when relevant.
- PRs should include a short summary, testing notes (commands run; screenshots for UI changes), and links to issues/release checklists.
- Call out changes to scripts, assets, or entitlements so reviewers can rerun packaging and codesign steps.

## Security & Configuration Tips
- Never commit signing identities or secrets; rely on your keychain during codesign.
- After packaging, verify entitlements when notifications or window access change: `codesign -dv build/Build/Products/Release/Flow.app`.
