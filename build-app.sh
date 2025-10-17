#!/bin/bash

# Build script for Sig.app
# This creates a proper macOS app bundle

set -e

echo "🔨 Building Sig.app..."

# Build the release binary
echo "📦 Building release binary..."
swift build -c release

# Create app bundle structure
echo "📁 Creating app bundle structure..."
APP_DIR="Sig.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy the binary and rename it to Sig
echo "📋 Copying binary..."
cp .build/release/BMO "$APP_DIR/Contents/MacOS/Sig"

# Copy Info.plist
echo "📋 Copying Info.plist..."
cp Info.plist "$APP_DIR/Contents/Info.plist"

# Copy app icon if it exists
if [ -f "AppIcon.icns" ]; then
    echo "🎨 Copying app icon..."
    cp AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Make the binary executable
chmod +x "$APP_DIR/Contents/MacOS/Sig"

echo "✅ Sig.app created successfully!"
echo ""
echo "To install:"
echo "  cp -r Sig.app /Applications/"
echo ""
echo "To test:"
echo "  open Sig.app"
