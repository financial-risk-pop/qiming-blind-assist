import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/ocr_result.dart';

/// 云端 OCR 数据源
///
/// 当端侧 ML Kit 识别置信度低于阈值时降级到云端精细 OCR。
/// 典型使用场景：
/// - 手写体识别
/// - 艺术字 / 牌匾
/// - 低光照 / 低质量图像
///
/// 支持的后端：
/// - 云端 OCR（国内推荐）
/// - 阿里云 OCR
/// - OpenAI Vision
/// - 自建服务
class CloudOcrDataSource {
  final ApiClient _apiClient;

  CloudOcrDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// 云端 OCR 识别
  /// 
  /// [imageData] 图片二进制数据
  /// [mode] 识别模式（目前主要用于精细 OCR）
  Future<OcrResult> recognize(
    Uint8List imageData, {
    OcrMode mode = OcrMode.fine,
  }) async {
    try {
      // 将图片转为 base64
      final base64Image = base64Encode(imageData);

      final requestBody = {
        'image': base64Image,
        'mode': mode.name,
        'languages': ['zh', 'en'],
      };

      AppLogger.info(
        '发起云端 OCR 请求（${imageData.length} 字节）',
        tag: 'CloudOcr',
      );

      final response = await _apiClient.post(
        '/ocr/recognize',
        data: requestBody,
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      AppLogger.error('云端 OCR 请求失败', tag: 'CloudOcr', error: e);
      throw ServerException(
        message: e.message ?? '云端 OCR 服务暂时不可用',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      AppLogger.error('云端 OCR 异常', tag: 'CloudOcr', error: e);
      throw ServerException(message: '云端 OCR 处理失败: $e');
    }
  }

  /// 解析 API 响应
  OcrResult _parseResponse(Response response) {
    final data = response.data as Map<String, dynamic>;

    // 默认结构：
    // {
    //   "results": [
    //     {"text": "人民医院急诊入口", "confidence": 0.98, "language": "zh"}
    //   ]
    // }
    final results = data['results'] as List?;
    if (results == null || results.isEmpty) {
      return OcrResult(
        text: '',
        confidence: 0,
        language: 'unknown',
        source: OcrSource.cloud,
        timestamp: DateTime.now(),
      );
    }

    // 取第一个（置信度最高的）结果
    final first = Map<String, dynamic>.from(results.first as Map);
    return OcrResult(
      text: first['text'] as String? ?? '',
      confidence: (first['confidence'] as num?)?.toDouble() ?? 0,
      language: first['language'] as String? ?? 'zh',
      source: OcrSource.cloud,
      timestamp: DateTime.now(),
    );
  }
}
