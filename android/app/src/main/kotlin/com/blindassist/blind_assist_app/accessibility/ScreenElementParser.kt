package com.blindassist.blind_assist_app.accessibility

import android.graphics.Rect
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

/**
 * 屏幕元素解析器
 * 
 * 将 Android AccessibilityNodeInfo 节点树转换为 Flutter 端可消费的 Map 结构。
 * 
 * 输出的 Map 字段与 Flutter 端 ScreenElement 实体对齐：
 * - id: 元素唯一标识（viewId 或生成的 uuid）
 * - elementType: 元素类型（button/text/edittext/image/icon/...）
 * - text: 显示文本
 * - contentDescription: 无障碍描述
 * - bounds: [left, top, right, bottom]
 * - isClickable / isScrollable / isFocused / isVisible / isChecked
 * - children: 子元素数组
 */
object ScreenElementParser {

    private const val TAG = "ScreenElementParser"
    private const val MAX_DEPTH = 20

    /**
     * 解析根窗口，返回顶层元素列表
     */
    fun parseRootWindow(root: AccessibilityNodeInfo?): List<Map<String, Any?>> {
        if (root == null) return emptyList()
        val result = mutableListOf<Map<String, Any?>>()
        for (i in 0 until root.childCount) {
            val child = root.getChild(i) ?: continue
            result.add(parseNode(child, depth = 0))
        }
        return result
    }

    /**
     * 在指定坐标查找元素
     */
    fun findElementAt(
        root: AccessibilityNodeInfo?,
        x: Int,
        y: Int
    ): Map<String, Any?>? {
        if (root == null) return null

        // 深度优先搜索：找到最深（最具体）的包含该点的节点
        var found: AccessibilityNodeInfo? = null
        val bounds = Rect()

        fun search(node: AccessibilityNodeInfo, depth: Int) {
            if (depth > MAX_DEPTH) return
            node.getBoundsInScreen(bounds)
            if (!bounds.contains(x, y)) return

            // 记录当前节点（更深的会覆盖）
            found = node

            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                search(child, depth + 1)
            }
        }

        search(root, 0)
        return found?.let { parseNode(it, depth = 0, includeChildren = false) }
    }

    /**
     * 按文本/描述/viewId 搜索元素
     */
    fun findElementsByQuery(
        root: AccessibilityNodeInfo?,
        query: String
    ): List<Map<String, Any?>> {
        if (root == null || query.isBlank()) return emptyList()
        val q = query.trim().lowercase()
        val result = mutableListOf<Map<String, Any?>>()

        fun traverse(node: AccessibilityNodeInfo, depth: Int) {
            if (depth > MAX_DEPTH) return

            val text = node.text?.toString()?.lowercase() ?: ""
            val desc = node.contentDescription?.toString()?.lowercase() ?: ""
            val viewId = node.viewIdResourceName?.lowercase() ?: ""

            if (text.contains(q) || desc.contains(q) || viewId.contains(q)) {
                result.add(parseNode(node, depth = 0, includeChildren = false))
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                traverse(child, depth + 1)
            }
        }

        traverse(root, 0)
        return result
    }

    // ==================== 核心解析 ====================

    private fun parseNode(
        node: AccessibilityNodeInfo,
        depth: Int,
        includeChildren: Boolean = true
    ): Map<String, Any?> {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)

        val children = mutableListOf<Map<String, Any?>>()
        if (includeChildren && depth < MAX_DEPTH) {
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                children.add(parseNode(child, depth + 1, includeChildren = true))
            }
        }

        return mapOf(
            "id" to (node.viewIdResourceName ?: generateId(node)),
            "elementType" to inferElementType(node),
            "text" to node.text?.toString(),
            "contentDescription" to node.contentDescription?.toString(),
            "className" to (node.className?.toString() ?: ""),
            "bounds" to listOf(bounds.left, bounds.top, bounds.right, bounds.bottom),
            "isClickable" to node.isClickable,
            "isScrollable" to node.isScrollable,
            "isFocused" to node.isFocused,
            "isVisible" to node.isVisibleToUser,
            "isChecked" to if (node.isCheckable) node.isChecked else null,
            "isEnabled" to node.isEnabled,
            "isEditable" to node.isEditable,
            "children" to children,
            "indexInParent" to null
        )
    }

    private fun generateId(node: AccessibilityNodeInfo): String {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        return "node_${node.className}_${bounds.left}_${bounds.top}"
    }

    /**
     * 根据节点的 className 推断元素类型
     * 
     * 映射到 Flutter 端 ScreenElementType 的字符串值
     */
    private fun inferElementType(node: AccessibilityNodeInfo): String {
        val cls = node.className?.toString() ?: ""
        return when {
            cls.contains("Button", ignoreCase = true) -> "button"
            cls.contains("EditText", ignoreCase = true) -> "edittext"
            cls.contains("TextView", ignoreCase = true) -> "text"
            cls.contains("ImageView", ignoreCase = true) -> "image"
            cls.contains("ImageButton", ignoreCase = true) -> "icon"
            cls.contains("CheckBox", ignoreCase = true) -> "checkbox"
            cls.contains("RadioButton", ignoreCase = true) -> "radio"
            cls.contains("Switch", ignoreCase = true) -> "switch"
            cls.contains("Toggle", ignoreCase = true) -> "toggle"
            cls.contains("SeekBar", ignoreCase = true) -> "seekbar"
            cls.contains("ProgressBar", ignoreCase = true) -> "progress"
            cls.contains("RecyclerView", ignoreCase = true) -> "list"
            cls.contains("ListView", ignoreCase = true) -> "list"
            cls.contains("TabLayout", ignoreCase = true) -> "tab"
            cls.contains("Toolbar", ignoreCase = true) -> "toolbar"
            cls.contains("BottomNavigationView", ignoreCase = true) -> "navigation"
            cls.contains("Dialog", ignoreCase = true) -> "dialog"
            cls.contains("WebView", ignoreCase = true) -> "webview"
            node.isClickable -> "button"
            else -> "container"
        }
    }
}
