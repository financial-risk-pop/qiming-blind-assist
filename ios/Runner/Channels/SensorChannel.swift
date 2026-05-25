import Flutter
import CoreMotion
import UIKit

/// iOS 传感器 Platform Channel
///
/// 查询设备传感器硬件信息（由 sensors_plus 插件处理实时数据流）
///
/// Channel 名称：com.blindassist/sensors
class SensorChannel: NSObject {

    private static let channelName = "com.blindassist/sensors"
    private let channel: FlutterMethodChannel
    private let motionManager = CMMotionManager()

    init(messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        super.init()
        self.channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        NSLog("[SensorChannel] 已注册")
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAvailableSensors":
            result(availableSensors())

        case "hasSensor":
            let type = (call.arguments as? [String: Any])?["type"] as? String ?? ""
            result(hasSensor(type: type))

        case "getSensorInfo":
            let type = (call.arguments as? [String: Any])?["type"] as? String ?? ""
            result(getSensorInfo(type: type))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func availableSensors() -> [[String: Any?]] {
        var sensors: [[String: Any?]] = []
        if motionManager.isAccelerometerAvailable {
            sensors.append(sensorInfo(name: "Accelerometer", typeName: "accelerometer"))
        }
        if motionManager.isGyroAvailable {
            sensors.append(sensorInfo(name: "Gyroscope", typeName: "gyroscope"))
        }
        if motionManager.isMagnetometerAvailable {
            sensors.append(sensorInfo(name: "Magnetometer", typeName: "magnetometer"))
        }
        if motionManager.isDeviceMotionAvailable {
            sensors.append(sensorInfo(name: "DeviceMotion", typeName: "device_motion"))
        }
        // iOS 气压计
        if CMAltimeter.isRelativeAltitudeAvailable() {
            sensors.append(sensorInfo(name: "Barometer", typeName: "pressure"))
        }
        // iOS 步数计
        // 需要运动权限，此处只列出可用性
        return sensors
    }

    private func hasSensor(type: String) -> Bool {
        switch type.lowercased() {
        case "accelerometer": return motionManager.isAccelerometerAvailable
        case "gyroscope": return motionManager.isGyroAvailable
        case "magnetometer": return motionManager.isMagnetometerAvailable
        case "pressure": return CMAltimeter.isRelativeAltitudeAvailable()
        case "device_motion": return motionManager.isDeviceMotionAvailable
        default: return false
        }
    }

    private func getSensorInfo(type: String) -> [String: Any?]? {
        if hasSensor(type: type) {
            return sensorInfo(name: type, typeName: type)
        }
        return nil
    }

    private func sensorInfo(name: String, typeName: String) -> [String: Any?] {
        return [
            "name": name,
            "typeName": typeName,
            "vendor": "Apple",
            "maxRange": nil,
            "resolution": nil,
            "power": nil
        ]
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }
}
