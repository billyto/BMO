# Sig - Danish-English Translator

A lightweight macOS menu bar app for quick Danish ↔ English translations using DeepL API.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.3-green)

## Features

- 🪖 Lives in your menu bar for quick access
- 🇩🇰 ↔ 🇬🇧 Bidirectional Danish-English translation
- ⚡ Fast translations powered by DeepL API
- 🎨 Clean, modern SwiftUI interface
- ⌨️ Keyboard shortcuts (⌘+Return to translate, ⌘+K to clear)
- 🔄 Clickable language swap
- 🔊 Text-to-speech for Danish pronunciation
- 🎯 Proper macOS app bundle for easy installation

## Screenshots

![BMO Translator Interface](screenshot.png)

## Requirements

- macOS 14.0 or later
- DeepL API key (free tier available: 500,000 characters/month)

## Installation

### Prerequisites

1. **Get a DeepL API Key** (Required)
   - Sign up for a free DeepL API account at [https://www.deepl.com/pro-api](https://www.deepl.com/pro-api)
   - Free tier includes 500,000 characters/month
   - Copy your API key

2. **Set API Key as Environment Variable**

   Add to your `~/.zshrc`:
   ```bash
   export DEEPL_API_KEY="your-api-key-here"
   ```

   Then reload your shell:
   ```bash
   source ~/.zshrc
   ```

### Option 1: Install as macOS App (Recommended)

```bash
# Clone the repository
git clone https://github.com/billyto/BMO.git
cd BMO

# Build the app bundle
./build-app.sh

# Setup environment for GUI apps (IMPORTANT!)
./setup-env.sh

# Install to Applications folder
cp -r Sig.app /Applications/

# Launch the app
open /Applications/Sig.app
```

Now you can:
- Launch Sig from Spotlight (⌘+Space, type "Sig")
- Add to your Dock
- Set to launch at login (System Settings → General → Login Items)

**Important:** After each system restart, run:
```bash
cd ~/Developer/bmo/BMO && ./setup-env.sh
```

This ensures GUI apps can access your API key.

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

1. Click the viking helmet icon (🪖) in your menu bar
2. Type or paste Danish or English text
3. Click "Translate" or press ⌘+Return
4. Click the language indicator (🇩🇰 Danish → 🇬🇧 English) to swap direction
5. Press ⌘+K to clear all text
6. Click the speaker icon to hear Danish pronunciation
7. Click the power icon to quit the app

## Development

### Project Structure

```
BMO/
├── Sources/BMO/
│   ├── BMO.swift                      # Main app entry point
│   ├── AppDelegate.swift              # Menu bar setup
│   ├── TranslatorView.swift           # SwiftUI interface
│   ├── TranslationService.swift       # Translation logic
│   ├── URLSessionNetworkClient.swift  # DeepL API client
│   └── Configuration.swift            # API configuration
├── Tests/
│   └── BMOTests/
│       ├── TranslationServiceTests.swift          # Unit tests
│       └── TranslationServiceIntegrationTests.swift # Integration tests
└── Package.swift
```

### Running Tests

```bash
# Run unit tests only
swift test

# Run with integration tests (requires API key)
DEEPL_API_KEY=your-key ENABLE_INTEGRATION_TESTS=1 swift test
```

## Roadmap

Future versions may include:

- [ ] Translation history
- [ ] Favorite translations
- [ ] Dark mode support
- [ ] Global hotkey to show popover
- [ ] Pronunciation guide (IPA)
- [ ] Example sentences
- [ ] More language pairs

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Powered by [DeepL API](https://www.deepl.com/pro-api)
- Built with SwiftUI and Swift Package Manager
- Viking helmet icon from SF Symbols

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

**Note**: This is a personal learning project created while learning Danish. Hej! 🇩🇰
