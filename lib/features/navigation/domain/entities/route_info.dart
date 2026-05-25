import 'package:equatable/equatable.dart';

/// 路线信息实体
class RouteInfo extends Equatable {
  /// 目的地名称
  final String destination;

  /// 总距离（米）
  final double totalDistance;

  /// 预计时长（分钟）
  final int estimatedMinutes;

  /// 导航步骤列表
  final List<RouteStep> steps;

  /// 特殊路段（台阶、斜坡等）
  final List<SpecialSegment> specialSegments;

  const RouteInfo({
    required this.destination,
    required this.totalDistance,
    required this.estimatedMinutes,
    required this.steps,
    this.specialSegments = const [],
  });

  @override
  List<Object?> get props => [destination, totalDistance, estimatedMinutes];
}

/// 导航步骤
class RouteStep extends Equatable {
  /// 步骤描述（如"前方50米右转"）
  final String instruction;

  /// 该步骤的距离（米）
  final double distance;

  /// 转弯角度（度，正值右转，负值左转，0直行）
  final double? turnAngle;

  /// 转弯方向描述
  final String? turnDirection;

  /// 地标描述（用于增强导航信息）
  final String? landmark;

  /// 步骤起点经纬度
  final double latitude;
  final double longitude;

  const RouteStep({
    required this.instruction,
    required this.distance,
    this.turnAngle,
    this.turnDirection,
    this.landmark,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [instruction, latitude, longitude];
}

/// 特殊路段
class SpecialSegment extends Equatable {
  /// 特殊路段类型
  final SpecialSegmentType type;

  /// 描述
  final String description;

  /// 距离起点的距离（米）
  final double distanceFromStart;

  /// 经纬度
  final double latitude;
  final double longitude;

  const SpecialSegment({
    required this.type,
    required this.description,
    required this.distanceFromStart,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [type, distanceFromStart];
}

/// 特殊路段类型
enum SpecialSegmentType {
  stairs('台阶'),
  slope('斜坡'),
  crosswalk('人行横道'),
  trafficLight('红绿灯'),
  underpass('地下通道'),
  overpass('天桥'),
  narrowPath('窄路'),
  construction('施工区域');

  final String label;
  const SpecialSegmentType(this.label);
}

/// 导航状态
enum NavigationStatus {
  idle,        // 空闲
  planning,    // 规划中
  navigating,  // 导航中
  arrived,     // 已到达
  error,       // 错误
}
