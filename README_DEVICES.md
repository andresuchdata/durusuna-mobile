# 📱 Device Commands - Quick Reference

One-command setup and run for all your devices. **No configuration needed!**

## 🚀 Direct Device Commands

### Samsung A16 (Your Physical Device)
```bash
make run-a16
```
**What it does:**
- ✅ Auto-detects your Mac's IP address
- ✅ Configures for physical device
- ✅ Connects directly to Samsung A16 (`RR8Y201QSAX`)
- ✅ Starts the app with real-time messaging ready

### iOS Simulator
```bash
make run-ios
```
**What it does:**
- ✅ Configures for iOS Simulator
- ✅ Starts iPhone 16 Pro simulator
- ✅ Uses localhost connection

### Android Emulator
```bash
make run-android-emu
```
**What it does:**
- ✅ Configures for Android Emulator
- ✅ Uses emulator network (10.0.2.2)
- ✅ Starts on default emulator

### Any Physical Device
```bash
make run-physical
```
**What it does:**
- ✅ Auto-detects IP
- ✅ Runs on any connected physical device
- ✅ Perfect for other Android/iOS devices

## 🔧 Utility Commands

```bash
make help          # Show all commands
make info          # Show current configuration  
make devices       # List available devices
make clean         # Reset configuration
make security-check # Check for security issues
```

## 🎯 Your Most Common Command

For your **Samsung A16** development:
```bash
cd durusuna-mobile
make run-a16
```

That's it! One command and you're ready to debug with real-time messaging! 🎉

## 🔍 What Happens Behind the Scenes

When you run `make run-a16`:

1. **Finds your Mac's IP** automatically
2. **Creates secure config** (`.env.local` - gitignored)
3. **Sets environment variables**:
   - `USE_PHYSICAL_DEVICE=true`
   - `DEV_SERVER_IP=YOUR_IP`
   - `DEBUG_MODE=true`
4. **Starts the app** with all the right settings
5. **Your Samsung A16** connects to `http://YOUR_IP:3001`

## 🔄 Switching Between Devices

```bash
# Morning: Work on iOS
make run-ios

# Afternoon: Test on Samsung A16  
make run-a16

# Evening: Try Android emulator
make run-android-emu
```

Each command automatically reconfigures everything. **No manual setup ever needed!** ✨ 