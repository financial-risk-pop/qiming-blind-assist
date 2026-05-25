import Flutter
import UIKit

/// 盲人智能辅助 App - iOS AppDelegate
///
/// 职责：
/// 1. 注册 Flutter 插件
/// 2. 配置 Platform Channel（无障碍、屏幕阅读、传感器）
/// 3. 配置应用级别的行为（屏幕常亮、后台任务等）
@main
@objc class AppDelegate: FlutterAppDelegate {

    // Platform Channel 实例（持有强引用，防止被释放）
    private var accessibilityChannel: AccessibilityChannel?
    private var screenReaderChannel: ScreenReaderChannel?
    private var sensorChannel: SensorChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 注册所有 Flutter 插件
        GeneratedPluginRegistrant.register(with: self)

        // 获取 FlutterViewController（Flutter 引擎入口）
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        // 注册 Platform Channels
        let messenger = controller.binaryMessenger
        accessibilityChannel = AccessibilityChannel(messenger: messenger)
        screenReaderChannel = ScreenReaderChannel(messenger: messenger)
        sensorChannel = SensorChannel(messenger: messenger)

        // 保持屏幕常亮（导航/检测场景必需）
        application.isIdleTimerDisabled = true

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
