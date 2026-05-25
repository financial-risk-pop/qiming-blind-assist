import 'package:permission_handler/permission_handler.dart';

/// 统一权限请求管理器
/// 
/// 盲人辅助App需要多种系统权限，此管理器：
/// 1. 统一管理所有权限请求逻辑
/// 2. 在请求前通过TTS告知用户为什么需要此权限
/// 3. 跟踪权限状态
class PermissionManager {
  /// 检查并请求所有核心权限
  Future<Map<Permission, PermissionStatus>> requestCorePermissions() async {
    return await [
      Permission.camera,           // 摄像头（障碍物检测+OCR）
      Permission.microphone,       // 麦克风（语音交互）
      Permission.location,         // 定位（导航）
      Permission.locationAlways,   // 后台定位（导航中切到后台）
    ].request();
  }

  /// 检查摄像头权限
  Future<bool> ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// 检查麦克风权限
  Future<bool> ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// 检查定位权限
  Future<bool> ensureLocationPermission() async {
    final status = await Permission.location.status;
    if (status.isGranted) return true;
    final result = await Permission.location.request();
    return result.isGranted;
  }

  /// 获取所有权限状态
  Future<Map<String, bool>> getAllPermissionStatus() async {
    return {
      '摄像头': await Permission.camera.isGranted,
      '麦克风': await Permission.microphone.isGranted,
      '定位': await Permission.location.isGranted,
      '后台定位': await Permission.locationAlways.isGranted,
    };
  }

  /// 检查是否所有核心权限都已授予
  Future<bool> areAllCorePermissionsGranted() async {
    final statuses = await getAllPermissionStatus();
    return statuses['摄像头']! && statuses['麦克风']! && statuses['定位']!;
  }

  /// 打开系统设置（当权限被永久拒绝时）
  Future<bool> openSystemSettings() async {
    return await openAppSettings();
  }
}
