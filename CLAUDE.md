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

# Setup environment for GUI apps (required after system restart)
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
- Auto-dismisses after 10 seconds
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

## Swift 6 Concurrency

The codebase uses strict concurrency:
- TranslationService is Sendable
- NetworkClient protocol is Sendable
- ViewModel is @MainActor
- ServiceProvider is @MainActor (required for safe service handling)
- Async/await used throughout
- SpeechDelegate uses @unchecked Sendable (required for AVSpeechSynthesizerDelegate)
