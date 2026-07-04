plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("kotlin-android")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.halo_app"
    compileSdk = 34 // Manually set compileSdk for compatibility

    defaultConfig {
        applicationId = "com.example.halo_app"
        minSdk = flutter.minSdkVersion // Essential: Firebase Phone Auth will NOT work if this is lower than 21
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

