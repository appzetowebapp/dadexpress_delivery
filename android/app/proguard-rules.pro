# Flutter Overlay Window rules
-keep class flutter.overlay.window.flutter_overlay_window.** { *; }

# Flutter Background Service rules
-keep class id.flutter.flutter_background_service.** { *; }

# Geolocator rules
-keep class com.baseflow.geolocator.** { *; }

# Keep Flutter engine parts needed for background isolates
-keep class io.flutter.embedding.engine.FlutterEngine { *; }
-keep class io.flutter.embedding.engine.dart.DartExecutor { *; }
-keep class io.flutter.view.FlutterMain { *; }

# Keep all Flutter plugins
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# Keep common Flutter plugin components
-keep class io.flutter.plugin.** { *; }

# Required for R8 to not strip out the entry point for the background service
-keep class * {
    public static void main(java.lang.String[]);
}

# Fix for Missing classes detected while running R8 (Play Core)
-dontwarn com.google.android.play.core.**
