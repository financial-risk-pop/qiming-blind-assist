import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../event_bus/event_bus.dart';
import '../utils/logger.dart';
import '../utils/permission_handler.dart';

/// 权限请求结果
class PermissionFlowResult {
  /// 所有必需权限是否全部授予
  final bool allRequiredGranted;

  /// 每项权限的授予状态
  final Map<PermissionType, bool> results;

  /// 被永久拒绝的权限（需用户到系统设置开启）
  final List<PermissionType> permanentlyDenied;

  const PermissionFlowResult({
    required this.allRequiredGranted,
    required this.results,
    required this.permanentlyDenied,
  });
}

/// 权限类型标识
enum PermissionType {
  camera('摄像头', true, '障碍物检测和文字识别需要摄像头'),
  microphone('麦克风', true, '语音交互功能需要麦克风'),
  location('定位', true, '导航功能需要获取您的位置'),
  notification('通知', false, '紧急警报和导航提醒需要通知权限'),
  locationAlways('后台定位', false, '导航时切换到后台也能持续导航');

  final String label;
  final bool required;   // 是否为核心必需权限
  final String rationale; // 权限用途说明（用于语音引导）

  const PermissionType(this.label, this.required, this.rationale);

  Permission get systemPermission {
    switch (this) {
      case PermissionType.camera:
        return Permission.camera;
      case PermissionType.microphone:
        return Permission.microphone;
      case PermissionType.location:
        return Permission.location;
      case PermissionType.notification:
        return Permission.notification;
      case PermissionType.locationAlways:
        return Permission.locationAlways;
    }
  }
}

/// 权限请求编排器
///
/// 负责 App 首次启动时的权限请求流程：
/// 1. 按顺序请求各项权限
/// 2. 每次请求前通过 TTS 语音说明用途（通过事件总线）
/// 3. 用户拒绝后记录并继续下一项（不强制阻塞）
/// 4. 返回汇总结果，供上层决定是否可进入主流程
///
/// 盲人用户特殊考虑：
/// - 由于看不到系统权限弹窗，我们会在弹窗前用 TTS 提前播报
/// - 在弹窗后等待足够时间给 TalkBack 读完
class PermissionFlow {
  final PermissionManager _permissionManager;
  final EventBus _eventBus;

  PermissionFlow({
    PermissionManager? permissionManager,
    required EventBus eventBus,
  })  : _permissionManager = permissionManager ?? PermissionManager(),
        _eventBus = eventBus;

  /// 执行完整权限请求流程
  ///
  /// [onBeforeRequest] 每次请求前的回调（可用于更新 UI）
  Future<PermissionFlowResult> requestAllRequired({
    ValueChanged<PermissionType>? onBeforeRequest,
  }) async {
    AppLogger.info('开始权限请求流程', tag: 'PermissionFlow');

    // 先欢迎播报
    _announce(
      '您好，欢迎使用启明，我将依次申请必要的权限。',
      interrupt: true,
    );

    final results = <PermissionType, bool>{};
    final permanentlyDenied = <PermissionType>[];

    // 按顺序请求：先 required，再 optional
    final ordered = [
      ...PermissionType.values.where((p) => p.required),
      ...PermissionType.values.where((p) => !p.required),
    ];

    for (final type in ordered) {
      onBeforeRequest?.call(type);

      // 播报用途
      _announce('接下来申请${type.label}权限，${type.rationale}。');

      // 给 TalkBack / 用户足够时间听清说明
      await Future.delayed(const Duration(milliseconds: 800));

      // 真正请求
      final status = await type.systemPermission.request();

      final granted = status.isGranted || status.isLimited;
      results[type] = granted;

      if (status.isPermanentlyDenied) {
        permanentlyDenied.add(type);
        AppLogger.warning('${type.label} 被永久拒绝', tag: 'PermissionFlow');
        _announce(
          '${type.label}权限已被永久拒绝，您可以稍后在系统设置中开启。',
        );
      } else if (granted) {
        AppLogger.info('${type.label} 已授予', tag: 'PermissionFlow');
        _announce('${type.label}权限已授予。');
      } else {
        AppLogger.warning('${type.label} 被拒绝', tag: 'PermissionFlow');
        _announce('${type.label}权限未授予。');
      }

      // 给 TTS 时间完成播报再进入下一项
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // 计算必需权限的综合结果
    final allRequiredGranted = PermissionType.values
        .where((p) => p.required)
        .every((p) => results[p] == true);

    // 最终汇报
    if (allRequiredGranted) {
      _announce('所有必要权限已就绪，现在可以开始使用。', interrupt: true);
    } else {
      _announce(
        '部分必要权限未授予，相关功能将无法使用。您可以随时到设置中重新开启。',
        interrupt: true,
      );
    }

    return PermissionFlowResult(
      allRequiredGranted: allRequiredGranted,
      results: results,
      permanentlyDenied: permanentlyDenied,
    );
  }

  /// 检查当前所有权限状态（不触发请求）
  Future<Map<PermissionType, bool>> checkAll() async {
    final result = <PermissionType, bool>{};
    for (final type in PermissionType.values) {
      final status = await type.systemPermission.status;
      result[type] = status.isGranted || status.isLimited;
    }
    return result;
  }

  /// 打开系统设置页（用于引导用户开启被永久拒绝的权限）
  Future<bool> openSystemSettings() {
    return openAppSettings();
  }

  /// 通过事件总线发送 TTS 播报请求
  void _announce(String text, {bool interrupt = false}) {
    _eventBus.fire(SpeakRequestEvent(
      text: text,
      priority: FeedbackPriority.critical,
      interruptCurrent: interrupt,
      sourceModule: 'permission_flow',
    ));
  }
}
