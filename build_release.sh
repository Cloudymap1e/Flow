#!/bin/bash

# Build Flow app in Release configuration for macOS
# This script cleans, builds, and prepares the app for distribution

set -e  # Exit on error

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="Flow"
SCHEME="Flow"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="$BUILD_DIR/Release"

echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"

echo "🏗️  Building $PROJECT_NAME in $CONFIGURATION configuration..."
xcodebuild \
    -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'platform=macOS' \
    clean build

echo "✅ Build completed successfully!"
echo "📦 App location: $BUILD_DIR/Build/Products/$CONFIGURATION/$PROJECT_NAME.app"

# Verify the app was built
if [ -d "$BUILD_DIR/Build/Products/$CONFIGURATION/$PROJECT_NAME.app" ]; then
    echo "✓ App bundle created successfully"
    
    # Show code signing information
    echo ""
    echo "🔐 Code signing information:"
    codesign -dv "$BUILD_DIR/Build/Products/$CONFIGURATION/$PROJECT_NAME.app" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier"
else
    echo "❌ Error: App bundle not found"
    exit 1
fi
