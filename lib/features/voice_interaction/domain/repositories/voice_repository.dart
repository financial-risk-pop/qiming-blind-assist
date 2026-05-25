import '../entities/voice_command.dart';

/// 语音交互仓库接口
abstract class VoiceRepository {
  /// 当前语音状态（可选实现）
  VoiceState get currentState;

  /// 语音状态变化流
  Stream<VoiceState> get stateStream;

  // ===== 语音识别（ASR）=====

  /// 单次语音识别（带超时）
  /// 
  /// 返回识别到的文本，超时或失败时返回空字符串
  Future<String> recognizeSpeech({Duration? timeout});

  /// 启动持续监听模式
  /// 
  /// 返回实时识别结果流
  Stream<String> startContinuousListening();

  /// 停止语音识别
  Future<void> stopListening();

  // ===== 指令解析 =====

  /// 将自然语言文本解析为结构化指令
  /// 
  /// 返回 null 表示未识别到任何有效指令
  VoiceCommand? parseCommand(String text);

  // ===== 语音合成（TTS）=====

  /// 语音播报
  /// 
  /// [interrupt] 是否打断当前播报，默认加入队列
  Future<void> speak(String text, {bool interrupt = false});

  /// 带优先级的语音播报
  /// 
  /// [priority] 优先级，数字越大越先播报
  /// [interruptCurrent] 是否打断当前播报
  Future<void> speakWithPriority(
    String text, {
    required int priority,
    bool interruptCurrent = false,
  });

  /// 停止当前播报
  Future<void> stopSpeaking();

  // ===== TTS配置 =====

  /// 更新语速 (0.0 - 1.0)
  Future<void> updateSpeechRate(double rate);

  /// 更新音量 (0.0 - 1.0)
  Future<void> updateVolume(double volume);

  /// 更新音调 (0.5 - 2.0)
  Future<void> updatePitch(double pitch);
}
