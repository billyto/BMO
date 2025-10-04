# BMO - Danish-English Translator

A lightweight macOS menu bar app for quick Danish ↔ English translations using DeepL API.

![BMO Icon](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 🪖 Lives in your menu bar for quick access
- 🇩🇰 ↔ 🇬🇧 Bidirectional Danish-English translation
- ⚡ Fast translations powered by DeepL API
- 🎨 Clean SwiftUI interface
- ⌨️ Keyboard shortcut (⌘+Return to translate)
- 🔄 Easy language swap button

## Screenshots

![BMO Translator Interface](screenshot.png)

## Requirements

- macOS 14.0 or later
- DeepL API key (free tier available: 500,000 characters/month)

## Installation

### Get a DeepL API Key

1. Sign up for a free DeepL API account at [https://www.deepl.com/pro-api](https://www.deepl.com/pro-api)
2. Copy your API key

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/BMO.git
cd BMO

# Build the app
swift build -c release

# Run with your API key
DEEPL_API_KEY=your-api-key-here .build/release/BMO
```

### Set API Key as Environment Variable (Optional)

Add to your `~/.zshrc` or `~/.bash_profile`:

```bash
export DEEPL_API_KEY="your-api-key-here"
```

## Usage

1. Click the viking helmet icon (🪖) in your menu bar
2. Type or paste Danish or English text
3. Click "Translate" or press ⌘+Return
4. Copy the translation result
5. Use the swap button (↔) to switch language direction

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
