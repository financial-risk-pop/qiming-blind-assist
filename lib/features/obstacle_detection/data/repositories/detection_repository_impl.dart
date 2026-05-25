import 'dart:async';

import '../../domain/entities/obstacle.dart';
import '../../domain/repositories/detection_repository.dart';
import '../datasources/obstacle_detection_data_source.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/event_bus/event_bus.dart';
import '../../../../core/utils/haptic_feedback.dart';

/// 障碍物检测仓库实现
/// 
/// 连接检测数据源和领域层，额外负责：
/// 1. 障碍物告警的冷却时间管理（防止重复告警）
/// 2. 通过事件总线通知语音模块播报
/// 3. 触发震动反馈
class DetectionRepositoryImpl implements DetectionRepository {
  final ObstacleDetectionDataSource _dataSource;
  final EventBus _eventBus;
  final HapticFeedbackManager _hapticManager;

  // 告警冷却记录：类型+方位 → 上次告警时间
  final Map<String, DateTime> _alertCooldowns = {};
  static const _cooldownDuration = Duration(seconds: 3);

  bool _isDetecting = false;

  DetectionRepositoryImpl({
    required ObstacleDetectionDataSource dataSource,
    required EventBus eventBus,
    required HapticFeedbackManager hapticManager,
  })  : _dataSource = dataSource,
        _eventBus = eventBus,
        _hapticManager = hapticManager {
    // 监听检测结果并处理告警逻辑
    _dataSource.obstacleStream.listen(_processObstacles);
  }

  @override
  Stream<List<Obstacle>> get obstacleStream => _dataSource.obstacleStream;

  @override
  bool get isDetecting => _isDetecting;

  @override
  Future<void> startDetection({int targetFps = 15}) async {
    if (_isDetecting) return;
    _isDetecting = true;
    await _dataSource.startDetection(targetFps: targetFps);
    AppLogger.info('障碍物检测已启动', tag: 'DetectionRepo');
  }

  @override
  Future<void> stopDetection() async {
    if (!_isDetecting) return;
    _isDetecting = false;
    await _dataSource.stopDetection();
    _alertCooldowns.clear();
    AppLogger.info('障碍物检测已停止', tag: 'DetectionRepo');
  }

  @override
  Future<void> updateConfig(DetectionConfig config) async {
    // 更新帧率
    if (_isDetecting) {
      await _dataSource.stopDetection();
      await _dataSource.startDetection(targetFps: config.targetFps);
    }
  }

  /// 处理检测结果，决定是否触发告警
  void _processObstacles(List<Obstacle> obstacles) {
    if (obstacles.isEmpty) return;

    for (final obstacle in obstacles) {
      final alertKey = '${obstacle.type.name}_${obstacle.direction.name}';
      final now = DateTime.now();

      // 检查冷却时间
      if (_alertCooldowns.containsKey(alertKey)) {
        final lastAlert = _alertCooldowns[alertKey]!;
        if (now.difference(lastAlert) < _cooldownDuration) {
          // 紧急障碍物缩短冷却时间
          if (!obstacle.isUrgent) continue;
        }
      }

      _alertCooldowns[alertKey] = now;

      // 触发震动反馈
      _triggerHaptic(obstacle);

      // 通过事件总线通知语音模块
      _triggerVoiceAlert(obstacle);
    }
  }

  /// 触发震动反馈
  void _triggerHaptic(Obstacle obstacle) {
    if (obstacle.isUrgent) {
      _hapticManager.urgentObstacleAlert();
    } else if (obstacle.isNear) {
      _hapticManager.nearObstacleAlert();
    } else {
      _hapticManager.normalObstacleAlert();
    }
  }

  /// 触发语音告警
  void _triggerVoiceAlert(Obstacle obstacle) {
    final priority = obstacle.isUrgent
        ? FeedbackPriority.critical
        : FeedbackPriority.navigation;

    _eventBus.fire(SpeakRequestEvent(
      text: obstacle.toSpeechText(),
      priority: priority,
      interruptCurrent: obstacle.isUrgent,
      sourceModule: 'obstacle_detection',
    ));

    // 同时发送结构化障碍物事件
    _eventBus.fire(ObstacleAlertEvent(
      obstacles: [
        ObstacleInfo(
          type: obstacle.type.name,
          distance: obstacle.distance,
          direction: obstacle.direction.name,
          confidence: obstacle.confidence,
        ),
      ],
      priority: priority,
    ));
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
