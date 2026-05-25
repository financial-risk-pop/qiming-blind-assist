package com.blindassist.blind_assist_app.channels

import android.content.Context
import android.util.Log
import com.blindassist.blind_assist_app.accessibility.BlindAssistAccessibilityService
import com.blindassist.blind_assist_app.accessibility.ScreenElementParser
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * 屏幕阅读 Platform Channel
 * 
 * 提供给 Flutter 端的能力：
 * - 获取当前屏幕元素树（getScreenElements）
 * - 获取指定位置元素（getElementAt）
 * - 按关键词搜索元素（findElements）
 * - 执行 UI 操作（performAction）
 * - 屏幕变化事件流（EventChannel）
 * 
 * Method Channel：com.blindassist/screen_reader
 * Event Channel：com.blindassist/screen_reader/events
 */
class ScreenReaderChannel(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "ScreenReaderChannel"
        private const val METHOD_CHANNEL = "com.blindassist/screen_reader"
        private const val EVENT_CHANNEL = "com.blindassist/screen_reader/events"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    private var eventSink: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        
        // 把本 Channel 注册给 AccessibilityService，以便服务内检测到屏幕变化时推送事件
        BlindAssistAccessibilityService.setEventListener { event ->
            eventSink?.success(event)
        }

        Log.i(TAG, "ScreenReaderChannel 已注册")
    }

    // ==================== MethodChannel ====================

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val service = BlindAssistAccessibilityService.instance
        if (service == null) {
            result.error(
                "SERVICE_NOT_ENABLED",
                "无障碍服务未启用，请前往设置开启 BlindAssist 无障碍服务",
                null
            )
            return
        }

        when (call.method) {
            "isServiceEnabled" -> result.success(true)
            
            "openAccessibilitySettings" -> {
                // 由 AccessibilityChannel 统一处理
                result.success(null)
            }

            "getScreenElements" -> {
                try {
                    val elements = ScreenElementParser.parseRootWindow(service.rootInActiveWindow)
                    result.success(JSONArray(elements).toString())
                } catch (e: Exception) {
                    Log.e(TAG, "获取屏幕元素失败", e)
                    result.error("PARSE_ERROR", e.message, null)
                }
            }

            "getCurrentAppInfo" -> {
                result.success(service.getCurrentAppInfo())
            }

            "getElementAt" -> {
                val x = (call.argument<Double>("x") ?: 0.0).toInt()
                val y = (call.argument<Double>("y") ?: 0.0).toInt()
                try {
                    val element = ScreenElementParser.findElementAt(
                        service.rootInActiveWindow, x, y
                    )
                    if (element != null) {
                        result.success(JSONObject(element).toString())
                    } else {
                        result.success(null)
                    }
                } catch (e: Exception) {
                    result.error("PARSE_ERROR", e.message, null)
                }
            }

            "findElements" -> {
                val query = call.argument<String>("query") ?: ""
                try {
                    val elements = ScreenElementParser.findElementsByQuery(
                        service.rootInActiveWindow, query
                    )
                    result.success(JSONArray(elements).toString())
                } catch (e: Exception) {
                    result.error("FIND_ERROR", e.message, null)
                }
            }

            "performAction" -> {
                val action = call.argument<String>("action") ?: ""
                val elementId = call.argument<String>("elementId")
                val text = call.argument<String>("text")
                try {
                    val success = service.performAction(action, elementId, text)
                    result.success(success)
                } catch (e: Exception) {
                    Log.e(TAG, "执行操作失败: $action", e)
                    result.error("ACTION_ERROR", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    // ==================== EventChannel ====================

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.i(TAG, "EventChannel 开始监听")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.i(TAG, "EventChannel 取消监听")
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        BlindAssistAccessibilityService.setEventListener(null)
        eventSink = null
    }
}
