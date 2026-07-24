# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (optional, for deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Play Core R8 missing rules
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# music_widget (home_widget plugin)
-keep class es.antonborri.home_widget.** { *; }

# App's own Activity / Plugin / Widget classes — referenced by the
# AndroidManifest, instantiated via reflection by the FlutterEngine,
# or extended by R8-optimized classes. Without these, R8 strips
# SharePlugin and MainActivity blows up with NoClassDefFoundError
# before runApp() ever runs, leaving the splash screen visible.
-keep class org.hxprlee.ecilaes.** { *; }

# audio_service / just_audio
-keep class com.ryanheise.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# flutter_curl
-keep class com.ajinasokan.flutter_curl.** { *; }

# media_kit
-keep class com.mr.crossbow.** { *; }
