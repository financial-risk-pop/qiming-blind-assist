import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/logger.dart';

/// 高德地图导航服务
///
/// 提供：
/// 1. 地理编码（地名 → 坐标）
/// 2. 步行路径规划（起点 → 终点）
/// 3. 当前位置获取
class AmapNavService {
  // TODO: 替换为你自己的高德 Web 服务 API Key
  // 申请地址：https://console.amap.com/dev/key/app
  // 类型选「Web服务」
  static const String _apiKey = 'YOUR_AMAP_WEB_SERVICE_KEY';

  static const String _geoUrl = 'https://restapi.amap.com/v3/geocode/geo';
  static const String _walkUrl =
      'https://restapi.amap.com/v3/direction/walking';
  static const String _reGeoUrl =
      'https://restapi.amap.com/v3/geocode/regeo';

  /// 获取当前 GPS 位置
  static Future<Position?> getCurrentLocation() async {
    try {
      // 检查定位服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('定位服务未开启', tag: 'AmapNav');
        return null;
      }

      // 检查权限
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          AppLogger.warning('定位权限被拒绝', tag: 'AmapNav');
          return null;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        AppLogger.warning('定位权限被永久拒绝', tag: 'AmapNav');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      AppLogger.info('定位成功: ${pos.latitude}, ${pos.longitude}',
          tag: 'AmapNav');
      return pos;
    } catch (e) {
      AppLogger.error('定位失败: $e', tag: 'AmapNav');
      return null;
    }
  }

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// 地理编码：地名 → 坐标
  ///
  /// [city] 传入当前城市可大幅提高准确率
  static Future<GeoResult?> geocode(String address, {String? city}) async {
    if (_apiKey == 'YOUR_AMAP_KEY_HERE') {
      return _mockGeocode(address);
    }
    try {
      final params = <String, String>{
        'key': _apiKey,
        'address': address,
        'output': 'JSON',
      };
      if (city != null && city.isNotEmpty) {
        params['city'] = city;
      }
      final resp = await _dio.get(_geoUrl, queryParameters: params);
      final data = resp.data is String ? jsonDecode(resp.data) : resp.data;
      AppLogger.info('地理编码: address=$address, city=$city, status=${data['status']}, count=${data['count']}',
          tag: 'AmapNav');
      if (data['status'] != '1' ||
          data['geocodes'] == null ||
          (data['geocodes'] as List).isEmpty) {
        AppLogger.warning('地理编码无结果: ${data['info']}', tag: 'AmapNav');
        return null;
      }
      final geo = data['geocodes'][0];
      return GeoResult(
        location: geo['location'] ?? '',
        formattedAddress: geo['formatted_address'] ?? address,
        city: geo['city']?.toString() ?? '',
      );
    } catch (e) {
      AppLogger.error('地理编码异常: $e', tag: 'AmapNav');
      return null;
    }
  }

  /// 逆地理编码：坐标 → 地名
  /// [lng], [lat] 可以是 WGS-84 或 GCJ-02，内部会自动转换
  static Future<String?> reverseGeocode(double lng, double lat,
      {bool alreadyGcj02 = false}) async {
    if (_apiKey == 'YOUR_AMAP_KEY_HERE') {
      return '当前位置附近';
    }
    try {
      double gcjLng = lng, gcjLat = lat;
      if (!alreadyGcj02) {
        final gcj = _CoordTransform.wgs84ToGcj02(lng, lat);
        gcjLng = gcj.$1;
        gcjLat = gcj.$2;
      }
      final resp = await _dio.get(_reGeoUrl, queryParameters: {
        'key': _apiKey,
        'location': '$gcjLng,$gcjLat',
        'output': 'JSON',
      });
      final data = resp.data is String ? jsonDecode(resp.data) : resp.data;
      if (data['status'] != '1') return null;
      return data['regeocode']?['formatted_address']?.toString();
    } catch (e) {
      AppLogger.error('逆地理编码异常: $e', tag: 'AmapNav');
      return null;
    }
  }

  /// 步行路径规划（v3 API）
  static Future<WalkRouteResult?> walkRoute({
    required String origin,
    required String destination,
  }) async {
    if (_apiKey == 'YOUR_AMAP_KEY_HERE') {
      return _mockWalkRoute(destination);
    }
    try {
      AppLogger.info('路径规划请求: origin=$origin, dest=$destination',
          tag: 'AmapNav');
      final resp = await _dio.get(_walkUrl, queryParameters: {
        'key': _apiKey,
        'origin': origin,
        'destination': destination,
      });
      final data = resp.data is String ? jsonDecode(resp.data) : resp.data;
      AppLogger.info('路径规划返回: status=${data['status']}, info=${data['info']}',
          tag: 'AmapNav');

      if (data['status'] != '1' || data['route'] == null) {
        AppLogger.warning(
            '路径规划失败: status=${data['status']}, info=${data['info']}, infocode=${data['infocode']}',
            tag: 'AmapNav');
        return null;
      }
      final route = data['route'];
      final paths = route['paths'] as List?;
      if (paths == null || paths.isEmpty) return null;

      final path = paths[0];
      final steps = (path['steps'] as List?) ?? [];
      final stepDescs = steps.map<String>((s) {
        // v3 字段：instruction, road (非 road_name), distance
        final instruction = s['instruction']?.toString() ?? '';
        final road = (s['road'] ?? s['road_name'] ?? '').toString();
        final dist = (s['distance'] ?? s['step_distance'] ?? '').toString();
        return '$instruction${road.isNotEmpty ? "（$road）" : ""}${dist.isNotEmpty ? "，$dist米" : ""}';
      }).toList();

      return WalkRouteResult(
        totalDistance:
            double.tryParse(path['distance']?.toString() ?? '0') ?? 0,
        totalDuration:
            double.tryParse(path['duration']?.toString() ?? '0') ?? 0,
        steps: stepDescs,
      );
    } catch (e) {
      AppLogger.error('路径规划异常: $e', tag: 'AmapNav');
      return null;
    }
  }

  /// 一站式导航：输入目的地名称，返回完整路线
  static Future<NavResult> navigate(String destination) async {
    // 1. 获取当前位置
    final pos = await getCurrentLocation();
    String originStr;
    String originName;
    String currentCity = '';

    if (pos != null) {
      // GPS 返回 WGS-84 坐标，高德 API 需要 GCJ-02，必须转换否则偏移100-700米
      final gcj = _CoordTransform.wgs84ToGcj02(pos.longitude, pos.latitude);
      originStr = '${gcj.$1},${gcj.$2}';
      AppLogger.info('坐标转换: WGS84(${pos.longitude},${pos.latitude}) -> GCJ02(${gcj.$1},${gcj.$2})',
          tag: 'AmapNav');

      // 逆地理编码获取当前地址和城市（originStr已是GCJ-02坐标）
      try {
        final resp = await _dio.get(_reGeoUrl, queryParameters: {
          'key': _apiKey,
          'location': originStr,
          'output': 'JSON',
        });
        final data = resp.data is String ? jsonDecode(resp.data) : resp.data;
        if (data['status'] == '1') {
          final regeo = data['regeocode'];
          originName = regeo?['formatted_address']?.toString() ?? '当前位置';
          // 提取城市
          final comp = regeo?['addressComponent'];
          currentCity = comp?['city']?.toString() ?? '';
          if (currentCity.isEmpty) {
            currentCity = comp?['district']?.toString() ?? '';
          }
          AppLogger.info('当前城市: $currentCity', tag: 'AmapNav');
        } else {
          originName = '当前位置';
        }
      } catch (e) {
        originName = '当前位置';
        AppLogger.warning('逆地理编码失败: $e', tag: 'AmapNav');
      }
    } else {
      originStr = '116.397428,39.90923';
      originName = '当前位置（定位失败）';
      currentCity = '北京';
    }

    // 2. 地理编码目的地（带城市参数）
    var geo = await geocode(destination, city: currentCity);

    // 如果没找到，试试拼上城市名
    if (geo == null && currentCity.isNotEmpty) {
      geo = await geocode('$currentCity$destination');
    }

    // 如果还没找到，不带城市参数试一次
    if (geo == null) {
      geo = await geocode(destination);
    }

    if (geo == null) {
      return NavResult.error(
          '找不到"$destination"，请尝试输入更详细的地址，如"东莞市人民医院"');
    }

    // 3. 路径规划
    final route = await walkRoute(
      origin: originStr,
      destination: geo.location,
    );
    if (route == null) {
      return NavResult.error('路线规划失败，请稍后重试');
    }

    // 4. 组装结果
    final distKm = (route.totalDistance / 1000).toStringAsFixed(1);
    final durMin = (route.totalDuration / 60).ceil();

    final summary = '已为您规划到${geo.formattedAddress}的步行路线，'
        '全程约${distKm}公里，预计${durMin}分钟。';

    final stepsText = route.steps.asMap().entries.map((e) {
      return '第${e.key + 1}步：${e.value}';
    }).join('\n');

    return NavResult(
      success: true,
      originName: originName,
      destName: geo.formattedAddress,
      summary: summary,
      stepsText: stepsText,
      totalDistance: route.totalDistance,
      totalDurationMin: durMin,
      speakText: '$summary\n${route.steps.take(3).join("。然后，")}',
    );
  }

  // ===== Mock 数据（没有 API Key 时使用）=====

  static GeoResult _mockGeocode(String address) {
    return GeoResult(
      location: '116.481028,39.989643',
      formattedAddress: address,
      city: '',
    );
  }

  static WalkRouteResult _mockWalkRoute(String dest) {
    return WalkRouteResult(
      totalDistance: 1200,
      totalDuration: 1080,
      steps: [
        '从起点向东出发，沿人民路步行200米',
        '右转进入建设大道，步行350米',
        '过第一个红绿灯路口，继续直行150米',
        '左转进入和平街，步行300米',
        '到达目的地，在道路右侧',
      ],
    );
  }
}

