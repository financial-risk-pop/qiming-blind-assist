import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/route_info.dart';
import '../../domain/repositories/navigation_repository.dart';
import 'amap_rest_client.dart';

/// 导航数据源
/// 
/// 封装底层定位服务和高德地图API的调用：
/// 1. GPS实时定位（Geolocator）
/// 2. 路线规划（AmapRestClient，高德 Web 服务 API）
/// 3. POI搜索（AmapRestClient）
/// 4. 实时导航指令生成
class NavigationDataSource {
  final AmapRestClient? _amapClient;

  StreamSubscription<Position>? _positionSubscription;
  RouteInfo? _currentRoute;
  int _currentStepIndex = 0;

  // 实时位置流
  final _positionController = StreamController<LocationInfo>.broadcast();
  Stream<LocationInfo> get positionStream => _positionController.stream;

  // 导航指令流
  final _navigationController = StreamController<RouteStep>.broadcast();
  Stream<RouteStep> get navigationStream => _navigationController.stream;

  NavigationDataSource({AmapRestClient? amapClient}) : _amapClient = amapClient;

  // ==================== 定位服务 ====================

  /// 获取当前位置
  Future<LocationInfo> getCurrentLocation() async {
    try {
      // 检查定位服务
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const DeviceException(message: '定位服务未开启，请在系统设置中开启GPS');
      }

      // 检查权限
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw const DeviceException(message: '定位权限被拒绝');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw const DeviceException(message: '定位权限被永久拒绝，请前往设置开启');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const DeviceException(
          message: '获取位置超时，请到开阔地带重试',
        ),
      );

