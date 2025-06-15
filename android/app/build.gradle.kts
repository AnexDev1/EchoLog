plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties") // Assumes key.properties is in the android directory
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
} else {
    println("WARNING: key.properties not found. Release build may not be signed.")
}

android {
    namespace = "com.anexon.echolog"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13113456" // Ensure this is the version you intend to use or remove if not needed
    // ndkVersion removed to avoid hardcoding; specify only if your project requires a specific NDK version
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.anexon.echolog"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = 5
        versionName = "v1.0.5"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists() && keystoreProperties.getProperty("storeFile") != null) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            } else {
                // This block will be entered if key.properties is missing or doesn't contain storeFile.
                // For a production release, you'd typically want the build to fail or have proper fallbacks.
                // For now, it will proceed but might not sign correctly if properties are missing.
                println("WARNING: Keystore properties not found or incomplete for release signingConfig.")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // The 'release' signingConfig is defined above and assigned here.
            signingConfig = signingConfigs.getByName("release")

            // You should also configure ProGuard/R8 for release builds
            isShrinkResources = true
            isMinifyEnabled = true // Set to true for production to shrink and obfuscate
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}