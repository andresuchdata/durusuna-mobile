# 🔒 Durusuna Mobile - Secure Development Makefile
# Provides easy commands for secure development setup

.PHONY: help configure configure-device configure-emulator run-device run-emulator run-a16 run-ios run-android-emu clean info

help: ## Show available commands
	@echo "🔒 Durusuna Mobile - Secure Development Commands"
	@echo "================================================"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "🔐 Security Features:"
	@echo "   - No hardcoded IPs in source code"
	@echo "   - Environment-based configuration"
	@echo "   - Automatic IP detection"
	@echo "   - Gitignored sensitive files"
	@echo ""
	@echo "📱 Quick Device Commands:"
	@echo "   make run-a16        - Samsung A16 (auto-config)"
	@echo "   make run-ios        - iOS Simulator"
	@echo "   make run-android-emu - Android Emulator"

# ============================================================================
# DIRECT DEVICE COMMANDS (Auto-configure, no prompts)
# ============================================================================

run-a16: ## Samsung A16 - Auto-configure and run on physical device
	$(eval LOCAL_IP := $(shell ifconfig en0 2>/dev/null | grep "inet " | awk '{print $$2}' | head -1))
	@echo "📱 Samsung A16 Configuration"
	@echo "============================"
	@echo "🔧 Auto-configuring for Samsung A16..."
	@echo "📍 Detected IP: $(LOCAL_IP)"
	@echo "USE_PHYSICAL_DEVICE=true" > .env.local
	@echo "DEV_SERVER_IP=$(LOCAL_IP)" >> .env.local
	@echo "DEV_SERVER_PORT=3001" >> .env.local
	@echo "ENVIRONMENT=development" >> .env.local
	@echo "DEBUG_MODE=true" >> .env.local
	@echo "DEVICE_TYPE=samsung_a16" >> .env.local
	@echo "✅ Configuration saved to .env.local"
	@echo "🚀 Starting app on Samsung A16..."
	@echo "📱 Device should connect to: http://$(LOCAL_IP):3001"
	@flutter run -d 'RR8Y201QSAX' --dart-define=USE_PHYSICAL_DEVICE=true --dart-define=DEV_SERVER_IP=$(LOCAL_IP) --dart-define=DEV_SERVER_PORT=3001 --dart-define=DEBUG_MODE=true

run-ios: ## iOS Simulator - Auto-configure and run
	@echo "🍎 iOS Simulator Configuration"
	@echo "============================="
	@echo "🔧 Auto-configuring for iOS Simulator..."
	@echo "USE_PHYSICAL_DEVICE=false" > .env.local
	@echo "DEV_SERVER_PORT=3001" >> .env.local
	@echo "ENVIRONMENT=development" >> .env.local
	@echo "DEBUG_MODE=true" >> .env.local
	@echo "DEVICE_TYPE=ios_simulator" >> .env.local
	@echo "✅ Configuration saved to .env.local"
	@echo "🚀 Starting app on iOS Simulator..."
	@flutter run -d 'iPhone 16 Pro' --dart-define=USE_PHYSICAL_DEVICE=false --dart-define=DEV_SERVER_PORT=3001 --dart-define=DEBUG_MODE=true

run-android-emu: ## Android Emulator - Auto-configure and run
	@echo "🤖 Android Emulator Configuration"
	@echo "================================="
	@echo "🔧 Auto-configuring for Android Emulator..."
	@echo "USE_PHYSICAL_DEVICE=false" > .env.local
	@echo "DEV_SERVER_PORT=3001" >> .env.local
	@echo "ENVIRONMENT=development" >> .env.local
	@echo "DEBUG_MODE=true" >> .env.local
	@echo "DEVICE_TYPE=android_emulator" >> .env.local
	@echo "✅ Configuration saved to .env.local"
	@echo "🚀 Starting app on Android Emulator..."
	@flutter run -d 'emulator-5554' --dart-define=USE_PHYSICAL_DEVICE=false --dart-define=DEV_SERVER_PORT=3001 --dart-define=DEBUG_MODE=true

run-physical: ## Any Physical Device - Auto-detect IP and configure
	$(eval LOCAL_IP := $(shell ifconfig en0 2>/dev/null | grep "inet " | awk '{print $$2}' | head -1))
	@echo "📱 Physical Device Configuration"
	@echo "==============================="
	@echo "🔧 Auto-configuring for physical device..."
	@echo "📍 Detected IP: $(LOCAL_IP)"
	@echo "USE_PHYSICAL_DEVICE=true" > .env.local
	@echo "DEV_SERVER_IP=$(LOCAL_IP)" >> .env.local
	@echo "DEV_SERVER_PORT=3001" >> .env.local
	@echo "ENVIRONMENT=development" >> .env.local
	@echo "DEBUG_MODE=true" >> .env.local
	@echo "DEVICE_TYPE=physical_device" >> .env.local
	@echo "✅ Configuration saved to .env.local"
	@echo "🚀 Starting app on connected physical device..."
	@echo "📱 Device should connect to: http://$(LOCAL_IP):3001"
	@flutter run --dart-define=USE_PHYSICAL_DEVICE=true --dart-define=DEV_SERVER_IP=$(LOCAL_IP) --dart-define=DEV_SERVER_PORT=3001 --dart-define=DEBUG_MODE=true

