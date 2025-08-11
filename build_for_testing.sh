#!/bin/bash

echo "🔧 Building APK for Private Testing (No Play Store Required)"
echo "🎯 Optimized for modern Android devices (8.0+)"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
cd android
./gradlew clean
cd ..

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build architecture-specific APKs (better device compatibility)
echo "🏗️ Building architecture-specific APKs for better compatibility..."
flutter build apk --release --split-per-abi

# Build universal APK as backup
echo "🌐 Building universal APK as backup..."
flutter build apk --release

# Create distribution folder
DIST_DIR="testing_apks"
rm -rf $DIST_DIR
mkdir -p $DIST_DIR

# Copy APKs to distribution folder
echo "📋 Organizing APKs for distribution..."
cp build/app/outputs/apk/release/app-release.apk $DIST_DIR/durusuna-universal.apk
cp build/app/outputs/apk/release/app-arm64-v8a-release.apk $DIST_DIR/durusuna-arm64-v8a.apk 2>/dev/null || echo "ARM64 APK not found"
cp build/app/outputs/apk/release/app-armeabi-v7a-release.apk $DIST_DIR/durusuna-armeabi-v7a.apk 2>/dev/null || echo "ARM APK not found"

# Get APK info
APK_SIZE=$(du -h $DIST_DIR/durusuna-universal.apk | cut -f1)
APK_COUNT=$(ls -1 $DIST_DIR/*.apk | wc -l)

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "📱 Private Testing APKs ready in: $DIST_DIR/"
echo "   📊 Total APKs: $APK_COUNT"
echo "   📏 Universal APK size: $APK_SIZE"
echo ""
echo "🎯 RECOMMENDED FOR MODERN ANDROID:"
echo "   1. Try: durusuna-arm64-v8a.apk (most compatible)"
echo "   2. Fallback: durusuna-universal.apk"
echo ""
echo "📱 DISTRIBUTION OPTIONS:"
echo "   • Email/WhatsApp: Send APK files directly"
echo "   • Cloud storage: Upload to Google Drive/Dropbox"
echo "   • USB transfer: Copy to device storage"
echo "   • ADB install: adb install $DIST_DIR/durusuna-arm64-v8a.apk"
echo ""
echo "🔧 ANDROID INSTALLATION GUIDE:"
echo "   1. Settings > Security > Install from Unknown Sources (Enable)"
echo "   2. Download APK to device"
echo "   3. Open with File Manager"
echo "   4. Tap Install and Allow permissions"
echo "   5. If installation fails: restart device and try again"
echo ""
echo "🚫 NO PLAY STORE NEEDED - Direct installation only!"