      return LocationInfo(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        heading: position.heading,
        speed: position.speed,
        timestamp: position.timestamp,
      );
    } catch (e) {
      if (e is DeviceException) rethrow;
      throw DeviceException(message: '获取位置失败: $e');
    }
  }

  /// 开始位置持续监听
  void startLocationUpdates() {
    _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen(
      (position) {
        final location = LocationInfo(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          heading: position.heading,
          speed: position.speed,
          timestamp: position.timestamp,
        );
        _positionController.add(location);

        // 如果正在导航，检查路段进度
        if (_currentRoute != null) {
          _checkNavigationProgress(location);
        }
      },
      onError: (error) {
        AppLogger.error('位置监听错误', tag: 'NavDS', error: error);
      },
    );
  }

  /// 停止位置监听
  void stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  // ==================== 路线规划 ====================

  /// 规划步行路线
  /// 
  /// 优先调用高德 REST API（若 [AmapRestClient] 已注入），
  /// 失败或未配置时降级到模拟数据以便开发/演示。
  Future<RouteInfo> planRoute({
    required String destination,
    LocationInfo? origin,
  }) async {
    try {
      final start = origin ?? await getCurrentLocation();

      AppLogger.info(
        '规划路线: (${start.latitude},${start.longitude}) → $destination',
        tag: 'NavDS',
      );

      // 1. 尝试调用高德 REST API
      if (_amapClient != null) {
        try {
          // 先对目的地做地理编码（假设用户说的是地名）
          final destCoords = await _amapClient.geocode(destination);
          if (destCoords != null) {
            final route = await _amapClient.planWalkingRoute(
              originLat: start.latitude,
              originLng: start.longitude,
              destLat: destCoords.$1,
              destLng: destCoords.$2,
              destinationName: destination,
            );
            AppLogger.info('高德 API 返回路线：${route.steps.length} 步', tag: 'NavDS');
            return route;
          } else {
            AppLogger.warning(
              '目的地"$destination"无法解析，降级到模拟数据',
              tag: 'NavDS',
            );
          }
        } catch (e) {
          AppLogger.warning('高德 API 调用失败，降级：$e', tag: 'NavDS');
        }
      }

      // 2. 降级：返回模拟路线（开发/离线场景）
      return _mockRoute(destination, start);
    } catch (e) {
      if (e is DeviceException) rethrow;
      throw ServerException(message: '路线规划失败: $e');
    }
  }

  /// 生成模拟路线（用于无 API Key 或网络失败场景）
  RouteInfo _mockRoute(String destination, LocationInfo start) {
    return RouteInfo(
      destination: destination,
      totalDistance: 850.0,
      estimatedMinutes: 12,
      steps: [
        RouteStep(
          instruction: '向北直行100米',
          distance: 100,
          turnDirection: '北',
          latitude: start.latitude,
          longitude: start.longitude,
        ),
        RouteStep(
          instruction: '右转进入人民路，直行500米',
          distance: 500,
          turnDirection: '东',
          landmark: '路口有一个红绿灯',
          latitude: start.latitude + 0.0009,
          longitude: start.longitude,
        ),
        RouteStep(
          instruction: '左转，直行250米到达目的地',
          distance: 250,
          turnDirection: '北',
          landmark: '目的地在道路右侧',
          latitude: start.latitude + 0.0009,
          longitude: start.longitude + 0.0045,
        ),
      ],
      specialSegments: const [],
    );
  }

  // ==================== 实时导航 ====================

  /// 开始导航
  void startNavigation(RouteInfo route) {
    _currentRoute = route;
    _currentStepIndex = 0;
    startLocationUpdates();

    // 播报第一条导航指令
    if (route.steps.isNotEmpty) {
      _navigationController.add(route.steps[0]);
    }

    AppLogger.info('导航开始: ${route.destination}', tag: 'NavDS');
  }

  /// 停止导航
  void stopNavigation() {
    _currentRoute = null;
    _currentStepIndex = 0;
    stopLocationUpdates();
    AppLogger.info('导航已停止', tag: 'NavDS');
  }

  /// 检查导航进度
  void _checkNavigationProgress(LocationInfo currentLocation) {
    final route = _currentRoute;
    if (route == null) return;
    if (_currentStepIndex >= route.steps.length) return;

    final currentStep = route.steps[_currentStepIndex];

    // 简化判断：检查是否需要切换到下一步
    // 实际应基于位置和路段坐标的几何计算
    final distToStep = _calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      currentStep.latitude,
      currentStep.longitude,
    );

    // 接近当前路段终点（20米内），切换下一步
    if (distToStep < 20) {
      _currentStepIndex++;
      if (_currentStepIndex < route.steps.length) {
        _navigationController.add(route.steps[_currentStepIndex]);
      }
    }
  }

  // ==================== POI搜索 ====================

  /// 搜索附近POI
  Future<List<POIResult>> searchPOI(
    String keyword, {
    double radius = 1000,
    LocationInfo? center,
  }) async {
    try {
      final location = center ?? await getCurrentLocation();

      AppLogger.info('搜索POI: $keyword (半径${radius}m)', tag: 'NavDS');

      // 1. 优先使用高德 REST API
      if (_amapClient != null) {
        try {
          final results = await _amapClient.searchAround(
            lat: location.latitude,
            lng: location.longitude,
            keyword: keyword,
            radius: radius,
          );
          if (results.isNotEmpty) {
            return results;
          }
        } catch (e) {
          AppLogger.warning('高德 POI 搜索失败，降级：$e', tag: 'NavDS');
        }
      }

      // 2. 降级：返回单个模拟结果
      return [
        POIResult(
          name: '$keyword（示例）',
          address: '示例地址',
          distance: 200.0,
          latitude: location.latitude + 0.002,
          longitude: location.longitude + 0.001,
          category: '生活服务',
        ),
      ];
    } catch (e) {
      if (e is DeviceException) rethrow;
      throw ServerException(message: 'POI搜索失败: $e');
    }
  }

  // ==================== 偏航检测 ====================

  /// 检测偏航距离
  Future<double?> checkDeviation(RouteInfo route) async {
    try {
      final currentLocation = await getCurrentLocation();

      // 简化实现：计算当前位置到最近路段的垂直距离
      // 实际应使用路线的完整坐标序列
      if (_currentStepIndex < route.steps.length) {
        final step = route.steps[_currentStepIndex];
        final distance = _calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          step.latitude,
          step.longitude,
        );
        // 超过偏航阈值返回偏航距离
        if (distance > 30) {
          return distance;
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('偏航检测失败', tag: 'NavDS', error: e);
      return null;
    }
  }

  // ==================== 工具方法 ====================

  /// 计算两点间距离（Haversine公式，返回米）
  double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const earthRadius = 6371000.0; // 地球半径（米）
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  // ==================== 资源释放 ====================

  Future<void> dispose() async {
    stopNavigation();
    await _positionController.close();
    await _navigationController.close();
  }
}
