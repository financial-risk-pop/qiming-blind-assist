import 'dart:async';

import '../../domain/entities/voice_command.dart';
import '../../domain/repositories/voice_repository.dart';
import '../datasources/voice_data_source.dart';
import '../parsers/command_parser.dart';
import '../../../../core/utils/logger.dart';

/// 语音仓库实现
/// 
/// 连接底层数据源和领域层，实现完整的语音交互流程：
/// 1. ASR语音识别 → 指令解析 → 返回VoiceCommand
/// 2. TTS语音合成 → 优先级播报队列
class VoiceRepositoryImpl implements VoiceRepository {
  final VoiceDataSource _dataSource;
  final CommandParser _parser;

  // 上一次播报内容（支持"再说一遍"指令）
  String? _lastSpokenText;

  VoiceRepositoryImpl({
    required VoiceDataSource dataSource,
    CommandParser? parser,
  })  : _dataSource = dataSource,
        _parser = parser ?? CommandParser();

  // ==================== 状态管理 ====================

  @override
  VoiceState get currentState {
    if (_dataSource.isSpeaking) return VoiceState.speaking;
    if (_dataSource.isListening) return VoiceState.commandListening;
    return VoiceState.idle;
  }

  @override
  Stream<VoiceState> get stateStream => _dataSource.stateStream.map(_mapSourceState);

  VoiceState _mapSourceState(VoiceSourceState s) {
    switch (s) {
      case VoiceSourceState.idle:
        return VoiceState.idle;
      case VoiceSourceState.listening:
        return VoiceState.commandListening;
      case VoiceSourceState.speaking:
        return VoiceState.speaking;
      case VoiceSourceState.error:
        return VoiceState.error;
    }
  }

  // ==================== ASR语音识别 ====================

  @override
  Future<String> recognizeSpeech({Duration? timeout}) async {
    final completer = Completer<String>();

    late StreamSubscription<String> subscription;
    subscription = _dataSource.recognitionResults.listen((result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      subscription.cancel();
    });

    // 监听 ASR 状态变化：当 ASR 完成/错误时若还未得到结果，返回空字符串
    late StreamSubscription<VoiceSourceState> stateSubscription;
    stateSubscription = _dataSource.stateStream.listen((voiceState) {
      if (voiceState == VoiceSourceState.idle ||
          voiceState == VoiceSourceState.error) {
        // ASR 已停止但没产生 finalResult，延迟 300ms 再检查
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!completer.isCompleted) {
            subscription.cancel();
            stateSubscription.cancel();
            completer.complete('');
          }
        });
      }
    });

    // 超时处理
    Timer? timer;
    final effectiveTimeout = timeout ?? const Duration(seconds: 10);
    timer = Timer(effectiveTimeout + const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        stateSubscription.cancel();
        _dataSource.stopListening();
        completer.complete('');
      }
    });

    try {
      await _dataSource.startListening(
        listenFor: effectiveTimeout,
      );
    } catch (e) {
      if (!completer.isCompleted) {
        subscription.cancel();
        stateSubscription.cancel();
        timer.cancel();
        completer.complete('');
      }
    }

    final result = await completer.future;
    timer.cancel();
    stateSubscription.cancel();
    return result;
  }

  @override
  Stream<String> startContinuousListening() {
    // 返回实时识别结果流
    return _dataSource.recognitionResults;
  }

  @override
  Future<void> stopListening() async {
    await _dataSource.stopListening();
  }

  // ==================== 指令解析 ====================

  @override
  VoiceCommand? parseCommand(String text) {
    return _parser.parse(text);
  }

  // ==================== TTS语音合成 ====================

  @override
  Future<void> speak(String text, {bool interrupt = false}) async {
    _lastSpokenText = text;

    if (interrupt) {
      await _dataSource.speak(text);
    } else {
      _dataSource.enqueueSpeak(text);
    }
  }

  @override
  Future<void> speakWithPriority(
    String text, {
    required int priority,
    bool interruptCurrent = false,
  }) async {
    _lastSpokenText = text;
    _dataSource.enqueueSpeak(
      text,
      priority: priority,
      interruptCurrent: interruptCurrent,
    );
  }

  @override
  Future<void> stopSpeaking() async {
    await _dataSource.stopSpeaking();
  }

  @override
  Future<void> updateSpeechRate(double rate) async {
    await _dataSource.updateTtsConfig(speechRate: rate);
  }

  @override
  Future<void> updateVolume(double volume) async {
    await _dataSource.updateTtsConfig(volume: volume);
  }

  @override
  Future<void> updatePitch(double pitch) async {
    await _dataSource.updateTtsConfig(pitch: pitch);
  }

  /// 获取上一次播报内容（支持"再说一遍"功能）
  String? get lastSpokenText => _lastSpokenText;

  /// 重复上一次播报
  Future<void> repeatLast() async {
    if (_lastSpokenText != null) {
      await speak(_lastSpokenText!, interrupt: true);
    } else {
      await speak('没有上一条播报内容', interrupt: true);
    }
  }

  // ==================== 初始化和销毁 ====================

  /// 初始化
  Future<void> initialize() async {
    await _dataSource.initialize();
    AppLogger.info('语音仓库初始化完成', tag: 'VoiceRepo');
  }

  /// 销毁
  Future<void> dispose() async {
    await _dataSource.dispose();
  }
}
