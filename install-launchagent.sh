#!/bin/bash

# Installation script for BMO environment setup LaunchAgent
# This creates a LaunchAgent that automatically sets DEEPL_API_KEY at login

set -e

PLIST_NAME="com.bmo.envsetup.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_SOURCE="$(cd "$(dirname "$0")" && pwd)/$PLIST_NAME"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "=== BMO LaunchAgent Installer ==="
echo ""

# Verify source plist exists
if [ ! -f "$PLIST_SOURCE" ]; then
    echo "❌ Error: $PLIST_NAME not found in current directory"
    exit 1
fi

# Verify DEEPL_API_KEY exists in .zshenv
if ! grep -q "DEEPL_API_KEY" ~/.zshenv 2>/dev/null; then
    echo "⚠️  Warning: DEEPL_API_KEY not found in ~/.zshenv"
    echo ""
    echo "Please add the following to ~/.zshenv:"
    echo "  export DEEPL_API_KEY=\"your-api-key-here\""
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCH_AGENTS_DIR"

# Unload existing agent if running
if launchctl list | grep -q "com.bmo.envsetup"; then
    echo "Unloading existing LaunchAgent..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# Copy plist to LaunchAgents directory
echo "Installing LaunchAgent to $PLIST_DEST..."
cp "$PLIST_SOURCE" "$PLIST_DEST"

# Set proper permissions
chmod 644 "$PLIST_DEST"

# Load the LaunchAgent
echo "Loading LaunchAgent..."
launchctl load "$PLIST_DEST"

# Verify it's running
if launchctl list | grep -q "com.bmo.envsetup"; then
    echo ""
    echo "✅ LaunchAgent installed and loaded successfully!"
    echo ""
    echo "The DEEPL_API_KEY will now be automatically set:"
    echo "  • At every login"
    echo "  • Immediately (just ran it now)"
    echo ""

    # Verify the environment variable was set
    if [ -n "$(launchctl getenv DEEPL_API_KEY 2>/dev/null)" ]; then
        echo "✅ DEEPL_API_KEY is now available to GUI apps"
    else
        echo "⚠️  Warning: DEEPL_API_KEY not set. Check logs:"
        echo "     cat /tmp/bmo-envsetup.log"
        echo "     cat /tmp/bmo-envsetup.error.log"
    fi

    echo ""
    echo "You can now launch Sig.app from:"
    echo "  • Spotlight (⌘+Space)"
    echo "  • Applications folder"
    echo "  • Dock"
    echo ""
    echo "To uninstall, run:"
    echo "  launchctl unload ~/Library/LaunchAgents/$PLIST_NAME"
    echo "  rm ~/Library/LaunchAgents/$PLIST_NAME"
else
    echo "❌ Error: Failed to load LaunchAgent"
    echo "Check the logs:"
    echo "  cat /tmp/bmo-envsetup.log"
    echo "  cat /tmp/bmo-envsetup.error.log"
    exit 1
fi
