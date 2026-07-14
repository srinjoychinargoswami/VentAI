# Keep Play Core classes (Google Play requirement)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.*

# Keep flutter_gemma and MediaPipe classes
-keep class com.google.mediapipe.** { *; }
-keep class com.google.gemma.** { *; }
-dontwarn com.google.mediapipe.*
-dontwarn com.google.gemma.**

# Keep Flutter framework classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.*

# Keep Flutter plugins
-keep class io.flutter.plugins.* { *; }
-keep class * extends io.flutter.plugins.* { *; }

# Keep flutter_gemma plugins
-keep class io.flutter.plugins.flutter_gemma** { *; }
-keep class * implements io.flutter.plugins.flutter_gemma.** { *; }
-keep class io.flutter.plugins.flutter_gemma_litertlm** { *; }
-keep class * implements io.flutter.plugins.flutter_gemma_litertlm.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom application classes
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgent
-keep public class * extends android.preference.Preference
-keep public class * extends android.view.View
-keep public class * extends android.widget.FrameLayout

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
