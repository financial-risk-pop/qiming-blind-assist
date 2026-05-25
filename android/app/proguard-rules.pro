# ============ BlindAssist ProGuard 规则 ============

# ===== Flutter 核心（不能混淆）=====
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# ===== BlindAssist 原生层 =====
# Platform Channel 与 Flutter 通过反射通信，保留原名
-keep class com.blindassist.blind_assist_app.channels.** { *; }
-keep class com.blindassist.blind_assist_app.accessibility.** { *; }

# AccessibilityService 由系统反射实例化，保留构造函数
-keep class * extends android.accessibilityservice.AccessibilityService {
    public <init>(...);
    public *;
}

# ===== TensorFlow Lite =====
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.**

# ===== Google ML Kit =====
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**

# ===== 高德地图 SDK =====
-keep class com.amap.api.** { *; }
-keep class com.autonavi.** { *; }
-dontwarn com.amap.api.**
-dontwarn com.autonavi.**

# ===== Gson / JSON 反射 =====
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ===== 保留行号方便排查线上问题 =====
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ===== Kotlin =====
-keepclassmembers class kotlin.Metadata { *; }
-keep class kotlin.Metadata { *; }

# ===== Kotlinx Coroutines =====
-dontwarn kotlinx.coroutines.**

# ===== Google Play Core (Flutter deferred components) =====
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
