import '../entities/ocr_result.dart';

/// OCR识别仓库接口
abstract class OcrRepository {
  /// 从摄像头当前画面识别文字
  /// 
  /// [mode] OCR 模式（快速/精细/自动）
  Future<OcrResult> recognizeFromCamera({OcrMode mode = OcrMode.auto});

  /// 从图片文件路径识别文字
  Future<OcrResult> recognizeFromImage(
    String imagePath, {
    OcrMode mode = OcrMode.auto,
  });

  /// 开始实时OCR识别，返回结果流
  Stream<OcrResult> startRealTimeOcr();

  /// 停止实时OCR识别
  Future<void> stopRealTimeOcr();
}
