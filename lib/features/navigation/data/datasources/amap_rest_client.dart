import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/route_info.dart';
import '../../domain/repositories/navigation_repository.dart';

/// 高德地图 REST API 客户端
///
/// 使用纯 HTTP 调用高德 Web 服务 API，替代 Flutter 插件方案。
/// 
/// 主要接口：
/// - 步行路径规划：https://restapi.amap.com/v3/direction/walking
/// - 周边 POI 搜索：https://restapi.amap.com/v3/place/around
/// - 地理编码：https://restapi.amap.com/v3/geocode/geo
/// - 逆地理编码：https://restapi.amap.com/v3/geocode/regeo
///
/// 使用前需在 AndroidManifest.xml / Info.plist 中配置 API Key。
class AmapRestClient {
  static const String _baseUrl = 'https://restapi.amap.com/v3';
  static const Duration _timeout = Duration(seconds: 8);

  final Dio _dio;
  final String _apiKey;

  AmapRestClient({required String apiKey, Dio? dio})
      : _apiKey = apiKey,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: _timeout,
              receiveTimeout: _timeout,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ));

  // ==================== 步行路径规划 ====================

  /// 步行路径规划
  ///
  /// [originLat], [originLng] 起点经纬度
  /// [destLat], [destLng] 终点经纬度
  Future<RouteInfo> planWalkingRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? destinationName,
  }) async {
    try {
      final response = await _dio.get(
        '/direction/walking',
        queryParameters: {
          'key': _apiKey,
          'origin': '$originLng,$originLat',
          'destination': '$destLng,$destLat',
          'output': 'json',
        },
      );

      return _parseWalkingRoute(
        response.data as Map<String, dynamic>,
        destinationName ?? '目的地',
        originLat,
        originLng,
      );
    } on DioException catch (e) {
      AppLogger.error('高德路径规划失败', tag: 'AmapRest', error: e);
      throw ServerException(
        message: '路线规划失败：${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// 解析高德 walking 接口响应
  ///
  /// 响应结构参考：
  /// {
  ///   "status": "1",
  ///   "route": {
  ///     "paths": [{
  ///       "distance": "850",
  ///       "duration": "720",
  ///       "steps": [
  ///         {"instruction": "向北直行100米", "distance": "100", "polyline": "116.39,39.91;116.39,39.92"}
  ///       ]
  ///     }]
  ///   }
  /// }
  RouteInfo _parseWalkingRoute(
    Map<String, dynamic> data,
    String destinationName,
    double originLat,
    double originLng,
  ) {
    final status = data['status']?.toString() ?? '0';
    if (status != '1') {
      final info = data['info']?.toString() ?? '未知错误';
      throw ServerException(message: '高德返回错误：$info');
    }

    final route = data['route'] as Map<String, dynamic>?;
    final paths = route?['paths'] as List?;
    if (paths == null || paths.isEmpty) {
      throw const ServerException(message: '未找到可行路线');
    }

    final firstPath = paths.first as Map<String, dynamic>;
    final totalDistance =
        double.tryParse(firstPath['distance']?.toString() ?? '0') ?? 0;
    final duration =
        double.tryParse(firstPath['duration']?.toString() ?? '0') ?? 0;
    final estimatedMinutes = (duration / 60).ceil();

    final stepsData = firstPath['steps'] as List? ?? [];
    final steps = stepsData.map((step) {
      final m = Map<String, dynamic>.from(step as Map);
      final instruction = (m['instruction'] as String? ?? '').trim();
      final stepDistance =
          double.tryParse(m['distance']?.toString() ?? '0') ?? 0;
      final polyline = m['polyline']?.toString() ?? '';
      final firstCoord = _firstPointOf(polyline, originLng, originLat);

      return RouteStep(
        instruction: instruction,
        distance: stepDistance,
        latitude: firstCoord.$2,
        longitude: firstCoord.$1,
      );
    }).toList();

    return RouteInfo(
      destination: destinationName,
      totalDistance: totalDistance,
      estimatedMinutes: estimatedMinutes,
      steps: steps,
      specialSegments: const [],
    );
  }

  /// 解析 polyline 字符串，返回第一个点 (lng, lat)
  /// 格式："116.39,39.91;116.40,39.92"
  (double, double) _firstPointOf(
    String polyline,
    double fallbackLng,
    double fallbackLat,
  ) {
    if (polyline.isEmpty) return (fallbackLng, fallbackLat);
    final first = polyline.split(';').first;
    final parts = first.split(',');
    if (parts.length < 2) return (fallbackLng, fallbackLat);
    final lng = double.tryParse(parts[0]) ?? fallbackLng;
    final lat = double.tryParse(parts[1]) ?? fallbackLat;
    return (lng, lat);
  }

  // ==================== POI 搜索 ====================

  /// 周边 POI 搜索
  Future<List<POIResult>> searchAround({
    required double lat,
    required double lng,
    required String keyword,
    double radius = 1000,
  }) async {
    try {
      final response = await _dio.get(
        '/place/around',
        queryParameters: {
          'key': _apiKey,
          'location': '$lng,$lat',
          'keywords': keyword,
          'radius': radius.round().toString(),
          'output': 'json',
          'extensions': 'base',
        },
      );

      return _parsePoiResults(
        response.data as Map<String, dynamic>,
        lat,
        lng,
      );
    } on DioException catch (e) {
      AppLogger.error('高德 POI 搜索失败', tag: 'AmapRest', error: e);
      throw ServerException(message: 'POI 搜索失败：${e.message}');
    }
  }

  List<POIResult> _parsePoiResults(
    Map<String, dynamic> data,
    double centerLat,
    double centerLng,
  ) {
    final status = data['status']?.toString() ?? '0';
    if (status != '1') return [];

    final pois = data['pois'] as List? ?? [];
    return pois.map((poi) {
      final m = Map<String, dynamic>.from(poi as Map);
      final location = m['location']?.toString() ?? '$centerLng,$centerLat';
      final coords = location.split(',');
      final poiLng = double.tryParse(coords.first) ?? centerLng;
      final poiLat =
          double.tryParse(coords.length > 1 ? coords[1] : '') ?? centerLat;
      final distance =
          double.tryParse(m['distance']?.toString() ?? '0') ?? 0;

      return POIResult(
        name: m['name']?.toString() ?? '',
        address: m['address']?.toString() ?? '',
        distance: distance,
        latitude: poiLat,
        longitude: poiLng,
        category: m['type']?.toString(),
      );
    }).toList();
  }

  // ==================== 地理编码 ====================

  /// 地址 → 经纬度
  Future<(double lat, double lng)?> geocode(String address) async {
    try {
      final response = await _dio.get(
        '/geocode/geo',
        queryParameters: {
          'key': _apiKey,
          'address': address,
          'output': 'json',
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] != '1') return null;

      final geocodes = data['geocodes'] as List? ?? [];
      if (geocodes.isEmpty) return null;

      final first = geocodes.first as Map<String, dynamic>;
      final location = first['location']?.toString() ?? '';
      final parts = location.split(',');
      if (parts.length < 2) return null;

      final lng = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lng == null || lat == null) return null;
      return (lat, lng);
    } on DioException catch (e) {
      AppLogger.error('高德地理编码失败', tag: 'AmapRest', error: e);
      return null;
    }
  }
}