# ============================================================================
# INTERACTIVE CONFIGURATION COMMANDS
# ============================================================================

configure: ## Interactive configuration setup
	@chmod +x configure_dev.sh
	@./configure_dev.sh

configure-device: ## Configure for physical device testing
	$(eval LOCAL_IP := $(shell ifconfig en0 2>/dev/null | grep "inet " | awk '{print $$2}' | head -1))
	@echo "🔧 Configuring for physical device..."
	@echo "📱 Local IP detected: $(LOCAL_IP)"
	@echo "USE_PHYSICAL_DEVICE=true" > .env.local
	@echo "DEV_SERVER_IP=$(LOCAL_IP)" >> .env.local
	@echo "DEV_SERVER_PORT=3001" >> .env.local
	@echo "ENVIRONMENT=development" >> .env.local
	@echo "DEBUG_MODE=true" >> .env.local
	@echo "✅ Configuration saved to .env.local"

configure-emulator: ## Configure for emulator testing  
	@echo "🔧 Configuring for emulator..."
	@echo "USE_PHYSICAL_DEVICE=false" > .env.local
	@echo "DEV_SERVER_PORT=3001" >> .env.local
	@echo "ENVIRONMENT=development" >> .env.local
	@echo "DEBUG_MODE=true" >> .env.local
	@echo "✅ Configuration saved to .env.local"

run-device: configure-device ## Run app on physical device
	$(eval LOCAL_IP := $(shell ifconfig en0 2>/dev/null | grep "inet " | awk '{print $$2}' | head -1))
	@echo "🚀 Running on physical device..."
	@flutter run --dart-define=USE_PHYSICAL_DEVICE=true --dart-define=DEV_SERVER_IP=$(LOCAL_IP) --dart-define=DEV_SERVER_PORT=3001

run-emulator: configure-emulator ## Run app on emulator
	@echo "🚀 Running on emulator..."
	@flutter run --dart-define=USE_PHYSICAL_DEVICE=false --dart-define=DEV_SERVER_PORT=3001

run-debug: ## Run with debug information
	@echo "🐛 Running with debug info..."
	@flutter run --dart-define=DEBUG_MODE=true -v

# ============================================================================
# UTILITY COMMANDS
# ============================================================================

info: ## Show current configuration
	@echo "📋 Current Configuration:"
	@echo "========================"
	$(eval LOCAL_IP := $(shell ifconfig en0 2>/dev/null | grep "inet " | awk '{print $$2}' | head -1))
	@echo "Local IP: $(LOCAL_IP)"
	@echo "Environment files:"
	@if [ -f .env.local ]; then \
		echo "  ✅ .env.local exists"; \
		cat .env.local | grep -v "^#" | sed 's/^/     /'; \
	else \
		echo "  ❌ .env.local not found (run 'make configure')"; \
	fi

devices: ## List available devices
	@echo "📱 Available Devices:"
	@echo "===================="
	@flutter devices

clean: ## Clean environment configuration
	@echo "🧹 Cleaning configuration..."
	@rm -f .env.local
	@flutter clean
	@echo "✅ Configuration cleaned"

install: ## Install dependencies
	@echo "📦 Installing dependencies..."
	@flutter pub get
	@pod install --project-directory=ios/

build-release: ## Build release version (production)
	@echo "🏗️ Building release version..."
	@flutter build apk --dart-define=ENVIRONMENT=production

# Security checks
security-check: ## Check for security issues
	@echo "🔒 Security Check:"
	@echo "=================="
	@echo "Checking for hardcoded secrets..."
	@if grep -r "192\.168\|10\.0\.\|172\.16" lib/ --exclude-dir=.git 2>/dev/null | grep -v "// Example\|// TODO\|// Template"; then \
		echo "❌ Found potential hardcoded IPs"; \
	else \
		echo "✅ No hardcoded IPs found"; \
	fi
	@if [ -f .env.local ]; then \
		echo "✅ .env.local exists (good for development)"; \
	fi
	@if git check-ignore .env.local >/dev/null 2>&1; then \
		echo "✅ .env.local is properly gitignored"; \
	else \
		echo "⚠️  .env.local might not be gitignored"; \
	fi
