# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BMO (branded as "Sig") is a macOS menu bar application for Danish ↔ English translation using the DeepL API. It's a Swift Package Manager project targeting macOS 14+ with SwiftUI.

## Essential Commands

### Building and Running

```bash
# Build release binary
swift build -c release

# Build the macOS app bundle (creates Sig.app)
./build-app.sh

# One-time install: LaunchAgent that auto-exports DEEPL_API_KEY to launchctl at every login
./install-launchagent.sh

# Manual fallback: re-export DEEPL_API_KEY for the current session (must be re-run after each restart)
./setup-env.sh

# Run from command line (requires DEEPL_API_KEY in environment)
.build/release/BMO

# Open in Xcode
open Package.swift
```

### Testing

```bash
# Run unit tests only
swift test

# Run with integration tests (requires API key)
DEEPL_API_KEY=your-key ENABLE_INTEGRATION_TESTS=1 swift test
```

### Xcode Development

To run in Xcode, you must set the `DEEPL_API_KEY` environment variable:
1. Edit Scheme → Run → Arguments tab → Environment Variables
2. Add: `DEEPL_API_KEY` = `your-api-key-here`

## Architecture

### Target Structure

The project uses a library + executable pattern to support SwiftUI previews:

- **BMOLib** (library target): Contains all SwiftUI views, business logic, and supports Xcode previews
- **BMO** (executable target): Minimal entry point that depends on BMOLib

This separation is critical because SPM executable targets don't support SwiftUI previews, but library targets do.

### Key Components

**AppDelegate** (Sources/BMOLib/AppDelegate.swift:4)
- Creates and manages the NSStatusItem (menu bar icon)
- Initializes the NSPopover containing the SwiftUI view
- Validates DEEPL_API_KEY on launch
- Loads custom menu bar icon from Resources/

**TranslatorView + TranslatorViewModel** (Sources/BMOLib/TranslatorView.swift:4-202)
- Main SwiftUI interface using MVVM pattern
- ViewModel is @MainActor and handles async translation calls
- Includes AVFoundation integration for Danish text-to-speech
- Contains mock NetworkClient for Xcode previews

**TranslationService** (Sources/BMOLib/TranslationService.swift:44)
- Core translation logic, marked as Sendable for Swift 6 concurrency
- Dependency injection via NetworkClient protocol for testability
- Throws strongly-typed TranslationError enum

**NetworkClient Protocol** (Sources/BMOLib/TranslationService.swift:38)
- Abstraction for HTTP calls to DeepL API
- URLSessionNetworkClient is the production implementation
- MockNetworkClient used in tests and previews

### Configuration

**APIConfiguration** (Sources/BMOLib/Configuration.swift:5)
- Centralizes DeepL API endpoint configuration
- Defaults to free tier endpoint: api-free.deepl.com
- Supports custom configuration for testing

### Environment Variables

The app requires `DEEPL_API_KEY` to function:
- Command line: Set in `~/.zshenv` (not `~/.zshrc` — `.zshenv` is loaded for non-interactive shells too, which is what `launchctl` and the LaunchAgent read)
- Xcode: Set in scheme environment variables
- GUI apps: Run `./install-launchagent.sh` once to install `com.bmo.envsetup.plist`, which re-exports `DEEPL_API_KEY` to `launchctl` at every login. `./setup-env.sh` is the manual fallback (must be re-run after each restart)

### Menu Bar Icon

Custom icon loading logic (Sources/BMOLib/AppDelegate.swift:66):
- Attempts to load from Resources/menubar-icon.pdf or .png
- Sets `isTemplate = true` for automatic dark/light mode adaptation
- Falls back to SF Symbol "service.dog" if custom icon not found

## Testing Strategy

**Unit Tests** (Tests/BMOTests/TranslationServiceTests.swift)
- Use MockNetworkClient to avoid hitting real API
- Test error handling, validation, and business logic

**Integration Tests** (Tests/BMOTests/TranslationServiceIntegrationTests.swift)
- Only run when ENABLE_INTEGRATION_TESTS=1 is set
- Hit real DeepL API, require valid DEEPL_API_KEY
- Validate actual translation quality

## SwiftUI Previews

All SwiftUI views in BMOLib support live previews in Xcode:
1. Open TranslatorView.swift in Xcode
2. Enable Canvas: ⌥⌘↩ or Editor → Canvas
3. Previews use MockNetworkClient, no API key needed
4. See preview definitions at Sources/BMOLib/TranslatorView.swift:344

## App Bundle Structure

The `build-app.sh` script creates a proper macOS app bundle:
- Binary copied to Sig.app/Contents/MacOS/Sig
- Info.plist defines bundle metadata
- AppIcon.icns provides app icon
- Resources folder bundled automatically

## Language Support

Currently supports only Danish ↔ English via Language enum (Sources/BMOLib/TranslationService.swift:5). To add new language pairs:
1. Add cases to Language enum
2. Update UI in TranslatorView
3. Consider updating speech synthesis logic (only Danish TTS currently implemented)

