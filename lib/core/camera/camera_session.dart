import 'dart:async';

import 'package:camera/camera.dart';

import '../utils/logger.dart';

/// 摄像头初始化结果
class CameraInitResult {
  final bool isSuccess;
  final CameraController? controller;
  final String message;
  final String detail;

  const CameraInitResult({
    required this.isSuccess,
    this.controller,
    required this.message,
    this.detail = '',
  });
}

/// 极简摄像头会话管理
///
/// 核心原则：**绝对不卡死**
/// - 不用 permission_handler
/// - 所有 await 都有硬超时（Future.any 双保险）
/// - 任何异常都 catch
class CameraSession {
  /// 初始化摄像头
  ///
  /// **保证 12 秒内必返回结果**（成功或失败）
  static Future<CameraInitResult> initCamera({
    ResolutionPreset resolution = ResolutionPreset.medium,
    bool enableAudio = false,
  }) async {
    AppLogger.info('>>> initCamera 开始', tag: 'CameraSession');

    // ===== 硬超时保护：12 秒后无论如何都返回 =====
    final completer = Completer<CameraInitResult>();

    // 超时定时器
    final timer = Timer(const Duration(seconds: 12), () {
      if (!completer.isCompleted) {
        AppLogger.warning('initCamera 硬超时 12s', tag: 'CameraSession');
        completer.complete(const CameraInitResult(
          isSuccess: false,
          message: '摄像头启动超时（12秒）',
          detail: '摄像头初始化超过12秒未响应。\n\n'
              '可能原因：\n'
              '1) 摄像头权限未授予\n'
              '2) 摄像头被其他App占用\n'
              '3) 系统资源不足\n\n'
              '请到「设置 → 应用 → 启明 → 权限」检查摄像头权限。',
        ));
      }
    });

    // 实际初始化
    _doInit(resolution, enableAudio).then((result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      } else {
        // 超时后才完成的，释放资源
        result.controller?.dispose();
      }
    }).catchError((e, st) {
      if (!completer.isCompleted) {
        AppLogger.error('initCamera 未知异常: $e',
            tag: 'CameraSession', error: e, stackTrace: st);
        completer.complete(CameraInitResult(
          isSuccess: false,
          message: '摄像头启动异常',
          detail: '$e',
        ));
      }
    });

    final result = await completer.future;
    timer.cancel();
    AppLogger.info('>>> initCamera 完成: ${result.isSuccess} - ${result.message}',
        tag: 'CameraSession');
    return result;
  }

  static Future<CameraInitResult> _doInit(
    ResolutionPreset resolution,
    bool enableAudio,
  ) async {
    // Step 1: 列出摄像头
    AppLogger.info('Step1: availableCameras', tag: 'CameraSession');
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      AppLogger.error('availableCameras 异常: $e', tag: 'CameraSession');
      return CameraInitResult(
        isSuccess: false,
        message: '无法访问摄像头',
        detail: '$e\n\n可能是摄像头权限未授予。',
      );
    }

    if (cameras.isEmpty) {
      return const CameraInitResult(
        isSuccess: false,
        message: '未检测到摄像头',
        detail: '设备没有可用的摄像头，或摄像头权限未授予。\n\n'
            '请到「设置 → 应用 → 启明 → 权限」开启摄像头权限。',
      );
    }
    AppLogger.info('Step1 完成: ${cameras.length}个摄像头', tag: 'CameraSession');

    // Step 2: 选后置
    final cam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // Step 3: 初始化
    AppLogger.info('Step2: controller.initialize', tag: 'CameraSession');
    final controller = CameraController(
      cam,
      resolution,
      enableAudio: enableAudio,
    );

    try {
      await controller.initialize();
    } catch (e) {
      AppLogger.warning('controller.initialize 失败: $e', tag: 'CameraSession');
      try {
        await controller.dispose();
      } catch (_) {}

      final msg = e.toString().toLowerCase();
      if (msg.contains('denied') || msg.contains('permission')) {
        return CameraInitResult(
          isSuccess: false,
          message: '摄像头权限未授予',
          detail: '请到「设置 → 应用 → 启明 → 权限」开启摄像头权限。\n\n详情：$e',
        );
      }
      return CameraInitResult(
        isSuccess: false,
        message: '摄像头启动失败',
        detail: '$e',
      );
    }

    AppLogger.info('Step2 完成: 摄像头就绪', tag: 'CameraSession');
    return CameraInitResult(
      isSuccess: true,
      controller: controller,
      message: '准备就绪',
    );
  }
}
