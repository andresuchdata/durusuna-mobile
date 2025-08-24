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

# First try building universal APK (more reliable)
echo "🌐 Building universal APK first..."
if flutter build apk --release; then
    echo "✅ Universal APK built successfully!"
    
    # Now try building architecture-specific APKs
    echo "🏗️ Building architecture-specific APKs for better compatibility..."
    if flutter build apk --release --split-per-abi; then
        echo "✅ Split APKs built successfully!"
    else
        echo "⚠️ Split APKs failed, but universal APK is ready"
    fi
else
    echo "❌ Universal APK build failed"
    exit 1
fi

# Create distribution folder
DIST_DIR="testing_apks"
rm -rf $DIST_DIR
mkdir -p $DIST_DIR

# Copy APKs to distribution folder
echo "📋 Organizing APKs for distribution..."
cp build/app/outputs/apk/release/app-release.apk $DIST_DIR/durusuna-universal.apk

# Try to copy split APKs if they exist
if [ -f "build/app/outputs/apk/release/app-arm64-v8a-release.apk" ]; then
    cp build/app/outputs/apk/release/app-arm64-v8a-release.apk $DIST_DIR/durusuna-arm64-v8a.apk
    echo "✅ ARM64 APK copied"
else
    echo "⚠️ ARM64 APK not found"
fi

if [ -f "build/app/outputs/apk/release/app-armeabi-v7a-release.apk" ]; then
    cp build/app/outputs/apk/release/app-armeabi-v7a-release.apk $DIST_DIR/durusuna-armeabi-v7a.apk
    echo "✅ ARM APK copied"
else
    echo "⚠️ ARM APK not found"
fi

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
if [ -f "$DIST_DIR/durusuna-arm64-v8a.apk" ]; then
    echo "   1. Try: durusuna-arm64-v8a.apk (most compatible)"
    echo "   2. Fallback: durusuna-universal.apk"
else
    echo "   📱 Use: durusuna-universal.apk (universal compatibility)"
fi
echo ""
echo "📱 DISTRIBUTION OPTIONS:"
echo "   • Email/WhatsApp: Send APK files directly"
echo "   • Cloud storage: Upload to Google Drive/Dropbox"
echo "   • USB transfer: Copy to device storage"
echo "   • ADB install: adb install $DIST_DIR/durusuna-universal.apk"
echo ""
echo "🔧 ANDROID INSTALLATION GUIDE:"
echo "   1. Settings > Security > Install from Unknown Sources (Enable)"
echo "   2. Download APK to device"
echo "   3. Open with File Manager"
echo "   4. Tap Install and Allow permissions"
echo "   5. If installation fails: restart device and try again"
echo ""
echo "🚫 NO PLAY STORE NEEDED - Direct installation only!"
