# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /android-sdk/tools/proguard/proguard-android.txt

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Supabase
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Keep generic signature of Call, Response (R8 full mode strips signatures from non-kept items).
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation

# UCrop (image_cropper)
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**
