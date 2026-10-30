plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "uz.agroyordam.agroyordam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "uz.agroyordam.agroyordam"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release imzo: CI kalitni serverdan oladi (APK_KEYSTORE, APK_KEYSTORE_PASSWORD). Hamma APK bir kalit bilan
    // imzolanadi — ilova ustidan yangilanadi. Kalit berilmasa (lokal yig'ish) — debug kalit.
    val releaseKeystore = System.getenv("APK_KEYSTORE").orEmpty()
    signingConfigs {
        create("release") {
            if (releaseKeystore.isNotEmpty()) {
                storeFile = file(releaseKeystore)
                storeType = "pkcs12"
                storePassword = System.getenv("APK_KEYSTORE_PASSWORD")
                keyAlias = "agroyordam"
                keyPassword = System.getenv("APK_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseKeystore.isNotEmpty()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider (ilova yangilanishi) — plaginlar orqali ilovada allaqachon bor, bu yerda kompilyatsiya uchun
    implementation("androidx.core:core:1.13.1")
}
