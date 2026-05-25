import 'package:equatable/equatable.dart';

/// OCR识别结果实体
class OcrResult extends Equatable {
  /// 识别文本
  final String text;

  /// 置信度 0.0-1.0
  final double confidence;

  /// 识别语言
  final String language;

  /// 来源（端侧/云端）
  final OcrSource source;

  /// 识别时间
  final DateTime? timestamp;

  const OcrResult({
    required this.text,
    required this.confidence,
    this.language = 'zh',
    required this.source,
    this.timestamp,
  });

  @override
  List<Object?> get props => [text, confidence, source, timestamp];
}

/// OCR来源
enum OcrSource {
  device('端侧'),
  cloud('云端');

  final String label;
  const OcrSource(this.label);
}

/// OCR模式
enum OcrMode {
  /// 快速模式（端侧）
  fast,
  /// 精细模式（云端）
  fine,
  /// 详细模式（fine 的别名，向后兼容）
  detailed,
  /// 自动模式（先快后精）
  auto,
}
