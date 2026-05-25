import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../utils/logger.dart';

class SpeechInitResult {
  final bool isSuccess;
  final SpeechToText? speech;
  final String message;
  final String detail;

  const SpeechInitResult({
    required this.isSuccess,
    this.speech,
    required this.message,
    this.detail = '',
  });
}

/// 极简语音识别会话管理
///
/// 核心原则：**绝对不卡死**
/// - 不用 permission_handler
/// - 硬超时保护
class SpeechSession {
  /// 初始化语音识别
  ///
  /// **保证 8 秒内必返回结果**
  static Future<SpeechInitResult> initSpeech({
    Function(String)? onStatus,
    Function(dynamic)? onError,
  }) async {
    AppLogger.info('>>> initSpeech 开始', tag: 'SpeechSession');

    final completer = Completer<SpeechInitResult>();

    // 硬超时
    final timer = Timer(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        AppLogger.warning('initSpeech 硬超时 8s', tag: 'SpeechSession');
        completer.complete(const SpeechInitResult(
          isSuccess: false,
          message: '语音识别初始化超时（8秒）',
          detail: '语音引擎8秒未响应。\n\n'
              '可能原因：\n'
              '1) 麦克风权限未授予\n'
              '2) 手机没装中文语音包\n'
              '3) Google语音服务被禁用\n\n'
              '请到「设置 → 应用 → 启明 → 权限」检查麦克风权限。',
        ));
      }
    });

    _doInit(onStatus, onError).then((result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }).catchError((e, st) {
      if (!completer.isCompleted) {
        AppLogger.error('initSpeech 异常: $e',
            tag: 'SpeechSession', error: e, stackTrace: st);
        completer.complete(SpeechInitResult(
          isSuccess: false,
          message: '语音识别初始化异常',
          detail: '$e',
        ));
      }
    });

    final result = await completer.future;
    timer.cancel();
    AppLogger.info('>>> initSpeech 完成: ${result.isSuccess} - ${result.message}',
        tag: 'SpeechSession');
    return result;
  }

  static Future<SpeechInitResult> _doInit(
    Function(String)? onStatus,
    Function(dynamic)? onError,
  ) async {
    final speech = SpeechToText();
    bool ok = false;

    try {
      ok = await speech.initialize(
        onStatus: onStatus,
        onError: onError,
      );
    } catch (e) {
      AppLogger.warning('speech.initialize 异常: $e', tag: 'SpeechSession');
      final msg = e.toString().toLowerCase();
      if (msg.contains('denied') || msg.contains('permission')) {
        return SpeechInitResult(
          isSuccess: false,
          message: '麦克风权限未授予',
          detail: '请到「设置 → 应用 → 启明 → 权限」开启麦克风权限。\n\n详情：$e',
        );
      }
      return SpeechInitResult(
        isSuccess: false,
        message: '语音识别初始化失败',
        detail: '$e',
      );
    }

    if (!ok) {
      return const SpeechInitResult(
        isSuccess: false,
        message: '语音识别不可用',
        detail: '常见原因：\n'
            '1) 麦克风权限未授予\n'
            '2) 手机没装中文语音包\n'
            '3) Google语音服务被禁用\n\n'
            '解决方法：\n'
            '• 到「设置 → 应用 → 启明 → 权限」开启麦克风\n'
            '• 到「设置 → 系统 → 语言 → 语音」检查语音引擎',
      );
    }

    return SpeechInitResult(
      isSuccess: true,
      speech: speech,
      message: '准备就绪',
    );
  }
}
