#!/bin/bash

# Create a .dmg file for Flow app distribution
# This script packages the built app into a distributable DMG

set -e  # Exit on error

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="Flow"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/$PROJECT_NAME.app"
DMG_NAME="${PROJECT_NAME}-v1.0"
TEMP_DMG_DIR="$BUILD_DIR/dmg_temp"
FINAL_DMG="$PROJECT_DIR/${DMG_NAME}.dmg"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    echo "Please run build_release.sh first"
    exit 1
fi

echo "📦 Creating DMG for $PROJECT_NAME..."

# Clean up previous DMG artifacts
rm -rf "$TEMP_DMG_DIR"
rm -f "$FINAL_DMG"

# Create temporary directory for DMG contents
mkdir -p "$TEMP_DMG_DIR"

# Copy app to temp directory
echo "📋 Copying app to temporary directory..."
cp -R "$APP_PATH" "$TEMP_DMG_DIR/"

# Create symbolic link to Applications folder
echo "🔗 Creating Applications symlink..."
ln -s /Applications "$TEMP_DMG_DIR/Applications"

# Create the DMG
echo "💿 Creating DMG file..."
hdiutil create \
    -volname "$PROJECT_NAME" \
    -srcfolder "$TEMP_DMG_DIR" \
    -ov \
    -format UDZO \
    "$FINAL_DMG"

# Clean up temp directory
rm -rf "$TEMP_DMG_DIR"

echo "✅ DMG created successfully!"
echo "📍 Location: $FINAL_DMG"

# Show DMG info
FILESIZE=$(du -h "$FINAL_DMG" | cut -f1)
echo "📊 Size: $FILESIZE"

# Verify the DMG
echo ""
echo "🔍 Verifying DMG..."
if hdiutil verify "$FINAL_DMG" > /dev/null 2>&1; then
    echo "✓ DMG verification passed"
else
    echo "⚠️  DMG verification failed"
    exit 1
fi
