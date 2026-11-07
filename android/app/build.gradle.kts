plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.localai.localai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.localai.localai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 28 is required by the bundled on-device llama.cpp native libraries
        // (llm_llamacpp is compiled against android-28); Flutter's default of
        // 24 would let the app install on devices the .so cannot load on.
        minSdk = maxOf(flutter.minSdkVersion, 28)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // llm_llamacpp finds its ggml backend .so files (libggml-cpu-*.so,
    // libggml-vulkan.so) at runtime by scanning the native library *directory*
    // obtained via dladdr(). With the modern default (extractNativeLibs=false)
    // the libraries are mapped straight out of the APK, so that directory does
    // not exist and backend loading silently falls back — model loading then
    // fails with "Failed to load model from ...". Extracting them to the app's
    // lib dir (legacy packaging) restores the scan. This is the AGP-blessed
    // equivalent of android:extractNativeLibs="true".
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
