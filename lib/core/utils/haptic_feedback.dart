import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../constants/app_constants.dart';

/// 震动反馈管理器
/// 
/// 根据不同事件类型提供差异化的触觉反馈：
/// - 障碍物告警：距离越近，震感越强
/// - 导航提示：节奏性短震
/// - 操作确认：轻微短震
class HapticFeedbackManager {
  bool _isEnabled = true;
  double _intensity = 1.0;

  /// 更新震动设置
  void updateConfig({bool? enabled, double? intensity}) {
    if (enabled != null) _isEnabled = enabled;
    if (intensity != null) _intensity = intensity.clamp(0.0, 2.0);
  }

  /// 普通障碍物告警（距离 > 3m）
  Future<void> normalObstacleAlert() async {
    if (!_isEnabled) return;
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(
        duration: (AppConstants.normalObstacleVibration * _intensity).round(),
      );
    }
  }

  /// 近距离障碍物告警（1-3m）
  Future<void> nearObstacleAlert() async {
    if (!_isEnabled) return;
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(
        pattern: AppConstants.nearObstacleVibrationPattern,
      );
    }
  }

  /// 紧急障碍物告警（< 1m）
  Future<void> urgentObstacleAlert() async {
    if (!_isEnabled) return;
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(
        duration: (AppConstants.urgentObstacleVibration * _intensity).round(),
      );
    }
  }

  /// 导航转弯提示
  Future<void> navigationTurnHint() async {
    if (!_isEnabled) return;
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(
        pattern: AppConstants.turnVibrationPattern,
      );
    }
  }

  /// 操作确认轻震
  Future<void> confirmFeedback() async {
    if (!_isEnabled) return;
    HapticFeedback.lightImpact();
  }
}
