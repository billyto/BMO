#!/bin/bash

# Setup script for Sig - Sets environment variables for macOS GUI apps
# This ensures the app can access DEEPL_API_KEY when launched from Finder/Spotlight

# Read API key from shell environment
if [ -z "$DEEPL_API_KEY" ]; then
    echo "❌ Error: DEEPL_API_KEY not found in shell environment"
    echo ""
    echo "Please set it in your ~/.zshrc:"
    echo "  export DEEPL_API_KEY=\"your-api-key-here\""
    echo ""
    echo "Then reload your shell:"
    echo "  source ~/.zshrc"
    echo ""
    echo "And run this script again."
    exit 1
fi

# Set the environment variable for launchd (used by GUI apps)
launchctl setenv DEEPL_API_KEY "$DEEPL_API_KEY"

# Verify it was set
if [ "$(launchctl getenv DEEPL_API_KEY)" = "$DEEPL_API_KEY" ]; then
    echo "✅ DEEPL_API_KEY set successfully for GUI apps"
    echo ""
    echo "You can now launch Sig.app from:"
    echo "  - Spotlight (⌘+Space)"
    echo "  - Applications folder"
    echo "  - Dock"
    echo ""
    echo "⚠️  Note: You'll need to run this script after each restart"
    echo "   OR add it to your login items to run automatically."
else
    echo "❌ Failed to set environment variable"
    exit 1
fi