class GeoResult {
  final String location; // "lng,lat"
  final String formattedAddress;
  final String city;

  const GeoResult({
    required this.location,
    required this.formattedAddress,
    required this.city,
  });
}

class WalkRouteResult {
  final double totalDistance; // 米
  final double totalDuration; // 秒
  final List<String> steps;

  const WalkRouteResult({
    required this.totalDistance,
    required this.totalDuration,
    required this.steps,
  });
}

class NavResult {
  final bool success;
  final String? errorMsg;
  final String originName;
  final String destName;
  final String summary;
  final String stepsText;
  final double totalDistance;
  final int totalDurationMin;
  final String speakText; // TTS 播报用的文本

  const NavResult({
    this.success = false,
    this.errorMsg,
    this.originName = '',
    this.destName = '',
    this.summary = '',
    this.stepsText = '',
    this.totalDistance = 0,
    this.totalDurationMin = 0,
    this.speakText = '',
  });

  factory NavResult.error(String msg) => NavResult(
        success: false,
        errorMsg: msg,
        speakText: msg,
      );
}

/// WGS-84 ↔ GCJ-02 坐标转换
///
/// GPS 返回 WGS-84（国际标准），高德地图使用 GCJ-02（国测局火星坐标）。
/// 在中国大陆两者偏差 100-700 米，必须转换。
class _CoordTransform {
  static const double _a = 6378245.0;
  static const double _ee = 0.00669342162296594323;

  /// WGS-84 → GCJ-02
  /// 返回 (lng, lat)
  static (double, double) wgs84ToGcj02(double wgsLng, double wgsLat) {
    if (_outOfChina(wgsLng, wgsLat)) return (wgsLng, wgsLat);

    double dLat = _transformLat(wgsLng - 105.0, wgsLat - 35.0);
    double dLng = _transformLng(wgsLng - 105.0, wgsLat - 35.0);
    final radLat = wgsLat / 180.0 * math.pi;
    double magic = math.sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * math.pi);
    dLng = (dLng * 180.0) / (_a / sqrtMagic * math.cos(radLat) * math.pi);
    return (wgsLng + dLng, wgsLat + dLat);
  }

  static double _transformLat(double x, double y) {
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y +
        0.1 * x * y + 0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(y * math.pi) +
            40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) +
            320.0 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x +
        0.1 * x * y + 0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(x * math.pi) +
            40.0 * math.sin(x / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (150.0 * math.sin(x / 12.0 * math.pi) +
            300.0 * math.sin(x / 30.0 * math.pi)) * 2.0 / 3.0;
    return ret;
  }

  static bool _outOfChina(double lng, double lat) {
    return lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;
  }
}
