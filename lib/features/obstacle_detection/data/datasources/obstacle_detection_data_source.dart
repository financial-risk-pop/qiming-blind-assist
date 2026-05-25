import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/obstacle.dart';

/// 障碍物检测数据源
/// 
/// 核心职责：
/// 1. 摄像头帧捕获（Camera插件）
/// 2. TFLite端侧推理（目标检测模型）
/// 3. 后处理：NMS + 距离估算 + 方位计算
class ObstacleDetectionDataSource {
  CameraController? _cameraController;
  Interpreter? _interpreter;
  
  bool _isDetecting = false;
  int _targetFps = AppConstants.walkingDetectionFps;
  DateTime? _lastProcessTime;

  // 检测结果流
  final _obstacleController = StreamController<List<Obstacle>>.broadcast();
  Stream<List<Obstacle>> get obstacleStream => _obstacleController.stream;

  // 模型参数
  static const String _modelPath = 'assets/models/obstacle_detection.tflite';
  static const String _labelsPath = 'assets/models/obstacle_labels.txt';
  List<String> _labels = [];

  // ==================== 初始化 ====================

  /// 初始化摄像头和模型
  Future<void> initialize() async {
    try {
      // 初始化摄像头
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const DeviceException(message: '未检测到摄像头');
      }

      // 选择后置摄像头
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium, // 中等分辨率平衡性能
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // 初始化TFLite模型
      await _loadModel();

      AppLogger.info('障碍物检测数据源初始化完成', tag: 'ObstacleDS');
    } catch (e) {
      AppLogger.error('障碍物检测初始化失败', tag: 'ObstacleDS', error: e);
      rethrow;
    }
  }

  /// 加载TFLite模型和标签文件
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);

      // 从 assets 加载标签文件
      try {
        final labelsContent = await rootBundle.loadString(_labelsPath);
        _labels = labelsContent
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        AppLogger.info('标签加载完成：${_labels.length} 类', tag: 'ObstacleDS');
      } catch (e) {
        // 标签文件缺失时使用 fallback（常用 COCO 14 类）
        AppLogger.warning('标签文件缺失，使用 fallback 列表', tag: 'ObstacleDS');
        _labels = [
          'person', 'car', 'bicycle', 'motorcycle', 'bus', 'truck',
          'stairs', 'pothole', 'bollard', 'pole', 'tree', 'fire_hydrant',
          'bench', 'curb',
        ];
      }

      AppLogger.info('TFLite模型加载完成', tag: 'ObstacleDS');
    } catch (e) {
      AppLogger.error('模型加载失败', tag: 'ObstacleDS', error: e);
      throw AIModelException(message: '障碍物检测模型加载失败: $e');
    }
  }

  // ==================== 检测控制 ====================

  /// 开始障碍物检测
  Future<void> startDetection({int? targetFps}) async {
    if (_isDetecting) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw const DeviceException(message: '摄像头未初始化');
    }

    _targetFps = targetFps ?? AppConstants.walkingDetectionFps;
    _isDetecting = true;

    // 开始图像流处理
    await _cameraController!.startImageStream(_processFrame);

    AppLogger.info('开始障碍物检测 (${_targetFps}fps)', tag: 'ObstacleDS');
  }

  /// 停止障碍物检测
  Future<void> stopDetection() async {
    if (!_isDetecting) return;
    _isDetecting = false;

    try {
      await _cameraController?.stopImageStream();
    } catch (e) {
      AppLogger.warning('停止图像流异常: $e', tag: 'ObstacleDS');
    }

    AppLogger.info('障碍物检测已停止', tag: 'ObstacleDS');
  }

  bool get isDetecting => _isDetecting;

  // ==================== 图像处理 ====================

  /// 处理单帧图像
  void _processFrame(CameraImage image) {
    if (!_isDetecting || _interpreter == null) return;

    // 帧率控制
    final now = DateTime.now();
    if (_lastProcessTime != null) {
      final elapsed = now.difference(_lastProcessTime!).inMilliseconds;
      final interval = 1000 ~/ _targetFps;
      if (elapsed < interval) return;
    }
    _lastProcessTime = now;

    // 异步处理，避免阻塞摄像头帧流
    _runInference(image);
  }

  /// 执行模型推理
  Future<void> _runInference(CameraImage image) async {
    try {
      // 1. 图像预处理：YUV420 → RGB → 归一化
      final inputData = _preprocessImage(image);

      // 2. 准备输出缓冲
      // 假设模型输出：[1, numDetections, 6]（x,y,w,h,confidence,classId）
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputBuffer = List.generate(
        outputShape[0],
        (_) => List.generate(
          outputShape[1],
          (_) => List<double>.filled(outputShape[2], 0),
        ),
      );

      // 3. 运行推理
      _interpreter!.run(inputData, outputBuffer);

      // 4. 后处理：解码检测结果
      final obstacles = _postProcess(outputBuffer[0], image.width, image.height);

      // 5. 输出结果
      if (obstacles.isNotEmpty || true) {
        // 始终发送结果（空列表表示安全）
        _obstacleController.add(obstacles);
      }
    } catch (e) {
      AppLogger.error('推理出错', tag: 'ObstacleDS', error: e);
    }
  }

  /// 图像预处理
  Float32List _preprocessImage(CameraImage image) {
    final inputSize = AppConstants.modelInputSize;
    final pixelCount = inputSize * inputSize * 3;
    final input = Float32List(pixelCount);

    // YUV420 → RGB转换和resize
    // 实际实现需要根据平台做适配
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes.length > 1 ? image.planes[1].bytes : null;
    final vPlane = image.planes.length > 2 ? image.planes[2].bytes : null;

    final scaleX = image.width / inputSize;
    final scaleY = image.height / inputSize;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final srcX = (x * scaleX).round().clamp(0, image.width - 1);
        final srcY = (y * scaleY).round().clamp(0, image.height - 1);

        final yValue = yPlane[srcY * image.planes[0].bytesPerRow + srcX];

        // 简化的YUV→RGB转换
        int r, g, b;
        if (uPlane != null && vPlane != null) {
          final uvRow = srcY ~/ 2;
          final uvCol = srcX ~/ 2;
          final uValue = uPlane[uvRow * image.planes[1].bytesPerRow + uvCol] - 128;
          final vValue = vPlane[uvRow * image.planes[2].bytesPerRow + uvCol] - 128;

          r = (yValue + 1.402 * vValue).round().clamp(0, 255);
          g = (yValue - 0.344136 * uValue - 0.714136 * vValue).round().clamp(0, 255);
          b = (yValue + 1.772 * uValue).round().clamp(0, 255);
        } else {
          r = g = b = yValue;
        }

        // 归一化到 [0, 1]
        final idx = (y * inputSize + x) * 3;
        input[idx] = r / 255.0;
        input[idx + 1] = g / 255.0;
        input[idx + 2] = b / 255.0;
      }
    }

    return input;
  }

  /// 后处理：解码检测结果
  List<Obstacle> _postProcess(
    List<List<double>> detections,
    int imageWidth,
    int imageHeight,
  ) {
    final obstacles = <Obstacle>[];
    final confidenceThreshold = AppConstants.confidenceThreshold;

    for (final detection in detections) {
      if (detection.length < 6) continue;

      final confidence = detection[4];
      if (confidence < confidenceThreshold) continue;

      final classId = detection[5].round();
      if (classId < 0 || classId >= _labels.length) continue;

      // 边界框（归一化坐标）
      final x = detection[0];
      final y = detection[1];
      final w = detection[2];
      final h = detection[3];

      // 估算距离（基于目标在画面中的大小）
      final distance = _estimateDistance(h, _labels[classId]);

      // 估算方位（基于目标在画面中的水平位置）
      final direction = _estimateDirection(x);

      // 映射类型
      final type = _mapLabelToObstacleType(_labels[classId]);

      obstacles.add(Obstacle(
        type: type,
        distance: distance,
        direction: direction,
        confidence: confidence,
        boundingBox: ui.Rect.fromLTWH(x - w / 2, y - h / 2, w, h),
        detectedAt: DateTime.now(),
      ));
    }

    // NMS去重
    return _nonMaxSuppression(obstacles);
  }

  /// 基于目标大小估算距离（简化的单目测距）
  double _estimateDistance(double normalizedHeight, String label) {
    // 不同物体的参考高度（米）
    final refHeights = {
      'person': 1.7,
      'car': 1.5,
      'bicycle': 1.0,
      'motorcycle': 1.1,
      'bus': 3.0,
      'truck': 2.5,
      'stairs': 0.3,
      'pothole': 0.1,
      'bollard': 0.8,
      'pole': 3.0,
      'tree': 3.0,
      'fire_hydrant': 0.6,
      'bench': 0.8,
      'curb': 0.15,
    };

    final refHeight = refHeights[label] ?? 1.0;
    // 简化距离估算：距离 ∝ 参考高度 / 画面占比
    // 假设摄像头焦距参数
    if (normalizedHeight <= 0) return 10.0;
    final distance = (refHeight * 1.5) / normalizedHeight;
    return distance.clamp(0.1, 20.0);
  }

  /// 基于水平位置估算方位
  Direction _estimateDirection(double normalizedX) {
    if (normalizedX < 0.2) return Direction.farLeft;
    if (normalizedX < 0.35) return Direction.left;
    if (normalizedX < 0.45) return Direction.frontLeft;
    if (normalizedX < 0.55) return Direction.front;
    if (normalizedX < 0.65) return Direction.frontRight;
    if (normalizedX < 0.8) return Direction.right;
    return Direction.farRight;
  }

  /// 标签映射到障碍物类型
  /// 
  /// 覆盖 COCO 数据集常见类别，未识别的类别归为 other
  ObstacleType _mapLabelToObstacleType(String label) {
    final l = label.toLowerCase().trim();
    return switch (l) {
      // 行人
      'person' => ObstacleType.pedestrian,
      // 机动车
      'car' || 'bus' || 'truck' || 'train' => ObstacleType.vehicle,
      // 非机动车（归类为 vehicle，因为同样会移动，对盲人都是威胁）
      'bicycle' || 'motorcycle' => ObstacleType.vehicle,
      // 动物
      'bird' || 'cat' || 'dog' || 'horse' ||
      'sheep' || 'cow' || 'bear' => ObstacleType.animal,
      // 台阶类
      'stairs' => ObstacleType.stairs,
      // 坑洞
      'pothole' => ObstacleType.pothole,
      // 路障类（所有立柱状障碍物）
      'bollard' || 'traffic light' || 'stop sign' || 'parking meter' =>
        ObstacleType.barrier,
      // 杆子
      'pole' || 'fire hydrant' || 'fire_hydrant' => ObstacleType.pole,
      // 路沿
      'curb' => ObstacleType.curb,
      // 其他物体
      _ => ObstacleType.other,
    };
  }

  /// 非极大值抑制（NMS）
  List<Obstacle> _nonMaxSuppression(List<Obstacle> obstacles) {
    if (obstacles.length <= 1) return obstacles;

    // 按置信度排序
    obstacles.sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <Obstacle>[];
    final suppressed = <int>{};

    for (int i = 0; i < obstacles.length; i++) {
      if (suppressed.contains(i)) continue;
      kept.add(obstacles[i]);

      for (int j = i + 1; j < obstacles.length; j++) {
        if (suppressed.contains(j)) continue;
        final iou = _calculateIoU(obstacles[i].boundingBox, obstacles[j].boundingBox);
        if (iou > 0.5) {
          suppressed.add(j);
        }
      }
    }

    return kept;
  }

  /// 计算IoU
  double _calculateIoU(ui.Rect boxA, ui.Rect boxB) {
    final interLeft = boxA.left > boxB.left ? boxA.left : boxB.left;
    final interTop = boxA.top > boxB.top ? boxA.top : boxB.top;
    final interRight = boxA.right < boxB.right ? boxA.right : boxB.right;
    final interBottom = boxA.bottom < boxB.bottom ? boxA.bottom : boxB.bottom;

    if (interLeft >= interRight || interTop >= interBottom) return 0;

    final interArea = (interRight - interLeft) * (interBottom - interTop);
    final areaA = boxA.width * boxA.height;
    final areaB = boxB.width * boxB.height;
    final unionArea = areaA + areaB - interArea;

    return unionArea > 0 ? interArea / unionArea : 0;
  }

  // ==================== 资源释放 ====================

  Future<void> dispose() async {
    await stopDetection();
    _interpreter?.close();
    await _cameraController?.dispose();
    await _obstacleController.close();
  }
}
