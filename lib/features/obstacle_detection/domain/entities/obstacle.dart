import 'dart:ui';
import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

/// 障碍物实体
class Obstacle extends Equatable {
  /// 障碍物类型
  final ObstacleType type;

  /// 估算距离（米）
  final double distance;

  /// 相对方位
  final Direction direction;

  /// 检测置信度 0.0-1.0
  final double confidence;

  /// 在画面中的边界框
  final Rect boundingBox;

  /// 检测时间戳
  final DateTime detectedAt;

  const Obstacle({
    required this.type,
    required this.distance,
    required this.direction,
    required this.confidence,
    required this.boundingBox,
    required this.detectedAt,
  });

  /// 是否为紧急障碍物（距离<1米）
  bool get isUrgent => distance < 1.0;

  /// 是否为近距离障碍物（1-3米）
  bool get isNear => distance >= 1.0 && distance < 3.0;

  /// 生成语音播报文本
  String toSpeechText() {
    final distanceText = distance < 1
        ? '不到1米'
        : '${distance.toStringAsFixed(0)}米';
    return '${direction.label}${distanceText}有${type.label}';
  }

  @override
  List<Object?> get props => [type, distance, direction, detectedAt];
}

/// 检测配置
class DetectionConfig {
  /// 目标帧率
  final int targetFps;

  /// 最小置信度阈值
  final double minConfidence;

  /// 告警冷却时间（秒）
  final double alertCooldown;

  const DetectionConfig({
    this.targetFps = AppConstants.walkingFps,
    this.minConfidence = AppConstants.minDetectionConfidence,
    this.alertCooldown = 3.0,
  });
}
