plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.durusuna_mobile"
    compileSdk = flutter.compileSdkVersion
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
        minSdk = 23  // Android 6.0 for maximum compatibility including Samsung A22
        targetSdk = 34  // Latest stable Android version
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex for Samsung A22 compatibility
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // Optimize for Samsung A22 release builds
            isMinifyEnabled = false  // Disable to avoid issues on Samsung devices
            isShrinkResources = false
            
            // Keep debugging info for Samsung-specific issues
            isDebuggable = false
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
