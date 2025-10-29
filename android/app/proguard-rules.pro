# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/Cellar/android-sdk/24.3.3/tools/proguard/proguard-android.txt

## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

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
# APK Size Optimization Rules
# ========================================

# Remove HMS/AGConnect BuildConfig debug flags
-assumenosideeffects class **.BuildConfig {
    public static boolean DEBUG;
}

# Aggressive optimization settings (max compression)
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 7
-allowaccessmodification
-repackageclasses ''
-mergeinterfacesaggressively

# Remove debug logging completely
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    public static void check*(...);
    public static void throw*(...);
}

# Strip out line numbers and source file names (saves space)
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Remove unused code aggressively
-dontwarn **
-ignorewarnings

# Optimize method calls
-assumenosideeffects class java.lang.StringBuilder {
    public java.lang.StringBuilder();
    public java.lang.StringBuilder(int);
    public java.lang.StringBuilder append(...);
    public java.lang.String toString();
}

# Remove Kotlin metadata (not needed in production)
-dontwarn kotlin.**
-assumenosideeffects class kotlin.jvm.internal.** {
    *;
}

