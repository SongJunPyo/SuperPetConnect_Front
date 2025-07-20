plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.connect"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // 최신 Java 8+ API를 사용하는 Flutter 패키지들을 구형 버전에 맞게 변환해주는 작업
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.connect"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true  // FCM과 같은 복잡한 라이브러리를 사용하면 앱의 메서드 수가 65k를  초과할 수 있어 MultDex가 필요함 
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {    
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") // Core Library Desugaring 작업하면 전체 추가
    //의존성 추가: flutter_local_notifications와 같은 패키지가 사용하는 최신 Java API를 구형 Android 기기에서도 호환되도록 변환하는 기능을 활성화
}

flutter {
    source = "../.."
}
