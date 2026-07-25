import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) {
        load(FileInputStream(propertiesFile))
    }
}

val hasKeystore = keystoreProperties.getProperty("keyAlias") != null &&
        keystoreProperties.getProperty("keyPassword") != null &&
        keystoreProperties.getProperty("storeFile") != null &&
        keystoreProperties.getProperty("storePassword") != null

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yourself.habits"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.yourself.habits"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // MultiDex may be needed with Firebase + Firestore dependencies.
        multiDexEnabled = true
    }

    signingConfigs {
        getByName("debug") {
            // Dedicated CI/debug key with a Firebase-registered SHA fingerprint.
            // Production releases continue to use the private release keystore.
            storeFile = rootProject.file("ci-signing.jks")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Local production builds use key.properties. CI/test releases use the
            // Firebase-registered CI certificate so Google Sign-In remains testable.
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
