import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/obstacle.dart';
import '../../data/datasources/obstacle_detection_data_source.dart';
import '../../data/repositories/detection_repository_impl.dart';
import '../../../../core/utils/haptic_feedback.dart';
import '../../../voice_interaction/presentation/providers/voice_provider.dart';

/// 障碍物检测状态
class DetectionState {
  final bool isDetecting;
  final List<Obstacle> currentObstacles;
  final Obstacle? nearestObstacle;
  final String? errorMessage;

  const DetectionState({
    this.isDetecting = false,
    this.currentObstacles = const [],
    this.nearestObstacle,
    this.errorMessage,
  });

  DetectionState copyWith({
    bool? isDetecting,
    List<Obstacle>? currentObstacles,
    Object? nearestObstacle = _detSentinel,
    Object? errorMessage = _detSentinel,
  }) {
    return DetectionState(
      isDetecting: isDetecting ?? this.isDetecting,
      currentObstacles: currentObstacles ?? this.currentObstacles,
      nearestObstacle: nearestObstacle == _detSentinel
          ? this.nearestObstacle
          : nearestObstacle as Obstacle?,
      errorMessage: errorMessage == _detSentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _detSentinel = Object();

/// 障碍物检测Notifier
class DetectionNotifier extends StateNotifier<DetectionState> {
  final DetectionRepositoryImpl _repository;
  StreamSubscription? _obstacleSubscription;

  DetectionNotifier({required DetectionRepositoryImpl repository})
      : _repository = repository,
        super(const DetectionState());

  /// 初始化检测服务
  Future<void> initialize() async {
    try {
      await _repository.initialize();

      // 监听障碍物检测结果
      _obstacleSubscription = _repository.obstacleStream.listen(
        (obstacles) {
          final nearest = obstacles.isNotEmpty
              ? obstacles.reduce((a, b) => a.distance < b.distance ? a : b)
              : null;

          state = state.copyWith(
            currentObstacles: obstacles,
            nearestObstacle: nearest,
          );
        },
        onError: (error) {
          state = state.copyWith(errorMessage: '检测出错: $error');
        },
      );
    } catch (e) {
      state = state.copyWith(errorMessage: '检测服务初始化失败');
    }
  }

  /// 开始检测
  Future<void> startDetection({int targetFps = 15}) async {
    try {
      await _repository.startDetection(targetFps: targetFps);
      state = state.copyWith(isDetecting: true);
    } catch (e) {
      state = state.copyWith(errorMessage: '启动检测失败: $e');
    }
  }

  /// 停止检测
  Future<void> stopDetection() async {
    try {
      await _repository.stopDetection();
    } catch (e) {
      // 即使 stop 出错也要更新状态，否则按钮永远卡在"检测中"
    }
    state = DetectionState(
      isDetecting: false,
      currentObstacles: const [],
    );
  }

  /// 切换检测状态
  Future<void> toggleDetection() async {
    if (state.isDetecting) {
      await stopDetection();
    } else {
      await startDetection();
    }
  }

  @override
  void dispose() {
    _obstacleSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}

/// ========== Providers ==========

/// 震动反馈管理器Provider
final hapticManagerProvider = Provider<HapticFeedbackManager>((ref) {
  return HapticFeedbackManager();
});

/// 障碍物检测数据源Provider
final obstacleDataSourceProvider = Provider<ObstacleDetectionDataSource>((ref) {
  final ds = ObstacleDetectionDataSource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

/// 障碍物检测仓库Provider
final detectionRepositoryProvider = Provider<DetectionRepositoryImpl>((ref) {
  final dataSource = ref.watch(obstacleDataSourceProvider);
  final eventBus = ref.watch(eventBusProvider);
  final haptic = ref.watch(hapticManagerProvider);
  return DetectionRepositoryImpl(
    dataSource: dataSource,
    eventBus: eventBus,
    hapticManager: haptic,
  );
});

/// 障碍物检测状态Provider
final detectionNotifierProvider =
    StateNotifierProvider<DetectionNotifier, DetectionState>((ref) {
  final repository = ref.watch(detectionRepositoryProvider);
  return DetectionNotifier(repository: repository);
});
