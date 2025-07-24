# 🏗️ Build Scripts for Environment-Based Configuration

## 📱 Building for Different Environments

### **Development (Local Backend)**
```bash
# Default - uses local backend
flutter run

# Or explicitly set development
flutter run --dart-define=ENVIRONMENT=development
```

### **Staging (Test Backend)**
```bash
flutter run --dart-define=ENVIRONMENT=staging
flutter build apk --dart-define=ENVIRONMENT=staging
flutter build ios --dart-define=ENVIRONMENT=staging
```

### **Production (Live Backend)**
```bash
flutter run --dart-define=ENVIRONMENT=production
flutter build apk --dart-define=ENVIRONMENT=production --release
flutter build ios --dart-define=ENVIRONMENT=production --release
```

## 🔐 Security Best Practices

### **1. Repository Security**
- ✅ **Keep repo private** if you're exposing any backend URLs
- ✅ **Use environment variables** for sensitive data
- ✅ **Never commit API keys** or secrets

### **2. Advanced Security (Optional)**
- Use CI/CD to inject URLs at build time
- Store URLs in secure app configuration
- Use different app bundles for different environments

### **3. Git Security**
```bash
# Add to .gitignore
lib/core/constants/api_secrets.dart
.env
*.env
```

## 📋 Quick Commands

```bash
# Development (your current setup)
flutter run

# Test with Sevalla backend
flutter run --dart-define=ENVIRONMENT=production

# Build for app store
flutter build ios --dart-define=ENVIRONMENT=production --release
``` 