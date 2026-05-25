import 'dart:async';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// 原生语音识别服务 V2
///
/// 双模式：
/// 1. SpeechRecognizer（后台静默）
/// 2. Intent（弹系统语音 UI）—— 几乎所有手机都支持
class NativeSpeech {
  static const _method = MethodChannel('com.blindassist/speech');
  static const _event = EventChannel('com.blindassist/speech_events');

  StreamSubscription? _sub;

  void Function(String text)? onResult;
  void Function(String text)? onPartial;
  void Function(String status)? onStatus;
  void Function(String error)? onError;

  /// 检查 SpeechRecognizer 是否可用
  static Future<bool> isAvailable() async {
    try {
      return await _method
              .invokeMethod<bool>('isAvailable')
              .timeout(const Duration(seconds: 3)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 检查 Intent 方式是否可用（几乎所有手机都支持）
  static Future<bool> isIntentAvailable() async {
    try {
      return await _method
              .invokeMethod<bool>('isIntentAvailable')
              .timeout(const Duration(seconds: 3)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 用 SpeechRecognizer 开始监听（后台静默）
  Future<void> startListening() async {
    _sub?.cancel();
    _sub = _event.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type']?.toString() ?? '';
          final data = event['data']?.toString() ?? '';
          switch (type) {
            case 'result':
              onResult?.call(data);
              break;
            case 'partial':
              onPartial?.call(data);
              break;
            case 'status':
              onStatus?.call(data);
              break;
            case 'error':
              onError?.call(data);
              break;
          }
        }
      },
      onError: (e) => onError?.call('$e'),
    );
    try {
      await _method.invokeMethod('startListening');
    } catch (e) {
      onError?.call('启动失败: $e');
    }
  }

  /// 用 Intent 弹出系统语音 UI（备选方案）
  ///
  /// 返回识别到的文字，null 或空字符串表示失败/取消
  Future<String?> startListeningWithIntent() async {
    try {
      final result = await _method
          .invokeMethod<String>('startListeningWithIntent')
          .timeout(const Duration(seconds: 30));
      return result;
    } catch (e) {
      AppLogger.warning('Intent 语音识别异常: $e', tag: 'NativeSpeech');
      return null;
    }
  }

  Future<void> stopListening() async {
    try {
      await _method.invokeMethod('stopListening');
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _method.invokeMethod('cancel');
    } catch (_) {}
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    cancel();
  }
}
