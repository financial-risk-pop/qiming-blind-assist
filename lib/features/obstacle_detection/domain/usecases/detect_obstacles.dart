import '../entities/obstacle.dart';
import '../repositories/detection_repository.dart';

/// 障碍物检测用例
class DetectObstaclesUseCase {
  final DetectionRepository _repository;

  DetectObstaclesUseCase(this._repository);

  /// 获取障碍物检测结果流
  Stream<List<Obstacle>> call() {
    return _repository.obstacleStream;
  }

  /// 开始检测
  Future<void> start({int targetFps = 15}) {
    return _repository.startDetection(targetFps: targetFps);
  }

  /// 停止检测
  Future<void> stop() {
    return _repository.stopDetection();
  }
}
