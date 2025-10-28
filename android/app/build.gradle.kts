import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.huawei.agconnect")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.meowResQ.mysafezone"
    compileSdk = 36  // Updated to match plugin requirements
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    // APK Size Optimization: Split APKs by architecture
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a")
            isUniversalApk = false  // Set to true if you need a universal APK for testing
        }
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.meowResQ.mysafezone"
        minSdk = 29
        targetSdk = 34  // Updated to latest Android requirement
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders.put("HUAWEI_API_KEY", project.property("HUAWEI_MAP_API_KEY") as String)

        // Note: ndk.abiFilters removed - using splits.abi instead for APK size optimization
        // This allows generating separate APKs per architecture
        
        // Optimize vector drawables
        vectorDrawables.useSupportLibrary = true
        
        // APK Size Optimization: Keep only required language resources
        // Add more languages as needed: "zh", "ms", etc.
        resourceConfigurations += listOf("en")
    }
    
    // Lint options - prevent build failures on warnings
    lint {
        checkReleaseBuilds = false
        abortOnError = false
        disable += listOf("MissingTranslation", "ExtraTranslation")
    }

    buildTypes {
        release {
            // Use release signing configuration
            signingConfig = signingConfigs.getByName("release")
            
            // Enable code shrinking, obfuscation, and optimization for release
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Additional optimizations
            isDebuggable = false
            isJniDebuggable = false
            isPseudoLocalesEnabled = false
            
            // Optimize native libraries
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"  // Changed from NONE to avoid stripping errors
            }
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
        }
    }
    
    // Build features optimization
    buildFeatures {
        buildConfig = true
        aidl = false
        renderScript = false
        shaders = false
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
            // Pick first for duplicate files
            pickFirsts += listOf(
                "**/*.so",
                "**/*.dll"
            )
        }
        // Handle duplicate classes from CloudDB
        jniLibs {
            pickFirsts += listOf("**/*.so")
        }
    }

}

flutter {
    source = "../.."
}

// Dependencies
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ========================================
    // ACTIVELY USED - AGConnect Services
    // ========================================
    implementation("com.huawei.agconnect:agconnect-core:1.9.1.301")
    implementation("com.huawei.agconnect:agconnect-cloud-database:1.5.3.300")
    // implementation("com.huawei.agconnect:agconnect-storage:1.9.1.301")  // NOT USED - AWS S3 used instead
    
    // ========================================
    // ACTIVELY USED - HMS Services
    // ========================================
    implementation("com.huawei.hms:maps:6.11.0.301")
    implementation("com.huawei.hms:maps-basic:6.11.0.300")
    implementation("com.huawei.hms:location:6.12.0.300")
    implementation("com.huawei.hms:push:6.13.0.300")
    implementation("com.huawei.hms:hwid:6.12.0.300")
    
    // ========================================
    // UNUSED - Commented Out for Smaller APK
    // ========================================
    // implementation("com.huawei.hms:drive:5.2.0.300")  // huawei_drive not used
    // implementation("com.huawei.hms:site:6.5.1.302")   // huawei_site not used
}