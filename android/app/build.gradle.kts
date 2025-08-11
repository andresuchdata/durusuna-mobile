plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.durusuna_mobile"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.durusuna_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26  // Android 8.0 - good balance of modern features and device coverage
        targetSdk = 35  // Match with compileSdk for consistency
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex for modern Android compatibility
        multiDexEnabled = true
        
        // Add ABI splits for better device compatibility
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // Optimize for modern Android devices release builds
            isMinifyEnabled = false  // Disable to avoid compatibility issues
            isShrinkResources = false
            
            // Keep debugging info for device-specific issues
            isDebuggable = false
            
            // Add ProGuard rules for Isar compatibility and modern Android support
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    
    // Split APKs by ABI for better compatibility with different devices
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a")
            isUniversalApk = true  // Also generate a universal APK
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Multidex support for Samsung A22
    implementation("androidx.multidex:multidex:2.0.1")
}