## macOS Services Integration (v1.5)

The app now includes a system-wide translation service that appears in the macOS Services menu.

**ServiceProvider** (Sources/BMOLib/ServiceProvider.swift:5)
- Marked as @MainActor for Swift 6 concurrency safety
- Registered via `NSApp.servicesProvider` in AppDelegate
- Handles `translateText` method called by macOS Services infrastructure
- Auto-detects language by trying both directions (DA→EN, then EN→DA if first fails)
- Limits text to 5000 characters to prevent API abuse

**TranslationResultWindow** (Sources/BMOLib/TranslationResultWindow.swift:5)
- SwiftUI-based floating window for displaying translation results
- Positioned near mouse cursor when service is invoked
- Auto-dismisses after `AppSettings.shared.effectiveTimeout` (default 15s, user-configurable in Settings; 0 disables auto-dismiss)
- Includes copy-to-clipboard functionality
- Uses borderless window with floating level for non-intrusive display

**Info.plist Configuration**
- NSServices array declares the "Translate with BMO" service
- NSMessage: `translateText` maps to ServiceProvider method
- NSSendTypes: accepts `public.utf8-plain-text` and `NSStringPboardType`
- Service appears in right-click context menus when text is selected

**Service Registration**
- macOS automatically discovers services from Info.plist in app bundles
- Service cache can be refreshed with `/System/Library/CoreServices/pbs -flush`
- Users can enable/disable in System Settings → Keyboard → Services
- App must be in /Applications or ~/Applications for service to be discovered

## Popover Pin (v1.7)

The menu bar popover normally uses `NSPopover.behavior = .transient`, which auto-closes when it loses focus or the user clicks outside — disruptive during a long translation session (e.g. tabbing to another app to reference text). A footer pin toggle lets the user keep it open on demand.

**TranslatorViewModel.isPinned** (Sources/BMOLib/TranslatorView.swift)
- `@Published`, session-only — not persisted to `AppSettings`/`UserDefaults`
- Toggled via the pin footer button (next to Settings) in `FooterRow`

**AppDelegate**
- Constructs `translatorViewModel` itself (rather than letting `TranslatorView` own it internally) so it can subscribe to `$isPinned` via Combine and flip `popover.behavior` between `.transient` (default) and `.applicationDefined` (pinned — disables NSPopover's automatic dismissal entirely)
- `TranslatorView` takes this injected view model via `@ObservedObject`, not `@StateObject`, since AppDelegate — not the view — owns its lifecycle
- `togglePopover()`'s manual-close path always resets `isPinned = false` before calling `performClose`, so every fresh open starts unpinned and auto-dismissing again

## Danish IPA Pronunciation (v1.9)

Optional IPA transcription (e.g. `/hɛjˀ/`) shown alongside whichever side of a translation is Danish — the input when translating DA→EN, the output when translating EN→DA. Computed once per completed translation, not live-as-you-type.

**Data source: espeak-ng** (Sources/BMOLib/PhoneticsService.swift)
- GPL-3.0, invoked as an external process via `Process` (not bundled/linked) — same relationship as the app has with any other CLI tool, so the app's own MIT license is unaffected
- Requires `brew install espeak-ng`; not bundled, not installed automatically
- `EspeakNG.executablePath()` checks well-known Homebrew/system install locations directly rather than relying on `Process`'s PATH lookup — same reasoning as `DEEPL_API_KEY`'s `.zshenv` requirement: launchd's PATH for GUI-launched apps is minimal
- `ProcessPhoneticsRunner` shells out to `espeak-ng -v da --ipa -q <text>`; arguments are passed as a `Process` array, not a shell string, so there's no injection concern
- `PhoneticsService` wraps it behind the `PhoneticsRunner` protocol — same DI shape as `TranslationService`/`NetworkClient` — for test/preview mocking

**EspeakAvailability** (Sources/BMOLib/EspeakAvailability.swift)
- `@MainActor` `ObservableObject`, mirrors `APIKeyMonitor`'s role — drives the Settings status row (not found / detected)

**Settings** — `AppSettings.showIPA`, default off (extra subprocess call per translation, and the dependency isn't installed by default)

**Display**
- Popover: `TranslatorViewModel.danishIPA`, recomputed in `refreshDanishIPA(source:translated:from:to:)` after a successful translation, on `swapLanguages()`, and on `restore(from:)` (not persisted in `HistoryItem` — recomputed on demand rather than migrating its schema)
- Services/hotkey floating window: `TranslationResultViewModel.fetchDanishIPAIfNeeded(original:translated:detectedSource:)`, called once via `.task { }` on `TranslationResultView` so SwiftUI cancels it automatically if the window closes mid-lookup

## Swift 6 Concurrency

The codebase uses strict concurrency:
- TranslationService is Sendable
- NetworkClient protocol is Sendable
- ViewModel is @MainActor
- ServiceProvider is @MainActor (required for safe service handling)
- Async/await used throughout
- SpeechDelegate uses @unchecked Sendable (required for AVSpeechSynthesizerDelegate)
