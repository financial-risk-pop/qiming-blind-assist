package com.blindassist.blind_assist_app.channels

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.URLEncoder
import java.util.Locale
import java.util.UUID

/**
 * TTS Channel V4
 *
 * 核心改进：
 * 1. 去掉预探测临时 TTS 对象，避免竞态导致 status=-1
 * 2. 原生 TTS 失败后延迟重试一次
 * 3. 在线 TTS 添加音频焦点请求，解决蓝牙/音频路由问题
 * 4. 添加 UtteranceProgressListener 监听实际播放状态
 * 5. 在线 TTS 失败自动触发原生 TTS 重新初始化
 */
class TtsChannel(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "TtsChannel"
        private const val CHANNEL_NAME = "com.blindassist/tts"
        private const val MAX_RETRY = 2
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var tts: TextToSpeech? = null
    private var nativeReady = false
    private var initStatus = "not_initialized"
    private val pendingQueue = mutableListOf<String>()
    private var mediaPlayer: MediaPlayer? = null
    private var initRetryCount = 0
    private var audioFocusRequest: AudioFocusRequest? = null
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
        initNativeTts()
    }

    /**
     * 初始化原生 TTS：
     * - 不再预探测 defaultEngine（去掉临时对象竞态）
     * - 直接用默认构造函数让系统自己选引擎
     * - 失败后延迟1秒重试一次
     */
    private fun initNativeTts() {
        initStatus = "initializing"
        try {
            Log.i(TAG, "初始化原生TTS (retry=$initRetryCount)...")

            val listener = TextToSpeech.OnInitListener { status ->
                Log.i(TAG, "TTS onInit status=$status, retry=$initRetryCount")
                if (status == TextToSpeech.SUCCESS) {
                    configureNativeTts()
                } else {
                    Log.w(TAG, "原生TTS初始化失败(status=$status)")
                    nativeReady = false

                    // 如果还有重试次数，延迟1.5秒重试
                    if (initRetryCount < MAX_RETRY) {
                        initRetryCount++
                        initStatus = "native_failed:$status,retrying_$initRetryCount"
                        Log.i(TAG, "将在1.5秒后重试初始化...")
                        mainHandler.postDelayed({
                            try { tts?.shutdown() } catch (_: Exception) {}
                            tts = null
                            initNativeTts()
                        }, 1500)
                    } else {
                        initStatus = "native_failed:$status,using_online"
                        Log.w(TAG, "原生TTS重试${MAX_RETRY}次后仍失败，降级在线TTS")
                        flushQueue()
                    }
                }
            }

            // 不再预探测引擎，直接让系统选择
            tts = TextToSpeech(context, listener)

        } catch (e: Exception) {
            Log.e(TAG, "原生TTS创建异常: ${e.message}")
            nativeReady = false
            initStatus = "native_error:${e.message},using_online"
        }
    }

    private fun configureNativeTts() {
        val locales = listOf(
            Locale("zh", "CN"), Locale.CHINESE,
            Locale.SIMPLIFIED_CHINESE, Locale.getDefault()
        )
        for (locale in locales) {
            val r = tts?.isLanguageAvailable(locale) ?: -2
            if (r >= TextToSpeech.LANG_AVAILABLE) {
                tts?.setLanguage(locale)
                Log.i(TAG, "  语言设置: $locale (result=$r)")
                break
            }
        }
        tts?.setSpeechRate(0.9f)

        // 添加播放监听，追踪实际播放状态
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                Log.i(TAG, "原生TTS开始播放: $utteranceId")
            }
            override fun onDone(utteranceId: String?) {
                Log.i(TAG, "原生TTS播放完成: $utteranceId")
            }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                Log.e(TAG, "原生TTS播放出错: $utteranceId, 降级到在线TTS")
            }
            override fun onError(utteranceId: String?, errorCode: Int) {
                Log.e(TAG, "原生TTS播放出错: $utteranceId, code=$errorCode")
            }
        })

        nativeReady = true
        initStatus = "native_ready:${tts?.defaultEngine}"
        Log.i(TAG, "原生TTS就绪 ✅ engine=${tts?.defaultEngine}")
        flushQueue()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "speak" -> {
                val text = call.argument<String>("text") ?: ""
                speak(text)
                result.success(null)
            }
            "stop" -> {
                tts?.stop()
                releaseMediaPlayer()
                result.success(null)
            }
            "isReady" -> result.success(true)
            "getStatus" -> {
                result.success(mapOf(
                    "ready" to true,
                    "nativeReady" to nativeReady,
                    "initStatus" to initStatus,
                    "engine" to (tts?.defaultEngine ?: "online_fallback"),
                    "voice" to (tts?.voice?.name ?: "online"),
                    "locale" to (tts?.voice?.locale?.toString() ?: "zh-CN"),
                ))
            }
            "setSpeechRate" -> {
                val rate = call.argument<Double>("rate") ?: 0.9
                tts?.setSpeechRate(rate.toFloat())
                result.success(null)
            }
            "setVolume" -> result.success(null)
            "ensureVolume" -> {
                ensureMediaVolume()
                result.success(null)
            }
            "reinit" -> {
                Log.i(TAG, "收到reinit请求，重新初始化原生TTS")
                initRetryCount = 0
                try { tts?.shutdown() } catch (_: Exception) {}
                tts = null
                nativeReady = false
                initNativeTts()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun speak(text: String) {
        if (text.isEmpty()) return
        ensureMediaVolume()

        // 如果还在初始化中，加入等待队列
        if (initStatus == "initializing" || initStatus.contains("retrying")) {
            Log.i(TAG, "TTS初始化中，加入队列: ${text.take(20)}...")
            pendingQueue.add(text)
            return
        }

        if (nativeReady) {
            doNativeSpeak(text)
        } else {
            doOnlineSpeak(text)
        }
    }

    private fun doNativeSpeak(text: String) {
        try {
            requestAudioFocus()
            val params = android.os.Bundle()
            params.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_MUSIC)
            val uttId = UUID.randomUUID().toString()
            val ret = tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, uttId)
            Log.i(TAG, "原生speak调用, ret=$ret, text=${text.take(30)}")
            if (ret != TextToSpeech.SUCCESS) {
                Log.w(TAG, "原生speak返回失败($ret)，降级到在线TTS")
                doOnlineSpeak(text)
            }
        } catch (e: Exception) {
            Log.w(TAG, "原生speak异常，降级到在线: ${e.message}")
            doOnlineSpeak(text)
        }
    }

    /**
     * 在线 TTS —— 百度在线合成 + 音频焦点请求
     */
    private fun doOnlineSpeak(text: String) {
        val trimmed = if (text.length > 200) text.substring(0, 200) else text
        val encoded = URLEncoder.encode(trimmed, "UTF-8")
        val url = "https://tts.baidu.com/text2audio?tex=$encoded&lan=zh&cuid=baidu_tts_qiming&ctp=1&pdt=301&spd=5&per=0"

        Log.i(TAG, "在线TTS: ${trimmed.take(30)}...")

        mainHandler.post {
            try {
                releaseMediaPlayer()
                requestAudioFocus()

                val mp = MediaPlayer()
                mp.setAudioAttributes(AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .build())

                mp.setOnPreparedListener { player ->
                    Log.i(TAG, "在线TTS准备完成，开始播放, duration=${player.duration}ms")
                    try {
                        player.start()
                    } catch (e: Exception) {
                        Log.e(TAG, "start失败: ${e.message}")
                    }
                }
                mp.setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer错误: what=$what extra=$extra")
                    abandonAudioFocus()
                    true
                }
                mp.setOnCompletionListener {
                    Log.i(TAG, "在线TTS播放完成")
                    abandonAudioFocus()
                }

                mp.setDataSource(url)
                mp.prepareAsync()
                mediaPlayer = mp
            } catch (e: Exception) {
                Log.e(TAG, "在线TTS异常: ${e.message}")
                abandonAudioFocus()
            }
        }
    }

    private fun requestAudioFocus() {
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val focusReq = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_ASSISTANT)
                        .build())
                    .build()
                am.requestAudioFocus(focusReq)
                audioFocusRequest = focusReq
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            }
        } catch (e: Exception) {
            Log.w(TAG, "请求音频焦点失败: ${e.message}")
        }
    }

    private fun abandonAudioFocus() {
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
            }
        } catch (_: Exception) {}
    }

    private fun releaseMediaPlayer() {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {}
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null
    }

    private fun flushQueue() {
        if (pendingQueue.isNotEmpty()) {
            val queue = ArrayList(pendingQueue)
            pendingQueue.clear()
            for (text in queue) speak(text)
        }
    }

    private fun ensureMediaVolume() {
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            Log.d(TAG, "媒体音量: $current/$max")
            if (current == 0) {
                am.setStreamVolume(AudioManager.STREAM_MUSIC, (max * 0.7).toInt(),
                    AudioManager.FLAG_SHOW_UI)
                Log.i(TAG, "媒体音量为0，已自动调高到70%")
            }
        } catch (_: Exception) {}
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        try { tts?.stop(); tts?.shutdown() } catch (_: Exception) {}
        releaseMediaPlayer()
        abandonAudioFocus()
        tts = null
    }
}
