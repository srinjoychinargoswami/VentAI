pluginManagement {
    val flutterSdkPath: String by settings
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dplugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.5.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.0" apply false
}

include(":app")
