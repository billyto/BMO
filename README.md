# Sig - Danish-English Translator

A lightweight macOS menu bar app for quick Danish ↔ English translations using DeepL API.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.10-green)

## Features

- 🪖 Lives in your menu bar for quick access
- 🇩🇰 ↔ 🇬🇧 Bidirectional Danish-English translation
- ⚡ Fast translations powered by DeepL API
- 🎨 Clean, modern SwiftUI interface
- ⌨️ Keyboard shortcuts (⌘+Return to translate, ⌘+K to clear)
- 🔄 Clickable language swap
- 🔊 Text-to-speech for Danish pronunciation
- 🎯 Proper macOS app bundle for easy installation
- 🖱️ System-wide translation service - right-click any selected text and translate via Services menu
- 📌 Pin the popover open during long sessions - stays open even if it loses focus
- 🗣️ Danish IPA pronunciation guide (e.g. `/hɛjˀ/`) shown alongside translations - optional, requires `espeak-ng`
- 🗂️ **NEW:** Bookmark translations and export them as Anki flashcards (Danish front, English back)

## Screenshots

![BMO Translator Interface](screenshot.png)

## Requirements

- macOS 14.0 or later
- DeepL API key (free tier available: 500,000 characters/month)
- Optional: [espeak-ng](https://github.com/espeak-ng/espeak-ng) (`brew install espeak-ng`) for the Danish IPA pronunciation guide - not required otherwise; enable it in Settings once installed

## Installation

### Prerequisites

1. **Get a DeepL API Key** (Required)
   - Sign up for a free DeepL API account at [https://www.deepl.com/pro-api](https://www.deepl.com/pro-api)
   - Free tier includes 500,000 characters/month
   - Copy your API key

2. **Set API Key as Environment Variable**

   Add to your `~/.zshenv` (preferred for GUI apps):
   ```bash
   export DEEPL_API_KEY="your-api-key-here"
   ```

   Then reload your shell:
   ```bash
   source ~/.zshenv
   ```

   **Note:** Use `~/.zshenv` instead of `~/.zshrc` because `.zshenv` is loaded for all shell sessions, including non-interactive ones.

### Option 1: Install as macOS App (Recommended)

```bash
# Clone the repository
git clone https://github.com/billyto/BMO.git
cd BMO

# Build the app bundle
./build-app.sh

# Install LaunchAgent for automatic environment setup (ONE-TIME SETUP)
./install-launchagent.sh

# Install to Applications folder
cp -r Sig.app /Applications/

# Launch the app
open /Applications/Sig.app
```

Now you can:
- Launch Sig from Spotlight (⌘+Space, type "Sig")
- Add to your Dock
- Set to launch at login (System Settings → General → Login Items)

**What the LaunchAgent does:**
- Automatically sets `DEEPL_API_KEY` for GUI apps at every login
- No manual steps needed after system restarts
- Reads the API key from your `~/.zshenv` file

**Alternative (manual setup):** If you prefer not to use the LaunchAgent, you can run `./setup-env.sh` manually after each restart.

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/billyto/BMO.git
cd BMO

# Build the release binary
swift build -c release

# Run directly (requires DEEPL_API_KEY in environment)
.build/release/BMO
```

## Usage

### Menu Bar App

1. Click the viking helmet icon (🪖) in your menu bar
2. Type or paste Danish or English text
3. Click "Translate" or press ⌘+Return
4. Click the language indicator (🇩🇰 Danish → 🇬🇧 English) to swap direction
5. Press ⌘+K to clear all text
6. Click the speaker icon to hear Danish pronunciation
7. Click the pin icon to keep the popover open while you work - normally it closes as soon as it loses focus or you click elsewhere; pinning disables that until you unpin it or quit
8. Click the bookmark icon next to a translation (or press ⌘D) to save it for Anki - see [Anki Export](#anki-export-new-in-v110)
9. Click the power icon to quit the app

### Anki Export (NEW in v1.10)

Bookmark translations while you study, then export them as Anki flashcards in one go.

1. **Bookmark** a translation with the bookmark icon - in the popover result (⌘D), the Services/hotkey floating window, or on a History row
2. Click the **stack icon** in the popover footer to open the Anki list - the badge shows how many cards haven't been exported yet
3. Click **Export N new cards** - Sig writes `Sig-Anki-<date>.txt` (or `.tsv`, set in Settings → Anki) to your Downloads folder and reveals it in Finder
4. In **Anki**, choose **File → Import** and pick the file - the deck (`Dansk::fraSig` by default) and the Basic note type are preselected

**How cards look:**
- Front: the Danish text. Back: the English text, plus the IPA pronunciation when espeak-ng is installed (toggle in Settings → Anki)
- Cards are always Danish → English, whichever direction you translated
- Each card is tagged `fraSig`

**Good to know:**
- Bookmarks are kept separately from History, so they survive History being off or cleared
- Exported cards stay in the list (dimmed) and aren't exported again unless you hover one and click **Export again** (↩) - the next export then updates that card in Anki instead of duplicating it. Use **Clear exported** to tidy the list - it doesn't touch Anki
- Each card carries a stable ID, so re-importing it updates the existing note instead of adding a duplicate (with Anki's default import options)
- Change the target deck in Settings → Anki (use `::` for subdecks)
- Needs Anki 2.1.55 or later. If your Basic note type has a different name (Anki localizes it), pick it in the import dialog

### System-Wide Translation Service (NEW in v1.5)

The app now includes a macOS Service that lets you translate text from anywhere:

1. **Select text** in any application (Safari, Chrome, TextEdit, Mail, etc.)
2. **Right-click** on the selected text
3. **Choose "Translate with BMO"** from the Services submenu
4. A **floating window** will appear with the translation
5. Click the **Copy button** to copy the translation to clipboard
6. The window auto-dismisses after a configurable timeout (default 15 seconds; set in Settings → Translation Window)

**Features:**
- Auto-detects language direction (Danish ↔ English)
- Works system-wide in any macOS app
- Non-intrusive floating window display
- Handles text up to 5000 characters
- Shows error notifications if translation fails

**Enabling the Service (REQUIRED):**

⚠️ **Important:** macOS services are disabled by default. You MUST enable the service manually:

1. Open **System Settings** → **Keyboard** → **Keyboard Shortcuts** → **Services**
2. Scroll to find **"Translate with BMO"** under the **Text** section
3. **Check the box** to enable it
4. The service will now appear in right-click menus

If the service doesn't appear in System Settings after installation:
- Make sure the app is in `/Applications/` folder
- Run `/System/Library/CoreServices/pbs -flush` in Terminal to refresh the services database
- Restart the app

## Development

### Project Structure

```
BMO/
├── Sources/
│   ├── BMO/                           # Executable target (entry point only)
│   │   └── BMO.swift
│   └── BMOLib/                        # Library target — all logic and SwiftUI views
│       ├── AppDelegate.swift          # Menu bar / NSPopover setup
│       ├── TranslatorView.swift       # SwiftUI interface
│       ├── TranslationService.swift   # Translation logic
│       ├── URLSessionNetworkClient.swift # DeepL API client
│       ├── Configuration.swift        # API configuration
│       ├── ServiceProvider.swift      # macOS Services menu integration
│       ├── TranslationResultWindow.swift # Floating result window for Services
│       ├── HotkeyMonitor.swift        # Global hotkey support
│       ├── AppSettings.swift          # User-facing settings
│       ├── SettingsView.swift         # Settings UI
│       ├── AnkiCard.swift             # Anki card model + bookmark list rules
│       ├── AnkiExporter.swift         # Anki text-import file + export flow
│       └── AnkiListView.swift         # Anki list UI
├── Tests/BMOTests/
│   ├── TranslationServiceTests.swift             # Unit tests (mocked network)
│   ├── TranslationServiceIntegrationTests.swift  # Integration tests (real API)
│   └── Anki*Tests.swift                          # Anki card, list, and export-format tests
└── Package.swift
```

### Running in Xcode

To develop in Xcode:

1. Open the project:
   ```bash
   open Package.swift
   ```

2. Configure the environment variable:
   - Click on the scheme selector (next to Run/Stop buttons)
   - Select "Edit Scheme..."
   - Select "Run" in the left sidebar
   - Go to the "Arguments" tab
   - Under "Environment Variables", add:
     - Name: `DEEPL_API_KEY`
     - Value: `your-api-key-here`

3. Run the project (⌘+R)

**Note:** You may see a warning "Cannot index window tabs due to missing main bundle identifier" - this is harmless and can be ignored. It appears because SPM executables don't have bundle identifiers like full app bundles do.

### Real-Time UI Development with Xcode Previews

For instant UI feedback while editing SwiftUI views:

1. Open `TranslatorView.swift` in Xcode (located in `Sources/BMOLib/`)
2. Enable the Canvas:
   - Press **⌥⌘↩** (Option-Command-Return), or
   - Click **Editor → Canvas** in the menu
3. The preview will show your UI and **update automatically** as you type
4. You can interact with the preview to test different states

The preview uses a mock translation service, so you don't need an API key to see UI changes in real-time. This is perfect for:
- Adjusting layouts and spacing
- Tweaking colors and fonts
- Testing different UI states
- Experimenting with animations

**Tips:**
- If the preview stops updating, click "Resume" or press **⌥⌘P** (Option-Command-P)
- The SwiftUI views are in the `BMOLib` target (a library), which fully supports previews
- Previews work out of the box - no additional configuration needed!

### Running Tests

```bash
# Run unit tests only
swift test

# Run with integration tests (requires API key)
DEEPL_API_KEY=your-key ENABLE_INTEGRATION_TESTS=1 swift test
```

## Roadmap

Completed:
- [x] System-wide translation service (v1.5) - Right-click context menu translation
- [x] Popover pin toggle (v1.7) - Keep the popover open during long sessions instead of auto-dismissing on focus loss
- [x] Danish IPA pronunciation guide (v1.9) - Optional, requires `espeak-ng` (see Requirements)
- [x] Anki export (v1.10) - Bookmark translations and export them as Danish → English flashcards

Future versions may include:

- [ ] Translation history
- [ ] Send cards straight to Anki via AnkiConnect
- [ ] Dark mode support
- [ ] Global hotkey to show popover
- [ ] Example sentences
- [ ] More language pairs

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Powered by [DeepL API](https://www.deepl.com/pro-api)
- Built with SwiftUI and Swift Package Manager
- Icon: [Viking](https://thenounproject.com/browse/icons/term/viking/) by Cahya Kurniawan from Noun Project (CC BY 3.0)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

**Note**: This is a personal learning project created while learning Danish. Hej! 🇩🇰
