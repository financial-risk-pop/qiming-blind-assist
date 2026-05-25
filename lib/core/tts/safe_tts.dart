import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// 安全的 TTS —— 走 Android 原生 TextToSpeech
class SafeTts {
  static const _channel = MethodChannel('com.blindassist/tts');

  void init() {
    // 确保媒体音量不是静音
    _ensureVolume();
  }

  Future<void> _ensureVolume() async {
    try {
      await _channel.invokeMethod('ensureVolume').timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
    } catch (_) {}
  }

  /// 说话
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _channel.invokeMethod('speak', {'text': text}).timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
    } catch (e) {
      AppLogger.warning('SafeTts.speak 异常: $e', tag: 'SafeTts');
    }
  }

  /// 停止
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop').timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
    } catch (_) {}
  }

  /// 检查是否就绪（最多等 3 秒）
  Future<bool> isReady() async {
    for (int i = 0; i < 6; i++) {
      try {
        final r = await _channel.invokeMethod<bool>('isReady').timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => false,
        );
        if (r == true) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// 获取详细状态（用于诊断）
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final r = await _channel.invokeMethod<Map>('getStatus').timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (r != null) return Map<String, dynamic>.from(r);
    } catch (_) {}
    return {'ready': false, 'initStatus': 'unknown'};
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    try {
      await _channel.invokeMethod('setSpeechRate', {'rate': rate}).timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
    } catch (_) {}
  }

  void dispose() {
    stop();
  }
}
