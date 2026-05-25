package com.blindassist.blind_assist_app.channels

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 语音识别 Channel V2
 *
 * 双模式：
 * 1. SpeechRecognizer（后台静默识别）—— 如果可用
 * 2. RecognizerIntent（弹出系统语音 UI）—— 作为备选，几乎所有手机都支持
 */
class SpeechChannel(
    private val activity: Activity,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "SpeechChannel"
        private const val METHOD_CHANNEL = "com.blindassist/speech"
        private const val EVENT_CHANNEL = "com.blindassist/speech_events"
        private const val REQUEST_CODE_SPEECH = 9527
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private var speechRecognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
        // 注册事件流
        Log.i(TAG, "SpeechChannel V2 已注册")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> {
                val available = SpeechRecognizer.isRecognitionAvailable(activity)
                Log.i(TAG, "SpeechRecognizer 可用: $available")
                result.success(available)
            }
            "isIntentAvailable" -> {
                // 检查 Intent 方式是否可用（几乎所有手机都有）
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                val available = intent.resolveActivity(activity.packageManager) != null
                Log.i(TAG, "Intent语音识别 可用: $available")
                result.success(available)
            }
            "startListening" -> {
                startListening()
                result.success(null)
            }
            "startListeningWithIntent" -> {
                // 弹出系统语音输入 UI
                startListeningWithIntent(result)
            }
            "stopListening" -> {
                stopListening()
                result.success(null)
            }
            "cancel" -> {
                cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ===== 方式 1: SpeechRecognizer（后台静默） =====

    private fun startListening() {
        try { speechRecognizer?.destroy() } catch (_: Exception) {}

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(activity)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                sendEvent("status", "listening")
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {
                sendEvent("status", "processing")
            }
            override fun onError(error: Int) {
                val msg = when (error) {
                    SpeechRecognizer.ERROR_AUDIO -> "音频录入错误"
                    SpeechRecognizer.ERROR_CLIENT -> "客户端错误"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "权限不足"
                    SpeechRecognizer.ERROR_NETWORK -> "网络错误"
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "网络超时"
                    SpeechRecognizer.ERROR_NO_MATCH -> "未识别到语音"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "识别器忙"
                    SpeechRecognizer.ERROR_SERVER -> "服务器错误"
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "语音输入超时"
                    else -> "未知错误($error)"
                }
                sendEvent("error", msg)
            }
            override fun onResults(results: Bundle?) {
                val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
                sendEvent("result", text)
            }
            override fun onPartialResults(partialResults: Bundle?) {
                val text = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
                if (text.isNotEmpty()) sendEvent("partial", text)
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            sendEvent("error", "启动失败: ${e.message}")
        }
    }

    // ===== 方式 2: 简化版——直接复用 SpeechRecognizer =====

    private fun startListeningWithIntent(result: MethodChannel.Result) {
        // 即使 isAvailable=false，某些手机的 SpeechRecognizer 实际仍能工作
        // 直接尝试启动，失败通过事件流报错
        try {
            startListening()
            result.success("listening")
        } catch (e: Exception) {
            result.success(null)
            sendEvent("error", "启动失败: ${e.message}")
        }
    }

    private fun stopListening() {
        try { speechRecognizer?.stopListening() } catch (_: Exception) {}
    }

    private fun cancel() {
        try { speechRecognizer?.cancel() } catch (_: Exception) {}
    }

    private fun sendEvent(type: String, data: String) {
        activity.runOnUiThread {
            eventSink?.success(mapOf("type" to type, "data" to data))
        }
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        try { speechRecognizer?.destroy() } catch (_: Exception) {}
        speechRecognizer = null
    }
}
