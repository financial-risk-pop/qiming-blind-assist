import '../entities/ocr_result.dart';
import '../repositories/ocr_repository.dart';

/// 文字识别用例
class RecognizeTextUseCase {
  final OcrRepository _repository;

  RecognizeTextUseCase(this._repository);

  /// 从摄像头识别（单次拍照识别）
  Future<OcrResult> fromCamera({OcrMode mode = OcrMode.auto}) {
    return _repository.recognizeFromCamera(mode: mode);
  }

  /// 从图片文件识别
  Future<OcrResult> fromImage(String imagePath, {OcrMode mode = OcrMode.auto}) {
    return _repository.recognizeFromImage(imagePath, mode: mode);
  }

  /// 启动实时识别流
  Stream<OcrResult> realtimeStream() {
    return _repository.startRealTimeOcr();
  }

  /// 停止实时识别
  Future<void> stopRealtimeRecognition() {
    return _repository.stopRealTimeOcr();
  }
}
