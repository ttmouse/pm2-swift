#!/usr/bin/env python3
"""Generate Xcode project for Visual PM2 GUI"""

import os
import subprocess

project_dir = "/Users/douba/Projects/XM/project/pm2-swift"
os.chdir(project_dir)

# Create xcodeproj directory
os.makedirs("VisualPM2GUI.xcodeproj", exist_ok=True)

# Use xcodebuild to generate minimal project
try:
    # Try to use xcode-gen if available
    result = subprocess.run(
        ["xcodebuild", "-version"],
        capture_output=True,
        text=True
    )
    print(f"✅ Xcode found: {result.stdout.strip()}")
except Exception as e:
    print(f"❌ Xcode not found: {e}")
    exit(1)

# Create a simple Swift Package structure first
try:
    subprocess.run(
        ["swift", "package", "init", "--type", "executable", "--name", "VisualPM2GUI"],
        capture_output=True
    )
    print("✅ Swift package created")
except Exception as e:
    print(f"⚠️  Could not create Swift package: {e}")

print("📝 Please use Xcode to manually create the project:")
print("   1. Open Xcode")
print("   2. File → New → Project → macOS → App")
print("   3. Name: VisualPM2GUI")
print("   4. Interface: SwiftUI")
print("   5. Language: Swift")
print("   6. Save in: /Users/douba/Projects/XM/project/pm2-swift")
print("   7. Add all .swift files from VisualPM2GUI/ directory")
