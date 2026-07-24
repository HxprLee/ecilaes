import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.hxprlee.ecilaes"
    // compileSdk must be 36 — many plugins (file_selector, flutter_curl,
    // media_kit, shared_preferences, sqflite, url_launcher, etc.) require it
    // via AAR metadata. targetSdk stays at 34: it controls the Android
    // runtime contract (MediaSession behavior, etc.) and 34 is what
    // audio_service 0.18.18 was built and tested against, so its
    // notification / lock-screen / headset callbacks fire correctly on
    // Android 14+.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "org.hxprlee.ecilaes"
        // Match compileSdk so MediaSession uses the contract audio_service
        // 0.18.18 was built against.
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Explicit because Flutter's `compileFlutterBuildRelease` task reads
        // `mergedFlavor.minSdkVersion` and NPEs when it's unset on AGP 8.11+.
        minSdk = maxOf(flutter.minSdkVersion, 21)
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
    splits {
        abi {
            isEnable = true
            reset()
            isUniversalApk = true
            include("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }
}

dependencies {
    implementation("androidx.palette:palette-ktx:1.0.0")
}

flutter {
    source = "../.."
}
