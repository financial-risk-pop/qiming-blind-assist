import '../entities/obstacle.dart';

/// 障碍物检测仓库接口
abstract class DetectionRepository {
  /// 障碍物检测结果流
  Stream<List<Obstacle>> get obstacleStream;

  /// 开始障碍物检测
  Future<void> startDetection({int targetFps = 15});

  /// 停止检测
  Future<void> stopDetection();

  /// 更新检测配置
  Future<void> updateConfig(DetectionConfig config);

  /// 获取当前检测状态
  bool get isDetecting;
}
