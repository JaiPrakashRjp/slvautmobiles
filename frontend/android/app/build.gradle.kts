import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase (FCM) — must be applied after the Android/Kotlin plugins.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: loaded from android/key.properties (git-ignored). CI writes
// it from GitHub secrets; if absent (local dev) the release build falls back to
// the debug key. A persistent key means updates install in place — no uninstall.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.slvauto.slv_auto_consultant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Required by flutter_local_notifications (uses java.time APIs on old Android).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Base id. The `dev` flavor appends `.dev` (see productFlavors) so the
        // dev app installs ALONGSIDE the prod app on the same phone. Prod (main)
        // keeps this base id. Both ids are registered in google-services.json.
        applicationId = "com.slvauto.slv_auto_consultant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFileName = keystoreProperties["storeFile"] as String?
            if (storeFileName != null) {
                storeType = "PKCS12"
                storeFile = file(storeFileName)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Persistent release key when configured (CI); else debug (local dev).
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }

    // Env flavors so dev and prod coexist on one phone and are told apart:
    //   prod → com.slvauto.slv_auto_consultant       · "SLV Auto Consultant"
    //   dev  → com.slvauto.slv_auto_consultant.dev    · "SLV Auto (DEV)"
    // CI builds `--flavor prod` on main, `--flavor dev` on dev. app_name is
    // consumed by AndroidManifest's android:label. Only the id/name differ —
    // the API URL is still injected via --dart-define at build time.
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "SLV Auto Consultant")
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "SLV Auto (DEV)")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Enables java.time / desugaring used by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
