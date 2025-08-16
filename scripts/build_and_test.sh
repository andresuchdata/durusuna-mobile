#!/bin/bash

echo "🚀 Starting Durusuna Mobile Build & Test Process..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "Visit: https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -1)"

# Clean and get dependencies
echo "🧹 Cleaning project..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

# Generate code
echo "🔧 Generating code..."
flutter packages pub run build_runner build --delete-conflicting-outputs

# Analyze code
echo "🔍 Analyzing code..."
flutter analyze

# Run tests
echo "🧪 Running tests..."
flutter test

# Check if everything is ready for running
echo "🏃 Checking if app can run..."
flutter doctor

echo "✨ Setup complete! You can now run:"
echo "   flutter run              # Run on default device"
echo "   flutter run -d android   # Run on Android"
echo "   flutter run -d ios       # Run on iOS"

# Optional: Ask if user wants to run the app
read -p "Do you want to run the app now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Running app..."
    flutter run
fi 