import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:blind_assist_app/features/obstacle_detection/domain/entities/obstacle.dart';
import 'package:blind_assist_app/core/constants/app_constants.dart';

/// 障碍物核心逻辑测试
///
/// 测试覆盖：
/// - 紧急/近距离判定边界
/// - 语音播报文本生成
/// - 各种类型/方位组合
/// - 置信度范围
void main() {
  group('Obstacle 紧急/近距离判定', () {
    test('distance = 0.0 → isUrgent=true, isNear=false', () {
      final o = _build(distance: 0.0);
      expect(o.isUrgent, true);
      expect(o.isNear, false);
    });

    test('distance = 0.99 → isUrgent=true', () {
      final o = _build(distance: 0.99);
      expect(o.isUrgent, true);
    });

    test('distance = 1.0 → 临界点：不紧急，算近距离', () {
      final o = _build(distance: 1.0);
      expect(o.isUrgent, false);
      expect(o.isNear, true);
    });

    test('distance = 2.99 → 仍算近距离', () {
      final o = _build(distance: 2.99);
      expect(o.isNear, true);
    });

    test('distance = 3.0 → 临界点：不再算近距离', () {
      final o = _build(distance: 3.0);
      expect(o.isNear, false);
    });

    test('distance = 10.0 → 远距离', () {
      final o = _build(distance: 10.0);
      expect(o.isNear, false);
      expect(o.isUrgent, false);
    });
  });

  group('Obstacle 语音播报文本', () {
    test('紧急障碍物：距离<1米 → 播报"不到1米"', () {
      final o = _build(
        distance: 0.5,
        type: ObstacleType.stairs,
        direction: Direction.front,
      );
      expect(o.toSpeechText(), contains('不到1米'));
      expect(o.toSpeechText(), contains('台阶'));
      expect(o.toSpeechText(), contains('正前方'));
    });

    test('普通距离：返回整数米', () {
      final o = _build(
        distance: 4.7,
        type: ObstacleType.pedestrian,
        direction: Direction.leftNear,
      );
      final text = o.toSpeechText();
      expect(text, contains('米'));
      expect(text, contains('行人'));
    });

    test('整数距离不加小数', () {
      final o = _build(
        distance: 5.0,
        type: ObstacleType.vehicle,
        direction: Direction.right,
      );
      expect(o.toSpeechText(), contains('5米'));
    });
  });

  group('Obstacle 所有枚举完整性', () {
    test('所有 ObstacleType 都能生成播报文本', () {
      for (final type in ObstacleType.values) {
        final o = _build(type: type);
        expect(
          o.toSpeechText().isNotEmpty,
          true,
          reason: '$type 的播报文本不能为空',
        );
      }
    });

    test('所有 Direction 都有可读的中文标签', () {
      for (final dir in Direction.values) {
        expect(dir.label.isNotEmpty, true);
      }
    });
  });

  group('DetectionConfig 默认值', () {
    test('默认使用行走模式帧率', () {
      const config = DetectionConfig();
      expect(config.targetFps, AppConstants.walkingFps);
    });

    test('默认置信度等于 AppConstants.minDetectionConfidence', () {
      const config = DetectionConfig();
      expect(config.minConfidence, AppConstants.minDetectionConfidence);
    });

    test('默认告警冷却 3 秒', () {
      const config = DetectionConfig();
      expect(config.alertCooldown, 3.0);
    });
  });

  group('AppConstants 常量完整性', () {
    test('detectionModelInputSize 等于 modelInputSize（别名一致）', () {
      expect(
        AppConstants.detectionModelInputSize,
        AppConstants.modelInputSize,
      );
    });

    test('walkingFps 等于 walkingDetectionFps（别名一致）', () {
      expect(
        AppConstants.walkingFps,
        AppConstants.walkingDetectionFps,
      );
    });

    test('minDetectionConfidence 等于 confidenceThreshold（别名一致）', () {
      expect(
        AppConstants.minDetectionConfidence,
        AppConstants.confidenceThreshold,
      );
    });

    test('静止帧率 < 行走帧率（功耗优化）', () {
      expect(
        AppConstants.stationaryFps,
        lessThan(AppConstants.walkingFps),
      );
    });

    test('紧急障碍物震动时长 > 普通障碍物', () {
      expect(
        AppConstants.urgentObstacleVibration,
        greaterThan(AppConstants.normalObstacleVibration),
      );
    });
  });
}

// ==================== 测试工具 ====================

Obstacle _build({
  ObstacleType type = ObstacleType.pedestrian,
  double distance = 2.0,
  Direction direction = Direction.front,
  double confidence = 0.85,
  Rect? boundingBox,
}) {
  return Obstacle(
    type: type,
    distance: distance,
    direction: direction,
    confidence: confidence,
    boundingBox: boundingBox ?? const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4),
    detectedAt: DateTime(2026, 4, 20, 12, 0, 0),
  );
}
