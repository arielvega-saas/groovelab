# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# GrooveLab audio engine
-keep class com.groovelab.groovelab.audio.** { *; }

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }

# Google Play Billing
-keep class com.android.vending.billing.** { *; }

# Google Play Core (deferred components / split install)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
