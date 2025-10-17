#!/bin/bash

# Script to convert menubar-icon.pdf to app icon (.icns)

set -e

echo "🎨 Creating app icon from menubar-icon.pdf..."

# Check if source PDF exists
if [ ! -f "Sources/BMOLib/Resources/menubar-icon.pdf" ]; then
    echo "❌ Error: menubar-icon.pdf not found in Sources/BMOLib/Resources/"
    exit 1
fi

# Create temporary directory for icon sizes
ICONSET_DIR="AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# First convert PDF to a high-res PNG
echo "📐 Converting PDF to PNG..."
TEMP_PNG="temp_icon.png"
sips -s format png Sources/BMOLib/Resources/menubar-icon.pdf --out "$TEMP_PNG" 2>&1 | grep -v "Warning:"

# Function to create icon with white background using Core Image filter
create_icon_with_background() {
    local size=$1
    local output=$2

    # Use sips to convert and flatten in one step
    # The -s format jpeg temporarily converts to JPEG (which doesn't support transparency)
    # then back to PNG, which forces the transparent areas to become white
    sips -z $size $size "$TEMP_PNG" -s format jpeg --out "${output%.png}.jpg" 2>&1 | grep -v "Warning:" | grep -v "Error:" || true
    sips -s format png "${output%.png}.jpg" --out "$output" 2>&1 | grep -v "Warning:" || true
    rm -f "${output%.png}.jpg"
}

# Generate different sizes from the high-res PNG
# macOS requires these specific sizes
echo "📐 Generating icon sizes with white background..."

create_icon_with_background 16 "$ICONSET_DIR/icon_16x16.png"
create_icon_with_background 32 "$ICONSET_DIR/icon_16x16@2x.png"
create_icon_with_background 32 "$ICONSET_DIR/icon_32x32.png"
create_icon_with_background 64 "$ICONSET_DIR/icon_32x32@2x.png"
create_icon_with_background 128 "$ICONSET_DIR/icon_128x128.png"
create_icon_with_background 256 "$ICONSET_DIR/icon_128x128@2x.png"
create_icon_with_background 256 "$ICONSET_DIR/icon_256x256.png"
create_icon_with_background 512 "$ICONSET_DIR/icon_256x256@2x.png"
create_icon_with_background 512 "$ICONSET_DIR/icon_512x512.png"
create_icon_with_background 1024 "$ICONSET_DIR/icon_512x512@2x.png"

# Convert to icns
echo "🔄 Converting to .icns format..."
iconutil -c icns "$ICONSET_DIR" -o AppIcon.icns

# Clean up
rm -rf "$ICONSET_DIR" "$TEMP_PNG"

echo "✅ AppIcon.icns created successfully!"
echo ""
echo "Now rebuild your app with ./build-app.sh"
