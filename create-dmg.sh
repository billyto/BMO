#!/bin/bash

# Create DMG installer for Sig
# This creates a visual installer like professional Mac apps

set -e

APP_NAME="Sig"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="Sig-Installer"
VOLUME_NAME="Sig Installer"
BACKGROUND_FILE="dmg-background.png"

echo "🔨 Building ${APP_NAME}..."

# First, build the app
./build-app.sh

# Create a temporary directory for DMG contents
echo "📁 Creating DMG staging directory..."
DMG_DIR="dmg_temp"
rm -rf "${DMG_DIR}"
mkdir -p "${DMG_DIR}"

# Copy the app bundle
echo "📦 Copying ${APP_BUNDLE}..."
cp -R "${APP_BUNDLE}" "${DMG_DIR}/"

# Create a symbolic link to Applications folder
echo "🔗 Creating Applications symlink..."
ln -s /Applications "${DMG_DIR}/Applications"

# Create a simple README for the DMG
echo "📝 Creating README..."
cat > "${DMG_DIR}/README.txt" << 'EOF'
Sig - Danish-English Translator
================================

IMPORTANT: Before first use, you must set up the environment:

1. Open Terminal
2. Run: cd ~/Developer/bmo/BMO && ./setup-env.sh
   (Or wherever you cloned the repository)

This sets your DEEPL_API_KEY so Sig can access it.

Installation:
1. Drag Sig.app to the Applications folder
2. Run the setup-env.sh script (see above)
3. Launch Sig from Spotlight (⌘+Space, type "Sig")

Usage:
- Click the viking helmet icon in your menu bar
- Translate between Danish and English
- Use ⌘+Return to translate
- Use ⌘+K to clear

Enjoy! 🇩🇰
EOF

# Remove any existing DMG
echo "🗑️  Removing old DMG if exists..."
rm -f "${DMG_NAME}.dmg"

# Create the DMG
echo "💿 Creating DMG..."
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

# Clean up
echo "🧹 Cleaning up..."
rm -rf "${DMG_DIR}"

echo ""
echo "✅ DMG created successfully: ${DMG_NAME}.dmg"
echo ""
echo "To distribute:"
echo "  1. Upload ${DMG_NAME}.dmg to GitHub releases"
echo "  2. Users double-click the DMG"
echo "  3. Users drag Sig.app to Applications"
echo ""
echo "To test locally:"
echo "  open ${DMG_NAME}.dmg"
