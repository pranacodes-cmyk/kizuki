# Only used if R8 shrinking is turned back on for release builds (it is off — see build.gradle.kts).
# Plugins below are called from Dart through JNI/reflection; R8 must not rename or strip them.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature, *Annotation*
