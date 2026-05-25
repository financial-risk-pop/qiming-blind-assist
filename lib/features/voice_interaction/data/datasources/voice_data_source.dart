import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';

/// 语音数据源 - 封装ASR语音识别和TTS语音合成的底层实现
/// 
/// 核心职责：
/// 1. ASR：管理SpeechToText的生命周期和回调
/// 2. TTS：管理FlutterTts的播报队列和打断逻辑
/// 3. 唤醒词检测：监听"小助手"关键词
class VoiceDataSource {
  final SpeechToText _speech;
  final FlutterTts _tts;

  // ASR状态
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isInitialized = false;

  // TTS播报队列（支持优先级排序）
  final List<_SpeakTask> _speakQueue = [];
  bool _isProcessingQueue = false;

  // 语音识别结果流
  final _recognitionController = StreamController<String>.broadcast();
  final _partialResultController = StreamController<String>.broadcast();
  final _stateController = StreamController<VoiceSourceState>.broadcast();

  VoiceDataSource({
    SpeechToText? speech,
    FlutterTts? tts,
  })  : _speech = speech ?? SpeechToText(),
        _tts = tts ?? FlutterTts();

  /// 语音识别最终结果流
  Stream<String> get recognitionResults => _recognitionController.stream;

  /// 语音识别部分结果流（实时反馈）
  Stream<String> get partialResults => _partialResultController.stream;

  /// 数据源状态流
  Stream<VoiceSourceState> get stateStream => _stateController.stream;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  // ==================== 初始化 ====================

  /// 初始化语音服务
  /// 
  /// 关键策略：TTS 和 ASR 独立初始化，任一失败都不影响另一个
  /// - TTS 不需要权限，应当尽量成功
  /// - ASR 需要麦克风权限，可能失败
  Future<void> initialize() async {
    // === TTS 先初始化（不需要权限） ===
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // TTS回调
      _tts.setStartHandler(() {
        _isSpeaking = true;
        _stateController.add(VoiceSourceState.speaking);
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _stateController.add(VoiceSourceState.idle);
        _processNextInQueue();
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _processNextInQueue();
      });

      _tts.setErrorHandler((message) {
        _isSpeaking = false;
        AppLogger.error('TTS错误: $message', tag: 'VoiceDataSource');
        _processNextInQueue();
      });

      AppLogger.info('TTS 初始化完成', tag: 'VoiceDataSource');
    } catch (e) {
      AppLogger.warning('TTS 初始化失败: $e', tag: 'VoiceDataSource');
    }

