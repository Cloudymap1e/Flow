#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
TARGET_DIR="$PROJECT_DIR/build/Build/Products/Release"
APP_NAME="Flow"
APP_BUNDLE="$TARGET_DIR/$APP_NAME.app"
ASSETS_PATH="$PROJECT_DIR/Assets.xcassets"

echo "📦 Packaging $APP_NAME..."

# Create target directory
mkdir -p "$TARGET_DIR"

# Create App Bundle Structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Binary
echo "📋 Copying binary..."
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Resources (Bundle)
if [ -d "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" ]; then
    echo "📋 Copying resources bundle..."
    cp -R "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_BUNDLE/Contents/Resources/"
fi

# Copy Data (CSV)
CSV_FILE="$PROJECT_DIR/63324f7cdc3d.360_20190409180625.csv"
if [ -f "$CSV_FILE" ]; then
    echo "📊 Copying default data..."
    cp "$CSV_FILE" "$APP_BUNDLE/Contents/Resources/default_data.csv"
fi

# Compile Assets (App Icon)
if [ -d "$ASSETS_PATH" ]; then
    echo "🎨 Compiling assets..."
    xcrun actool "$ASSETS_PATH" \
        --compile "$APP_BUNDLE/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 13.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$TARGET_DIR/assetcatalog_generated_info.plist"
else
    echo "⚠️ Assets.xcassets not found, skipping icon generation."
fi

# Create Info.plist
echo "📝 Creating Info.plist..."
# Merge the generated plist from actool if it exists, otherwise use basic one
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.Flow</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

echo "✅ App bundle created at $APP_BUNDLE"

# Run create_dmg.sh
echo "💿 Running create_dmg.sh..."
./create_dmg.sh
