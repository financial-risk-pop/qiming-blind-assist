import Flutter
import UIKit

/// iOS 屏幕阅读 Platform Channel
///
/// iOS 受沙箱限制，无法获取其他 App 的 UI 元素树。
/// 因此本 Channel 的能力有限，主要提供：
/// - 获取本 App 的可访问性元素（用于演示/调试）
/// - 提示用户 iOS 需要依赖路径 2（屏幕截图 + AI 视觉理解）
///
/// 未来集成：iOS 16+ 可考虑使用 ScreenCaptureKit 进行屏幕分享截取
///
/// Method Channel：com.blindassist/screen_reader
/// Event Channel：com.blindassist/screen_reader/events
class ScreenReaderChannel: NSObject {

    private static let methodChannelName = "com.blindassist/screen_reader"
    private static let eventChannelName = "com.blindassist/screen_reader/events"

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private let eventStreamHandler: ScreenEventStreamHandler

    init(messenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(
            name: Self.methodChannelName,
            binaryMessenger: messenger
        )
        self.eventChannel = FlutterEventChannel(
            name: Self.eventChannelName,
            binaryMessenger: messenger
        )
        self.eventStreamHandler = ScreenEventStreamHandler()

        super.init()

        self.methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        self.eventChannel.setStreamHandler(self.eventStreamHandler)

        NSLog("[ScreenReaderChannel] 已注册（iOS 能力受限）")
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isServiceEnabled":
            // iOS 无专门的无障碍服务开关，返回 true（功能由路径 2 实现）
            result(true)

        case "getScreenElements":
            // iOS 沙箱限制，无法获取其他 App 的 UI，返回空
            result("[]")

        case "getCurrentAppInfo":
            let info: [String: Any?] = [
                "packageName": Bundle.main.bundleIdentifier ?? "",
                "appName": Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "BlindAssist",
                "currentActivity": nil,
                "category": "tool",
                "description": "iOS 平台，请使用 AI 视觉模式解读屏幕"
            ]
            result(info)

        case "getElementAt":
            result(nil)

        case "findElements":
            result("[]")

        case "performAction":
            // iOS 无法代理执行其他 App 的操作
            NSLog("[ScreenReaderChannel] performAction 在 iOS 上不支持")
            result(false)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    deinit {
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
    }
}

/// 屏幕事件流处理器
///
/// iOS 上可以监听的变化有限，主要是 VoiceOver 焦点变化通知。
class ScreenEventStreamHandler: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events

        // 监听 VoiceOver 焦点变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onVoiceOverFocusChanged(_:)),
            name: UIAccessibility.elementFocusedNotification,
            object: nil
        )

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        eventSink = nil
        return nil
    }

    @objc private func onVoiceOverFocusChanged(_ notification: Notification) {
        guard let sink = eventSink else { return }

        let event: [String: Any?] = [
            "changeType": "content_update",
            "packageName": Bundle.main.bundleIdentifier ?? "",
            "className": "",
            "appName": Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "BlindAssist",
            "description": "VoiceOver 焦点变化",
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        sink(event)
    }
}
