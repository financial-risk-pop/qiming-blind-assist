import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show WriteBuffer;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/ocr_result.dart';

/// OCR识别数据源
/// 
/// 支持两种识别模式：
/// 1. 端侧模式（ML Kit）：离线可用，速度快，适合简单文本
/// 2. 云端模式（API）：需网络，精度高，适合复杂文档
class OcrDataSource {
  CameraController? _cameraController;
  TextRecognizer? _textRecognizer;
  TextRecognizer? _chineseRecognizer;
  
  bool _isRealTimeActive = false;
  Timer? _realTimeTimer;

  // OCR结果流
  final _resultController = StreamController<OcrResult>.broadcast();
  Stream<OcrResult> get resultStream => _resultController.stream;

  // ==================== 初始化 ====================

  Future<void> initialize() async {
    try {
      // 初始化ML Kit文字识别
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _chineseRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

      // 初始化摄像头
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const DeviceException(message: '未检测到摄像头');
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high, // OCR需要高分辨率
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      AppLogger.info('OCR数据源初始化完成', tag: 'OcrDS');
    } catch (e) {
      AppLogger.error('OCR初始化失败', tag: 'OcrDS', error: e);
      rethrow;
    }
  }

  CameraController? get cameraController => _cameraController;

  // ==================== 端侧OCR识别 ====================

  /// 从摄像头拍照并识别
  Future<OcrResult> recognizeFromCamera({OcrMode mode = OcrMode.auto}) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw const DeviceException(message: '摄像头未初始化');
    }

    try {
      // 拍照
      final image = await _cameraController!.takePicture();
      return await recognizeFromFile(image.path, mode: mode);
    } catch (e) {
      throw DeviceException(message: '拍照识别失败: $e');
    }
  }

  /// 从图片文件识别
  Future<OcrResult> recognizeFromFile(
    String filePath, {
    OcrMode mode = OcrMode.auto,
  }) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);

      // 先尝试中文识别
      final chineseResult = await _chineseRecognizer?.processImage(inputImage);
      
      String recognizedText = '';
      double confidence = 0;

      if (chineseResult != null && chineseResult.text.isNotEmpty) {
        recognizedText = chineseResult.text;
        // 估算置信度（基于识别到的文本块数量和字符数）
        confidence = _estimateConfidence(chineseResult);
      } else {
        // 降级到拉丁文识别
        final latinResult = await _textRecognizer?.processImage(inputImage);
        if (latinResult != null && latinResult.text.isNotEmpty) {
          recognizedText = latinResult.text;
          confidence = _estimateConfidence(latinResult);
        }
      }

      if (recognizedText.isEmpty) {
        return OcrResult(
          text: '',
          confidence: 0,
          language: 'unknown',
          source: OcrSource.device,
        );
      }

      // 检测语言
      final language = _detectLanguage(recognizedText);

      return OcrResult(
        text: recognizedText,
        confidence: confidence,
        language: language,
        source: OcrSource.device,
      );
    } catch (e) {
      throw AIModelException(message: 'OCR识别失败: $e');
    }
  }

  /// 从CameraImage直接识别（用于实时模式）
  Future<OcrResult?> recognizeFromCameraImage(CameraImage image) async {
    try {
      // 将CameraImage转换为InputImage
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) return null;

      final result = await _chineseRecognizer?.processImage(inputImage);
      if (result == null || result.text.isEmpty) return null;

      return OcrResult(
        text: result.text,
        confidence: _estimateConfidence(result),
        language: _detectLanguage(result.text),
        source: OcrSource.device,
      );
    } catch (e) {
      AppLogger.error('实时OCR识别出错', tag: 'OcrDS', error: e);
      return null;
    }
  }

  // ==================== 实时OCR ====================

  /// 开始实时OCR识别流
  Future<void> startRealTimeOcr() async {
    if (_isRealTimeActive) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw const DeviceException(message: '摄像头未初始化');
    }

    _isRealTimeActive = true;

    await _cameraController!.startImageStream((CameraImage image) async {
      if (!_isRealTimeActive) return;

      // 控制识别频率（每秒最多2次）
      _realTimeTimer?.cancel();
      _realTimeTimer = Timer(const Duration(milliseconds: 500), () async {
        final result = await recognizeFromCameraImage(image);
        if (result != null && result.text.isNotEmpty) {
          _resultController.add(result);
        }
      });
    });

    AppLogger.info('实时OCR已启动', tag: 'OcrDS');
  }

  /// 停止实时OCR
  Future<void> stopRealTimeOcr() async {
    _isRealTimeActive = false;
    _realTimeTimer?.cancel();
    try {
      await _cameraController?.stopImageStream();
    } catch (e) {
      AppLogger.warning('停止图像流异常: $e', tag: 'OcrDS');
    }
    AppLogger.info('实时OCR已停止', tag: 'OcrDS');
  }

  // ==================== 工具方法 ====================

  /// 估算置信度
  double _estimateConfidence(RecognizedText result) {
    if (result.blocks.isEmpty) return 0;
    // 基于识别到的块数和总字符数评估
    final totalChars = result.text.length;
    if (totalChars < 3) return 0.3;
    if (totalChars < 10) return 0.6;
    return 0.85;
  }

  /// 简单语言检测
  String _detectLanguage(String text) {
    final chineseRegex = RegExp(r'[\u4e00-\u9fff]');
    final chineseCount = chineseRegex.allMatches(text).length;
    final totalChars = text.replaceAll(RegExp(r'\s'), '').length;

    if (totalChars == 0) return 'unknown';
    if (chineseCount / totalChars > 0.3) return 'zh';
    return 'en';
  }

  /// CameraImage转InputImage
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      final bytes = _concatenatePlanes(image.planes);
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
      
      if (inputImageFormat == null) return null;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// 拼接图像平面数据
  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // ==================== 资源释放 ====================

  Future<void> dispose() async {
    await stopRealTimeOcr();
    await _textRecognizer?.close();
    await _chineseRecognizer?.close();
    await _cameraController?.dispose();
    await _resultController.close();
  }
}
