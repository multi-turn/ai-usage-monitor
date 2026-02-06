#!/bin/bash
set -e

APP_NAME="AI Usage Monitor"
BUNDLE_ID="com.aiusagemonitor"
VERSION="${1:-1.0.0}"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SIGNING_IDENTITY="Developer ID Application: Multi-turn Inc. (8V3Z27Z6RY)"

echo "🔨 Building AI Usage Monitor v$VERSION..."

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Resources/Scripts"

cp "$BUILD_DIR/AIUsageMonitor" "$APP_BUNDLE/Contents/MacOS/"

if [ -f "Sources/AIUsageMonitor/Resources/Scripts/updater.sh" ]; then
    cp "Sources/AIUsageMonitor/Resources/Scripts/updater.sh" "$APP_BUNDLE/Contents/Resources/Scripts/"
    chmod +x "$APP_BUNDLE/Contents/Resources/Scripts/updater.sh"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>AIUsageMonitor</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>SUFeedURL</key>
    <string>https://github.com/multi-turn/ai-usage-monitor/releases/latest/download/appcast.xml</string>
</dict>
</plist>
EOF

echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "✅ App bundle created: $APP_BUNDLE"

echo "🔐 Signing app with Developer ID..."
codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
codesign --verify --verbose "$APP_BUNDLE"
echo "✅ App signed successfully"

DMG_NAME="AIUsageMonitor-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "📦 Creating DMG..."
rm -f "$DMG_PATH"

DMG_TEMP="$BUILD_DIR/dmg-temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_TEMP"

echo "🔐 Signing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"
echo "✅ DMG signed successfully"

echo "✅ DMG created: $DMG_PATH"
echo ""
echo "📋 Release files:"
ls -lh "$BUILD_DIR"/*.dmg 2>/dev/null || true

echo ""
echo "🚀 To notarize (optional), run:"
echo "   xcrun notarytool submit \"$DMG_PATH\" --apple-id YOUR_APPLE_ID --team-id 8V3Z27Z6RY --password YOUR_APP_PASSWORD --wait"
echo "   xcrun stapler staple \"$DMG_PATH\""
