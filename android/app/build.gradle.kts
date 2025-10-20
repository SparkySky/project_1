plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.huawei.agconnect")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.meowResQ.mysafezone"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.meowResQ.mysafezone"
        minSdk = 29
        targetSdk = 33
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders.put("HUAWEI_API_KEY", project.property("HUAWEI_MAP_API_KEY") as String)

        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a"))
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += listOf(
                // Exclude all codec-related resources
                "org/apache/commons/codec/**",
                "org/apache/commons/codec/language/**",
                "org/apache/commons/codec/language/bm/**",
                "okhttp3/internal/**",
                "META-INF/commons-codec*",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE.txt"
            )
        }
    }

}

flutter {
    source = "../.."
}

// Kotlin Format
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Add Huawei HMS Core dependencies.
    implementation("com.huawei.agconnect:agconnect-core:1.9.1.301")
    implementation("com.huawei.agconnect:agconnect-cloud-database:1.5.3.300")
    implementation("com.huawei.hms:maps:6.11.0.301")
    implementation("com.huawei.hms:maps-basic:6.11.0.300")
    implementation("com.huawei.hms:location:6.12.0.300")
    implementation("com.huawei.hms:push:6.13.0.300")
    implementation("com.huawei.hms:hwid:6.12.0.300")
    implementation("com.huawei.hms:drive:5.2.0.300")
}