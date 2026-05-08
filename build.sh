#!/bin/bash

# Build script for Visual PM2 GUI

PROJECT_DIR="/Users/douba/Projects/XM/project/pm2-swift"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="VisualPM2GUI"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "🔨 Building Visual PM2 GUI..."
echo ""

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile Swift files
echo "📝 Compiling Swift files..."
SWIFT_FILES=(
    "VisualPM2GUI/Models/PM2Project.swift"
    "VisualPM2GUI/Models/PortPool.swift"
    "VisualPM2GUI/Models/AppConfig.swift"
    "VisualPM2GUI/Models/AppState.swift"
    "VisualPM2GUI/Models/DesignSystem.swift"
    "VisualPM2GUI/Services/PM2Service.swift"
    "VisualPM2GUI/Views/StatusBarMenu.swift"
    "VisualPM2GUI/Views/ProjectMenuItem.swift"
    "VisualPM2GUI/Views/LogsView.swift"
    "VisualPM2GUI/Views/SettingsView.swift"
    "VisualPM2GUI/VisualPM2GUIApp.swift"
)

SWIFT_CMD=""
for file in "${SWIFT_FILES[@]}"; do
    SWIFT_CMD+="$PROJECT_DIR/$file "
done

# Build using swiftc
cd "$PROJECT_DIR"
swiftc -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    $SWIFT_CMD \
    -framework SwiftUI \
    -framework Cocoa \
    -framework AppKit \
    -framework Foundation \
    -target arm64-apple-macosx14.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path)

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
else
    echo "❌ Compilation failed!"
    exit 1
fi

# Copy Info.plist
cp "$PROJECT_DIR/VisualPM2GUI/Info.plist" "$APP_BUNDLE/Contents/"

# Copy scripts (for pm2_wrapper.js)
echo "📦 Copying scripts..."
mkdir -p "$APP_BUNDLE/Contents/Resources/scripts"
cp -r "$PROJECT_DIR/scripts"/* "$APP_BUNDLE/Contents/Resources/scripts/"
if [ -d "$PROJECT_DIR/scripts/node_modules" ]; then
    cp -r "$PROJECT_DIR/scripts/node_modules" "$APP_BUNDLE/Contents/Resources/scripts/"
    echo "  ✅ node_modules copied"
fi

# Set executable permissions
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo ""
echo "✅ Build complete!"
echo "📦 App location: $APP_BUNDLE"
echo ""
echo "To run the app:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "Or from command line:"
echo "  \"$APP_BUNDLE/Contents/MacOS/$APP_NAME\""
