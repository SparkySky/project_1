# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/Cellar/android-sdk/24.3.3/tools/proguard/proguard-android.txt

## ============================================
## FLUTTER ENGINE - CRITICAL FOR ANDROID 15+
## ============================================
# Keep all Flutter classes (prevents JNI crashes)
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }

# Keep Flutter JNI methods (critical for native calls)
-keepclassmembers class io.flutter.embedding.engine.FlutterJNI {
    *;
}
-keepclassmembers class io.flutter.embedding.engine.FlutterEngine {
    *;
}
-keepclassmembers class io.flutter.embedding.engine.FlutterEngineGroup {
    *;
}

# Keep Flutter native methods (prevents JNI linking errors)
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep Flutter plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.plugin.common.** { *; }

# Prevent Flutter method channels from being obfuscated
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannel *;
}

# Firebase (if you add it later)
-keep class com.google.firebase.** { *; }

## AndroidX - Critical for Flutter Fragment integration
-keep class androidx.fragment.app.** { *; }
-keep class androidx.fragment.app.Fragment { *; }
-keep class androidx.fragment.app.FragmentActivity { *; }
-keep class androidx.fragment.app.FragmentManager { *; }
-keepclassmembers class androidx.fragment.app.Fragment {
    *;
}

## Huawei HMS Services
-keep class com.huawei.hms.** { *; }
-keep class com.huawei.agconnect.** { *; }
-keep interface com.huawei.hms.** { *; }
-keep interface com.huawei.agconnect.** { *; }
-dontwarn com.huawei.**

## AGConnect CloudDB - Keep all object types (prevents duplicate class errors)
-keep class com.huawei.agconnectclouddb.objecttypes.** { *; }
-keepclassmembers class com.huawei.agconnectclouddb.objecttypes.** { *; }
-dontwarn com.huawei.agconnectclouddb.objecttypes.**

## R8 - Ignore duplicate class warnings for CloudDB generated classes
-dontnote com.huawei.agconnectclouddb.objecttypes.**

## Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

## Keep custom View classes
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

## Keep Parcelables
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

## Keep Serializable classes
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

## Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

## Keep R class
-keepclassmembers class **.R$* {
    public static <fields>;
}

## Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

## Keep app-specific classes (update with your actual model classes)
-keep class com.meowResQ.mysafezone.** { *; }

## Gson/JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }

## OkHttp and Retrofit (if used)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# ========================================
# APK Size Optimization Rules (SAFE FOR FLUTTER)
# ========================================

# Remove HMS/AGConnect BuildConfig debug flags
-assumenosideeffects class **.BuildConfig {
    public static boolean DEBUG;
}

# SAFE optimization settings (compatible with Flutter JNI)
-optimizationpasses 5
-allowaccessmodification
# NOTE: -repackageclasses removed - it breaks JNI method lookups
-dontpreverify

# Remove debug logging (safe optimization)
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    public static void check*(...);
    public static void throw*(...);
}

# Keep source file and line numbers for crash reports
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Keep important attributes for Flutter
-keepattributes Exceptions,InnerClasses,Signature,Deprecated,EnclosingMethod

# Specific warnings to ignore (not blanket ignore)
-dontwarn kotlin.**
-dontwarn com.huawei.agconnect.**
-dontwarn com.huawei.hms.**

# NOTE: Removed blanket -dontwarn ** and -ignorewarnings
# These hide critical Flutter JNI errors on Android 15+

