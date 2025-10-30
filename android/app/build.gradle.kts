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
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
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
        targetSdk = 35  // Updated for Android 15 compatibility
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders.put("HUAWEI_API_KEY", project.property("HUAWEI_MAP_API_KEY") as String)
        
        // Note: ABI filtering is handled by Flutter build command (--split-per-abi or --target-platform)
        // Removing ndk filters to avoid conflicts with Flutter's split mechanism
        
        // Optimize vector drawables
        vectorDrawables.useSupportLibrary = true
        
        // APK Size Optimization: Keep only English language resources
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
            isCrunchPngs = true  // Compress PNG files
            isZipAlignEnabled = true  // Optimize APK alignment
            
            // Native code optimization
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
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
                
                // Exclude META-INF documentation and license files
                "META-INF/commons-codec*",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "META-INF/DEPENDENCIES",
                "META-INF/*.kotlin_module",
                "META-INF/ASL2.0",
                "META-INF/*.version",
                "META-INF/LICENSE.md",
                "META-INF/LICENSE-notice.md",
                "META-INF/NOTICE.md",
                
                // Exclude documentation files from HMS/AGConnect plugins
                "**/README.md",
                "**/README.txt",
                "**/CHANGELOG.md",
                "**/CHANGELOG.txt",
                "**/LICENSE",
                "**/LICENSE.txt",
                "**/LICENSE.md",
                "**/NOTICE",
                "**/NOTICE.txt",
                "**/NOTICE.md",
                "**/OpenSourceSoftwareNotice.html",
                "**/THIRD PARTY OPEN SOURCE SOFTWARE NOTICE.txt",
                
                // Exclude Gradle wrapper and build files
                "**/gradle-wrapper.jar",
                "**/gradle-wrapper.properties",
                "**/gradlew",
                "**/gradlew.bat",
                "**/build.gradle",
                "**/build.gradle.kts",
                "**/settings.gradle",
                "**/gradle.properties",
                "**/proguard-rules.pro",
                
                // Exclude analysis and config files
                "**/analysis_options.yaml",
                "**/pubspec.yaml",
                "**/pubspec.lock",
                "**/.packages",
                
                // Exclude protobuf definitions
                "**/*.proto",
                
                // Exclude Kotlin debug
                "DebugProbesKt.bin",
                "kotlin/**/*.kotlin_builtins",
                
                // Additional exclusions for size optimization
                "**/*.srcjar",
                "**/MANIFEST.MF",
                "META-INF/services/**",
                "META-INF/proguard/**",
                "**/*.properties",
                "**/package.html",
                "**/overview.html",
                "**/*-metadata.json",
                
                // Exclude debug and test resources
                "**/debug/**",
                "**/test/**",
                "**/androidTest/**",
                "**/*Test.class",
                "**/*Tests.class"
            )
            // Pick first for duplicate files
            pickFirsts += listOf(
                "**/*.so",
                "**/*.dll"
            )
        }
        // Handle native libraries
        jniLibs {
            pickFirsts += listOf("**/*.so")
            useLegacyPackaging = false  // Better compression
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