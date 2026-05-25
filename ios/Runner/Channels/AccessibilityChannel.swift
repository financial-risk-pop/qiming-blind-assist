import Flutter
import UIKit

/// iOS 无障碍 Platform Channel
///
/// iOS 的无障碍限制：
/// - 无法像 Android 那样获取其他 App 的 UI 树
/// - 主要用于查询 VoiceOver / Switch Control 等系统无障碍状态
/// - App 解读场景主要依赖路径 2（截图 + AI 视觉理解）
///
/// Channel 名称：com.blindassist/accessibility
class AccessibilityChannel: NSObject {

    private static let channelName = "com.blindassist/accessibility"
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        super.init()
        self.channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        NSLog("[AccessibilityChannel] 已注册")
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isServiceEnabled":
            // iOS 用 VoiceOver 运行状态作为无障碍就绪的代理指标
            let enabled = UIAccessibility.isVoiceOverRunning
            result(enabled)

        case "openAccessibilitySettings":
            // iOS 无法直接打开无障碍设置子页面，引导到本 App 的设置页
            if let url = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            result(nil)

        case "getCurrentAppInfo":
            // iOS 无法获取其他 App 的信息，只能返回本 App 自己
            let info: [String: Any?] = [
                "packageName": Bundle.main.bundleIdentifier ?? "",
                "appName": Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "BlindAssist"),
                "currentActivity": nil,
                "category": "tool",
                "description": "盲人智能辅助应用本身"
            ]
            result(info)

        case "isVoiceOverRunning":
            result(UIAccessibility.isVoiceOverRunning)

        case "isSwitchControlRunning":
            result(UIAccessibility.isSwitchControlRunning)

        case "isReduceMotionEnabled":
            result(UIAccessibility.isReduceMotionEnabled)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }
}
