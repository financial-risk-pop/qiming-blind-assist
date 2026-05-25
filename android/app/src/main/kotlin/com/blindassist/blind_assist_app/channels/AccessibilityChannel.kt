package com.blindassist.blind_assist_app.channels

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.blindassist.blind_assist_app.accessibility.BlindAssistAccessibilityService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 无障碍 Platform Channel
 */
class AccessibilityChannel(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AccessibilityChannel"
        private const val CHANNEL_NAME = "com.blindassist/accessibility"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
        Log.i(TAG, "AccessibilityChannel 已注册")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isServiceEnabled" -> {
                result.success(isAccessibilityServiceEnabled())
            }
            "openAccessibilitySettings" -> {
                openAccessibilitySettings()
                result.success(null)
            }
            "openBatterySettings" -> {
                openBatterySettings()
                result.success(null)
            }
            "isIgnoringBatteryOptimization" -> {
                result.success(isIgnoringBatteryOptimization())
            }
            "openAppDetailSettings" -> {
                openAppDetailSettings()
                result.success(null)
            }
            "getCurrentAppInfo" -> {
                result.success(getCurrentAppInfoFromService())
            }
            else -> result.notImplemented()
        }
    }

    /**
     * 检查本 App 的无障碍服务是否已开启
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceComponent =
            "${context.packageName}/${BlindAssistAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: ""
        return enabledServices.contains(serviceComponent) ||
            enabledServices.contains(BlindAssistAccessibilityService::class.java.simpleName)
    }

    /**
     * 打开系统无障碍设置
     */
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    /**
     * 打开省电/电池优化白名单设置
     * 优先尝试跳到 IGNORE_BATTERY_OPTIMIZATION_SETTINGS（系统级白名单页）
     * 如果失败，降级到本 App 的详情页
     */
    private fun openBatterySettings() {
        val intents = listOf(
            // 尝试 1：电池优化白名单页
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            // 尝试 2：电源管理设置
            Intent(Intent.ACTION_MAIN).apply {
                component = ComponentName(
                    "com.android.settings",
                    "com.android.settings.fuelgauge.PowerUsageSummary"
                )
            },
            // 尝试 3：App 详情页（一定能跳）
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            },
        )
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(context.packageManager) != null) {
                    context.startActivity(intent)
                    return
                }
            } catch (e: Exception) {
                Log.w(TAG, "尝试跳转失败: ${e.message}")
            }
        }
        // 都失败时给个 fallback
        try {
            val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(fallback)
        } catch (_: Exception) {}
    }

    /**
     * 检查是否已加入电池优化白名单
     */
    private fun isIgnoringBatteryOptimization(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                pm.isIgnoringBatteryOptimizations(context.packageName)
            } else {
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 直接打开本 App 的详情设置页
     */
    private fun openAppDetailSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "打开 App 详情失败: ${e.message}")
        }
    }

    private fun getCurrentAppInfoFromService(): Map<String, Any?> {
        val service = BlindAssistAccessibilityService.instance
        if (service == null) {
            return mapOf(
                "packageName" to "",
                "appName" to "无障碍服务未启用",
                "category" to null
            )
        }
        return service.getCurrentAppInfo()
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}

