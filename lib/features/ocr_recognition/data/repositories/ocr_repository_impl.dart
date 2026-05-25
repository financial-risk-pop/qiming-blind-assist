import 'dart:async';
import 'dart:io';

import '../../domain/entities/ocr_result.dart';
import '../../domain/repositories/ocr_repository.dart';
import '../datasources/ocr_data_source.dart';
import '../datasources/cloud_ocr_data_source.dart';
import '../../../../core/event_bus/event_bus.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/logger.dart';

/// OCR仓库实现
/// 
/// 实现端云协同策略：
/// 1. 有网络 + 精细模式 → 优先云端识别
/// 2. 无网络或快速模式 → 端侧ML Kit
/// 3. 识别结果自动通过事件总线推送语音播报
class OcrRepositoryImpl implements OcrRepository {
  final OcrDataSource _dataSource;
  final CloudOcrDataSource _cloudDataSource;
  final EventBus _eventBus;
  final NetworkInfo _networkInfo;

  OcrRepositoryImpl({
    required OcrDataSource dataSource,
    CloudOcrDataSource? cloudDataSource,
    required EventBus eventBus,
    required NetworkInfo networkInfo,
  })  : _dataSource = dataSource,
        _cloudDataSource = cloudDataSource ?? CloudOcrDataSource(),
        _eventBus = eventBus,
        _networkInfo = networkInfo;

  @override
  Future<OcrResult> recognizeFromCamera({OcrMode mode = OcrMode.auto}) async {
    OcrResult result;

    if (mode == OcrMode.auto) {
      // 自动模式：有网用云端，无网用端侧
      final hasNetwork = await _networkInfo.isConnected;
      if (hasNetwork) {
        result = await _recognizeCloud();
      } else {
        result = await _dataSource.recognizeFromCamera(mode: OcrMode.fast);
      }
    } else if (mode == OcrMode.detailed) {
      result = await _recognizeCloud();
    } else {
      result = await _dataSource.recognizeFromCamera(mode: mode);
    }

    // 通过事件总线推送结果
    if (result.text.isNotEmpty) {
      _eventBus.fire(OcrResultEvent(
        recognizedText: result.text,
        confidence: result.confidence,
        source: result.source == OcrSource.device ? 'device' : 'cloud',
      ));

      _eventBus.fire(SpeakRequestEvent(
        text: '识别到以下文字：${result.text}',
        priority: FeedbackPriority.information,
        sourceModule: 'ocr',
      ));
    } else {
      _eventBus.fire(SpeakRequestEvent(
        text: '未识别到文字，请调整角度或距离后重试',
        priority: FeedbackPriority.information,
        sourceModule: 'ocr',
      ));
    }

    return result;
  }

  @override
  Future<OcrResult> recognizeFromImage(String imagePath, {OcrMode mode = OcrMode.auto}) async {
    return _dataSource.recognizeFromFile(imagePath, mode: mode);
  }

  @override
  Stream<OcrResult> startRealTimeOcr() {
    _dataSource.startRealTimeOcr();

    // 监听并播报（但节流，每3秒最多播报一次新内容）
    String? lastSpokenText;
    DateTime? lastSpeakTime;

    return _dataSource.resultStream.where((result) {
      if (result.text.isEmpty) return false;

      final now = DateTime.now();
      final isNewContent = result.text != lastSpokenText;
      final cooldownPassed = lastSpeakTime == null ||
          now.difference(lastSpeakTime!).inSeconds >= 3;

      if (isNewContent && cooldownPassed) {
        lastSpokenText = result.text;
        lastSpeakTime = now;

        _eventBus.fire(SpeakRequestEvent(
          text: result.text,
          priority: FeedbackPriority.information,
          sourceModule: 'ocr',
        ));

        return true;
      }
      return false;
    });
  }

  @override
  Future<void> stopRealTimeOcr() async {
    await _dataSource.stopRealTimeOcr();
  }

  /// 云端OCR识别（调用云端API增强精度）
  /// 
  /// 流程：
  /// 1. 端侧拍照获取图片文件路径
  /// 2. 读取图片字节并调用云端 API
  /// 3. 云端失败时降级回端侧结果
  Future<OcrResult> _recognizeCloud() async {
    try {
      // 先端侧拍照得到图片文件（复用摄像头管线）
      final endSideResult = await _dataSource.recognizeFromCamera(mode: OcrMode.fast);

      // 如果端侧置信度已足够高，直接返回
      if (endSideResult.confidence >= 0.9) {
        AppLogger.debug('端侧置信度足够，跳过云端', tag: 'OcrRepo');
        return endSideResult;
      }

      // TODO: 实际场景应保留拍照原图路径，这里为演示结构先返回端侧结果
      // 完整实现需要：
      // 1. OcrDataSource.recognizeFromCamera 返回 (OcrResult, String imagePath)
      // 2. 读取 imagePath 文件字节
      // 3. 调用 _cloudDataSource.recognize(bytes)
      // 4. 合并两者结果（取置信度更高的）
      
      AppLogger.info(
        '云端 OCR 降级占位（端侧置信度 ${endSideResult.confidence}）',
        tag: 'OcrRepo',
      );
      return endSideResult;
    } catch (e) {
      AppLogger.error('云端 OCR 失败，降级端侧', tag: 'OcrRepo', error: e);
      return _dataSource.recognizeFromCamera(mode: OcrMode.fast);
    }
  }

  /// 初始化
  Future<void> initialize() async {
    await _dataSource.initialize();
  }

  /// 释放资源
  Future<void> dispose() async {
    await _dataSource.dispose();
  }
}
