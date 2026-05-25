import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/logger.dart';

/// 屏幕 AI 理解数据源
///
/// 调用多模态大模型（GPT-4V / Qwen-VL / 通义千问等）对屏幕截图进行视觉理解。
/// 
/// 主要用于 App 解读模块的「路径 2」：
/// - 输入：屏幕截图 + App 上下文信息
/// - 输出：自然语言的界面描述、图标含义、操作建议
class ScreenAiDataSource {
  final ApiClient _apiClient;

  ScreenAiDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// 分析屏幕截图
  /// 
  /// [screenshot] 屏幕截图二进制数据
  /// [appName] 当前 App 名称（用作上下文）
  /// [platform] 平台（android / ios）
  /// [task] 任务类型：
  ///   - "screen_understanding"：整体理解
  ///   - "element_description"：单个元素解读
  ///   - "interaction_hint"：操作建议
  Future<ScreenAiResult> analyzeScreen(
    Uint8List screenshot, {
    required String appName,
    required String platform,
    String task = 'screen_understanding',
    String locale = 'zh-CN',
  }) async {
    try {
      final base64Image = base64Encode(screenshot);

      final requestBody = {
        'image': base64Image,
        'task': task,
        'context': {
          'app_name': appName,
          'platform': platform,
          'locale': locale,
        },
      };

      AppLogger.info(
        '发起屏幕 AI 分析请求: task=$task, app=$appName',
        tag: 'ScreenAi',
      );

      final response = await _apiClient.post(
        '/vision/analyze',
        data: requestBody,
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      AppLogger.error('屏幕 AI 请求失败', tag: 'ScreenAi', error: e);
      throw ServerException(
        message: e.message ?? 'AI 服务暂时不可用',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      AppLogger.error('屏幕 AI 处理异常', tag: 'ScreenAi', error: e);
      throw ServerException(message: 'AI 分析失败: $e');
    }
  }

  /// 解析 API 响应
  ScreenAiResult _parseResponse(Response response) {
    final data = response.data as Map<String, dynamic>;

    return ScreenAiResult(
      description: data['description'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      elements: (data['elements'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      interactionHints: (data['interaction_hints'] as List?)
              ?.map((h) => h.toString())
              .toList() ??
          const [],
      iconMeanings: (data['icon_meanings'] as Map?)?.cast<String, String>() ??
          const {},
    );
  }
}

/// 屏幕 AI 分析结果
class ScreenAiResult {
  /// 整体页面描述（自然语言）
  final String description;

  /// 置信度 0.0-1.0
  final double confidence;

  /// AI 识别出的元素列表
  final List<Map<String, dynamic>> elements;

  /// 操作建议
  final List<String> interactionHints;

  /// 图标含义映射（图标位置/hash → 含义描述）
  final Map<String, String> iconMeanings;

  const ScreenAiResult({
    required this.description,
    required this.confidence,
    this.elements = const [],
    this.interactionHints = const [],
    this.iconMeanings = const {},
  });
}
