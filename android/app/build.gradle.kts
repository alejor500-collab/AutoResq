plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.autoresq.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Google Cloud Android OAuth must include this package and every signing SHA-1.
        // Current local debug SHA-1: AD:AC:FF:A1:8B:21:7C:AA:12:4A:00:A6:1C:BA:B5:33:0B:77:C0:F5.
        applicationId = "com.autoresq.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("autoresqFixed") {
            // Fixed debug-compatible certificate registered in Google OAuth.
            // SHA-1: AD:AC:FF:A1:8B:21:7C:AA:12:4A:00:A6:1C:BA:B5:33:0B:77:C0:F5
            storeFile = file("autoresq-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("autoresqFixed")
        }

        release {
            signingConfig = signingConfigs.getByName("autoresqFixed")
        }
    }
}

flutter {
    source = "../.."
}
