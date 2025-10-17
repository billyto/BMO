#!/bin/bash

# Create a fancy DMG with custom layout
# This creates a professional-looking installer like major Mac apps

set -e

APP_NAME="Sig"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="Sig-Installer"
VOLUME_NAME="Install Sig"
BACKGROUND_FILE="dmg-background.png"
DMG_TEMP="dmg_staging"
DMG_FINAL="${DMG_NAME}.dmg"

echo "🔨 Building ${APP_NAME}..."

# First, build the app
./build-app.sh

echo "📁 Preparing DMG contents..."

# Remove any existing DMG and temp directory
rm -rf "${DMG_TEMP}" "${DMG_FINAL}" "${DMG_NAME}-temp.dmg"

# Create staging directory
mkdir -p "${DMG_TEMP}"

# Copy app
echo "📦 Copying ${APP_BUNDLE}..."
cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"

# Create symbolic link to Applications
echo "🔗 Creating Applications symlink..."
ln -s /Applications "${DMG_TEMP}/Applications"

# Create README
cat > "${DMG_TEMP}/README.txt" << 'EOF'
Welcome to Sig! 🇩🇰

To install:
1. Drag Sig.app to the Applications folder
2. Open Terminal and run the setup script:
   cd ~/Developer/bmo/BMO && ./setup-env.sh
3. Launch Sig from Spotlight (⌘+Space, type "Sig")

This sets your DEEPL_API_KEY so the app can work properly.

For more info, visit: https://github.com/billyto/BMO
EOF

echo "💿 Creating temporary DMG..."

# Create a temporary DMG
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDRW \
    "${DMG_NAME}-temp.dmg"

# Mount the temporary DMG
echo "📌 Mounting DMG for customization..."
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
hdiutil attach "${DMG_NAME}-temp.dmg" -nobrowse

# Wait for mount
sleep 2

echo "🎨 Customizing DMG appearance..."

# Use AppleScript to set up the DMG window
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 650, 450}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set background picture of theViewOptions to file ".background:background.png"

        -- Position the app icon
        set position of item "${APP_BUNDLE}" of container window to {125, 150}

        -- Position the Applications link
        set position of item "Applications" of container window to {425, 150}

        -- Position README
        set position of item "README.txt" of container window to {275, 280}

        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Sync the volume
sync
sleep 2

echo "💾 Unmounting..."
hdiutil detach "${MOUNT_DIR}"

echo "🗜️  Converting to compressed DMG..."
hdiutil convert "${DMG_NAME}-temp.dmg" \
    -format UDZO \
    -o "${DMG_FINAL}"

echo "🧹 Cleaning up..."
rm -rf "${DMG_TEMP}" "${DMG_NAME}-temp.dmg"

echo ""
echo "✅ Fancy DMG created: ${DMG_FINAL}"
echo ""
echo "📦 The DMG includes:"
echo "   • Sig.app (drag to Applications)"
echo "   • Applications folder shortcut"
echo "   • README with setup instructions"
echo ""
echo "To test: open ${DMG_FINAL}"
echo "To distribute: Upload to GitHub Releases"
