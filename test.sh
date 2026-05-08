#!/bin/bash

# Test script for Visual PM2 GUI
# Compiles and runs XCTest unit tests

PROJECT_DIR="/Users/douba/.qoder/worktree/pm2-swift/lFCali"
BUILD_DIR="$PROJECT_DIR/build"
TEST_BUNDLE="$BUILD_DIR/VisualPM2GUITests"
APP_NAME="VisualPM2GUI"

echo "🧪 Running Visual PM2 GUI Tests..."
echo ""

# Clean and create build directory
mkdir -p "$BUILD_DIR"

# Compile source files as a module
echo "📝 Compiling source files..."
SWIFT_SOURCES=(
    "$PROJECT_DIR/VisualPM2GUI/Models/PM2Project.swift"
    "$PROJECT_DIR/VisualPM2GUI/Models/PortPool.swift"
    "$PROJECT_DIR/VisualPM2GUI/Models/AppConfig.swift"
    "$PROJECT_DIR/VisualPM2GUI/Models/AppState.swift"
    "$PROJECT_DIR/VisualPM2GUI/Services/PM2Service.swift"
    "$PROJECT_DIR/VisualPM2GUI/Views/StatusBarMenu.swift"
    "$PROJECT_DIR/VisualPM2GUI/Views/ProjectMenuItem.swift"
    "$PROJECT_DIR/VisualPM2GUI/Views/LogsView.swift"
    "$PROJECT_DIR/VisualPM2GUI/Views/SettingsView.swift"
    "$PROJECT_DIR/VisualPM2GUI/VisualPM2GUIApp.swift"
)

# Compile as a module for @testable import
swiftc -emit-module -module-name "$APP_NAME" \
    -o "$BUILD_DIR/$APP_NAME.o" \
    "${SWIFT_SOURCES[@]}" \
    -framework SwiftUI \
    -framework Cocoa \
    -framework AppKit \
    -framework Foundation \
    -target arm64-apple-macosx14.0 \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -emit-objc-header \
    -parse-as-library 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Source compilation failed!"
    exit 1
fi
echo "✅ Source compilation successful!"

# Compile and run tests
echo "📝 Compiling test files..."
TEST_SOURCES=(
    "$PROJECT_DIR/Tests/VisualPM2GUITests/GroupManagementTests.swift"
)

TEST_RUNNER="$BUILD_DIR/test_runner"

swiftc -o "$TEST_RUNNER" \
    "${TEST_SOURCES[@]}" \
    -I "$BUILD_DIR" \
    -L "$BUILD_DIR" \
    -framework XCTest \
    -framework SwiftUI \
    -framework Cocoa \
    -framework AppKit \
    -framework Foundation \
    -target arm64-apple-macosx14.0 \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Test compilation failed!"
    echo ""
    echo "Note: Tests require @testable import which needs module compilation."
    echo "Try running with: xcodebuild test -scheme VisualPM2GUI"
    echo "Or open the project in Xcode and press Cmd+U."
    exit 1
fi

echo "✅ Test compilation successful!"
echo ""
echo "🚀 Running tests..."
"$TEST_RUNNER"

echo ""
echo "✅ Tests complete!"