    // === ASR 再初始化（需要麦克风权限，失败不影响 TTS） ===
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );

      if (!_isInitialized) {
        AppLogger.warning('ASR 未就绪（可能缺少麦克风权限）',
            tag: 'VoiceDataSource');
      } else {
        AppLogger.info('ASR 初始化完成', tag: 'VoiceDataSource');
      }
    } catch (e) {
      AppLogger.warning('ASR 初始化失败: $e', tag: 'VoiceDataSource');
      _isInitialized = false;
    }

    AppLogger.info('语音服务初始化完成（TTS可用=true, ASR可用=$_isInitialized）',
        tag: 'VoiceDataSource');
  }

  // ==================== ASR语音识别 ====================

  /// 开始单次语音识别
  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (!_isInitialized) {
      throw const DeviceException(message: '语音服务未初始化');
    }

    // 如果正在播报，先停止
    if (_isSpeaking) {
      await stopSpeaking();
      // 短暂延迟确保TTS完全停止
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isListening = true;
    _stateController.add(VoiceSourceState.listening);

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _recognitionController.add(result.recognizedWords);
        } else {
          _partialResultController.add(result.recognizedWords);
        }
      },
      listenFor: listenFor ?? const Duration(seconds: 10),
      pauseFor: pauseFor ?? const Duration(seconds: 3),
      localeId: 'zh_CN',
      cancelOnError: true,
      listenMode: ListenMode.dictation,
    );
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
    _stateController.add(VoiceSourceState.idle);
  }

  /// 获取可用的语音识别语言列表
  Future<List<String>> getAvailableLocales() async {
    final locales = await _speech.locales();
    return locales.map((l) => l.localeId).toList();
  }

  // ==================== TTS语音合成 ====================

  /// 播报文本（直接播报，打断当前内容）
  /// 
  /// [text] 待播报文本；会自动跳过空字符串
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      AppLogger.warning('尝试播报空文本，已跳过', tag: 'VoiceDataSource');
      return;
    }

    // 先停止当前播报
    if (_isSpeaking) {
      await _tts.stop();
      // 等待系统回调将 _isSpeaking 置 false，避免竞态
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isSpeaking = true;
    _stateController.add(VoiceSourceState.speaking);
    await _tts.speak(text);
  }

  /// 将文本加入播报队列（按优先级排序）
  /// 
  /// [text] 待播报内容
  /// [priority] 优先级（数字越大越先播报，默认 0）
  ///   - 10: critical（障碍物紧急警报）
  ///   - 5:  navigation（导航指令）
  ///   - 1:  information（一般信息）
  /// [interruptCurrent] 为 true 时立即清空队列+打断当前播报
  /// 
  /// 设计特性：
  /// - 同优先级按入队时间 FIFO
  /// - 自动去重：连续的相同文本不重复加入
  /// - 空文本自动忽略
  void enqueueSpeak(String text, {int priority = 0, bool interruptCurrent = false}) {
    if (text.trim().isEmpty) return;

    if (interruptCurrent) {
      // 紧急打断：清空队列并立即播报
      _speakQueue.clear();
      speak(text);
      return;
    }

    // 去重：如果队尾已经有相同文本（3 秒内），跳过
    if (_speakQueue.isNotEmpty) {
      final last = _speakQueue.last;
      if (last.text == text &&
          DateTime.now().difference(last.enqueuedAt).inSeconds < 3) {
        AppLogger.debug('跳过重复播报: "$text"', tag: 'VoiceDataSource');
        return;
      }
    }

    _speakQueue.add(_SpeakTask(
      text: text,
      priority: priority,
      enqueuedAt: DateTime.now(),
    ));

    // 按优先级倒序排，同优先级保持 FIFO
    _speakQueue.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      return a.enqueuedAt.compareTo(b.enqueuedAt);
    });

    if (!_isProcessingQueue && !_isSpeaking) {
      _processNextInQueue();
    }
  }

  /// 处理队列中下一个播报任务
  void _processNextInQueue() {
    if (_speakQueue.isEmpty) {
      _isProcessingQueue = false;
      return;
    }

    _isProcessingQueue = true;
    final task = _speakQueue.removeAt(0);
    speak(task.text);
  }

  /// 当前队列长度（供调试 / UI 展示）
  int get pendingSpeechCount => _speakQueue.length;

  /// 清空播报队列
  void clearSpeechQueue() {
    _speakQueue.clear();
  }

  /// 停止当前播报
  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    await _tts.stop();
  }

  /// 更新TTS参数
  Future<void> updateTtsConfig({
    double? speechRate,
    double? volume,
    double? pitch,
    String? language,
  }) async {
    if (speechRate != null) await _tts.setSpeechRate(speechRate);
    if (volume != null) await _tts.setVolume(volume);
    if (pitch != null) await _tts.setPitch(pitch);
    if (language != null) await _tts.setLanguage(language);
  }

  // ==================== 内部回调 ====================

  void _onSpeechStatus(String status) {
    AppLogger.debug('ASR状态: $status', tag: 'VoiceDataSource');
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      _stateController.add(VoiceSourceState.idle);
    }
  }

  void _onSpeechError(dynamic error) {
    AppLogger.error('ASR错误: $error', tag: 'VoiceDataSource');
    _isListening = false;
    _stateController.add(VoiceSourceState.error);
  }

  // ==================== 资源释放 ====================

  Future<void> dispose() async {
    await _speech.stop();
    await _tts.stop();
    await _recognitionController.close();
    await _partialResultController.close();
    await _stateController.close();
  }
}

/// 语音数据源状态
enum VoiceSourceState {
  idle,
  listening,
  speaking,
  error,
}

/// 播报任务（内部用）
class _SpeakTask {
  final String text;
  final int priority;
  final DateTime enqueuedAt;

  _SpeakTask({
    required this.text,
    this.priority = 0,
    required this.enqueuedAt,
  });
}
