import '../entities/route_info.dart';

/// 导航仓库接口（Domain层定义，Data层实现）
abstract class NavigationRepository {
  /// 规划步行路线
  /// [destination] 目的地（地址或POI名称）
  Future<RouteInfo> planRoute({required String destination});

  /// 开始实时导航，返回导航指令流
  Stream<RouteStep> startNavigation(RouteInfo route);

  /// 停止导航
  Future<void> stopNavigation();

  /// 搜索POI兴趣点
  /// [keyword] 关键词
  /// [radius] 搜索半径（米）
  Future<List<POIResult>> searchPOI(String keyword, {double radius = 1000});

  /// 获取当前位置
  Future<LocationInfo> getCurrentLocation();

  /// 检测偏航
  /// 返回偏航距离（米），null表示未偏航
  Future<double?> checkDeviation(RouteInfo route);
}

/// POI搜索结果
class POIResult {
  final String name;
  final String address;
  final double distance;
  final double latitude;
  final double longitude;
  final String? category;

  const POIResult({
    required this.name,
    required this.address,
    required this.distance,
    required this.latitude,
    required this.longitude,
    this.category,
  });
}

/// 位置信息
class LocationInfo {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  const LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.heading,
    this.speed,
    required this.timestamp,
  });
}
