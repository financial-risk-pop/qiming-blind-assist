package com.blindassist.blind_assist_app

import android.os.Bundle
import android.view.WindowManager
import androidx.annotation.NonNull
import com.blindassist.blind_assist_app.channels.AccessibilityChannel
import com.blindassist.blind_assist_app.channels.ScreenReaderChannel
import com.blindassist.blind_assist_app.channels.SensorChannel
import com.blindassist.blind_assist_app.channels.SpeechChannel
import com.blindassist.blind_assist_app.channels.TtsChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * 盲人智能辅助 App 的主 Activity
 * 
 * 职责：
 * 1. 持有 Flutter 引擎
 * 2. 注册所有 Platform Channel（无障碍/屏幕阅读/传感器）
 * 3. 配置窗口参数（保持屏幕常亮、沉浸式体验等）
 */
class MainActivity : FlutterActivity() {

    // Platform Channel 实例
    private lateinit var accessibilityChannel: AccessibilityChannel
    private lateinit var screenReaderChannel: ScreenReaderChannel
    private lateinit var sensorChannel: SensorChannel
    private lateinit var speechChannel: SpeechChannel
    private lateinit var ttsChannel: TtsChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        accessibilityChannel = AccessibilityChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        screenReaderChannel = ScreenReaderChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        sensorChannel = SensorChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        speechChannel = SpeechChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        ttsChannel = TtsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        if (::accessibilityChannel.isInitialized) accessibilityChannel.dispose()
        if (::screenReaderChannel.isInitialized) screenReaderChannel.dispose()
        if (::sensorChannel.isInitialized) sensorChannel.dispose()
        if (::speechChannel.isInitialized) speechChannel.dispose()
        if (::ttsChannel.isInitialized) ttsChannel.dispose()
        super.onDestroy()
    }
}
