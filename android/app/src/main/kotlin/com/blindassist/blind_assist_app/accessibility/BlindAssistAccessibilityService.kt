package com.blindassist.blind_assist_app.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * BlindAssist 无障碍服务
 * 
 * 核心能力：
 * 1. 获取当前前台 App 信息
 * 2. 获取屏幕元素树（通过 rootInActiveWindow）
 * 3. 监听屏幕变化事件（窗口切换、内容更新）
 * 4. 执行 UI 操作（点击、滚动、设置文本）
 * 
 * 用户需要在系统设置 → 无障碍 → 下载的应用中手动开启本服务
 */
class BlindAssistAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "BlindAssistA11yService"

        // 单例引用，供 Channel 层访问
        @Volatile
        var instance: BlindAssistAccessibilityService? = null
            private set

        // 屏幕变化事件监听器（由 ScreenReaderChannel 注册）
        private var eventListener: ((Map<String, Any?>) -> Unit)? = null

        fun setEventListener(listener: ((Map<String, Any?>) -> Unit)?) {
            eventListener = listener
        }
    }

    // 当前前台 App 信息缓存
    @Volatile
    private var currentPackageName: String = ""
    @Volatile
    private var currentClassName: String = ""

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this

        // 配置服务参数
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.DEFAULT or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }

        Log.i(TAG, "BlindAssist 无障碍服务已连接")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance === this) {
            instance = null
        }
        Log.i(TAG, "BlindAssist 无障碍服务已断开")
    }

    override fun onInterrupt() {
        Log.w(TAG, "无障碍服务被中断")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        when (event.eventType) {
            // 窗口（App）切换
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val pkg = event.packageName?.toString() ?: ""
                val cls = event.className?.toString() ?: ""

                val isAppSwitch = pkg != currentPackageName && pkg.isNotEmpty()
                val isPageChange = pkg == currentPackageName && cls != currentClassName

                currentPackageName = pkg
                currentClassName = cls

                if (isAppSwitch) {
                    fireEvent(
                        changeType = "app_switch",
                        packageName = pkg,
                        className = cls
                    )
                } else if (isPageChange) {
                    fireEvent(
                        changeType = "page_change",
                        packageName = pkg,
                        className = cls
                    )
                }
            }

            // 页面内容更新
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                // 节流：只上报关键变更
                if (event.contentChangeTypes != 0) {
                    fireEvent(
                        changeType = "content_update",
                        packageName = currentPackageName,
                        className = currentClassName
                    )
                }
            }

            // 通知出现
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                val notifText = event.text?.joinToString(" ") ?: ""
                fireEvent(
                    changeType = "notification",
                    packageName = event.packageName?.toString() ?: "",
                    className = "",
                    description = notifText
                )
            }
        }
    }

    /**
     * 推送屏幕变化事件给 Flutter 端
     */
    private fun fireEvent(
        changeType: String,
        packageName: String,
        className: String,
        description: String? = null
    ) {
        val appName = getAppDisplayName(packageName)
        val event = mapOf(
            "changeType" to changeType,
            "packageName" to packageName,
            "className" to className,
            "appName" to appName,
            "description" to description,
            "timestamp" to System.currentTimeMillis()
        )
        eventListener?.invoke(event)
    }

    // ==================== 供 Channel 调用的公开方法 ====================

    /**
     * 获取当前前台 App 的信息
     */
    fun getCurrentAppInfo(): Map<String, Any?> {
        val pkg = currentPackageName.ifEmpty {
            rootInActiveWindow?.packageName?.toString() ?: ""
        }
        val appName = getAppDisplayName(pkg)
        val category = inferCategory(pkg)

        return mapOf(
            "packageName" to pkg,
            "appName" to appName,
            "currentActivity" to currentClassName,
            "category" to category,
            "description" to null
        )
    }

    /**
     * 执行 UI 操作
     * 
     * @param action 操作类型 (click/long_click/scroll_forward/scroll_backward/focus/set_text/copy/paste)
     * @param elementId 目标元素的 view id（可选）
     * @param text setText 操作时的输入文本
     */
    fun performAction(action: String, elementId: String?, text: String?): Boolean {
        val root = rootInActiveWindow ?: return false

        // 查找目标节点
        val targetNode = when {
            elementId != null && elementId.isNotEmpty() -> findNodeByViewId(root, elementId)
            else -> root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
        } ?: return false

        return try {
            when (action) {
                "click" -> targetNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                "long_click" -> targetNode.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK)
                "scroll_forward" -> targetNode.performAction(
                    AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                )
                "scroll_backward" -> targetNode.performAction(
                    AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                )
                "focus" -> targetNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                "clear_focus" -> targetNode.performAction(
                    AccessibilityNodeInfo.ACTION_CLEAR_FOCUS
                )
                "set_text" -> {
                    val args = Bundle().apply {
                        putCharSequence(
                            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                            text ?: ""
                        )
                    }
                    targetNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                }
                "copy" -> targetNode.performAction(AccessibilityNodeInfo.ACTION_COPY)
                "paste" -> targetNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                else -> {
                    Log.w(TAG, "未知操作类型: $action")
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "执行操作失败: $action", e)
            false
        }
    }

    /**
     * 模拟点击屏幕指定位置（需要 canPerformGestures=true）
     */
    fun performClickAt(x: Float, y: Float): Boolean {
        return try {
            val path = Path().apply { moveTo(x, y) }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
                .build()
            dispatchGesture(gesture, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "点击手势失败", e)
            false
        }
    }

    // ==================== 内部工具方法 ====================

    /**
     * 按 view id 查找节点
     */
    private fun findNodeByViewId(
        root: AccessibilityNodeInfo,
        viewId: String
    ): AccessibilityNodeInfo? {
        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
        return nodes.firstOrNull()
    }

    /**
     * 获取 App 的显示名称
     */
    private fun getAppDisplayName(packageName: String): String {
        if (packageName.isEmpty()) return "未知应用"
        return try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName
        }
    }

    /**
     * 根据包名推断 App 分类
     */
    private fun inferCategory(packageName: String): String {
        return when {
            packageName.startsWith("com.tencent.mm") -> "social"
            packageName.startsWith("com.tencent.mobileqq") -> "social"
            packageName.startsWith("com.sina.weibo") -> "social"
            packageName.startsWith("com.eg.android.AlipayGphone") -> "payment"
            packageName.startsWith("com.taobao") -> "shopping"
            packageName.startsWith("com.jingdong") -> "shopping"
            packageName.startsWith("com.autonavi") -> "navigation"
            packageName.startsWith("com.baidu.BaiduMap") -> "navigation"
            packageName.startsWith("com.ss.android.ugc.aweme") -> "entertainment"
            packageName.startsWith("com.smile.gifmaker") -> "entertainment"
            packageName.startsWith("com.sankuai.meituan") -> "food"
            packageName.startsWith("com.android") ||
                packageName.startsWith("com.google.android") ||
                packageName.startsWith("com.miui") -> "system"
            else -> "unknown"
        }
    }
}
