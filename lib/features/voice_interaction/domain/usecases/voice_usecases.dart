import '../entities/voice_command.dart';
import '../repositories/voice_repository.dart';

/// 处理语音指令用例
class ProcessCommandUseCase {
  final VoiceRepository _repository;

  ProcessCommandUseCase(this._repository);

  /// 将原始文本解析为语音指令
  /// 
  /// 如果解析失败，返回类型为 [CommandType.unknown] 的指令
  VoiceCommand call(String rawText) {
    final parsed = _repository.parseCommand(rawText);
    return parsed ??
        VoiceCommand(
          type: CommandType.unknown,
          rawText: rawText,
          timestamp: DateTime.now(),
        );
  }
}

/// 语音播报用例
class SpeakFeedbackUseCase {
  final VoiceRepository _repository;

  SpeakFeedbackUseCase(this._repository);

  /// 播报文本
  Future<void> call(String text, {bool interrupt = false}) {
    return _repository.speak(text, interrupt: interrupt);
  }

  /// 停止播报
  Future<void> stop() {
    return _repository.stopSpeaking();
  }
}
