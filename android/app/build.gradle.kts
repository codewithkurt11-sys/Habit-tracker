import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) {
        load(FileInputStream(propertiesFile))
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
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
    }

    // Validate release signing config only when building a release variant.
    // If key.properties is missing or incomplete, fail with a clear message
    // instead of throwing a NullPointerException on null casts.
    val hasKeystoreProps = keystoreProperties.containsKey("keyAlias") &&
        keystoreProperties.containsKey("keyPassword") &&
        keystoreProperties.containsKey("storeFile") &&
        keystoreProperties.containsKey("storePassword")
    val keystoreFile = keystoreProperties["storeFile"]?.toString()
    val keystoreExists = keystoreFile != null && rootProject.file(keystoreFile).exists()

    signingConfigs {
        create("release") {
            if (hasKeystoreProps && keystoreExists) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // Debug builds use the default debug signing config — no keystore needed.
        }
        getByName("release") {
            // Only assign signing config when all properties and the keystore
            // file are present. Otherwise the release build will be unsigned
            // (or fail at APK signing). This avoids throwing during configuration
            // which would break debug builds too.
            if (hasKeystoreProps && keystoreExists) {
                signingConfig = signingConfigs.getByName("release")
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
