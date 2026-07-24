pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 9.2.1 is the latest stable that compiles `compileFlutterBuildRelease`
    // without NPE once `defaultConfig.minSdk` is explicit on this Flutter
    // version. AGP 8.x can't run `jlink` from JDK 26 against android-36's
    // core-for-system-modules.jar, so we have to stay on 9.x.
    id("com.android.application") version "9.2.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

gradle.settingsEvaluated {
    settings.rootProject.children.removeIf {
        it.name == "flutter_discord_rpc" ||
        it.name.startsWith("bitsdojo_window") ||
        it.name == "nativeapi" ||
        it.name == "cnativeapi"
    }
}

