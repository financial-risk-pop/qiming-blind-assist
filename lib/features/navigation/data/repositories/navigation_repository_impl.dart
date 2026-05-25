import 'dart:async';

import '../../domain/entities/route_info.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../datasources/navigation_data_source.dart';
import '../../../../core/event_bus/event_bus.dart';
import '../../../../core/utils/logger.dart';

/// 导航仓库实现
/// 
/// 连接数据源和领域层，额外负责：
/// 1. 导航指令通过事件总线推送给语音模块
/// 2. 偏航检测和纠正提醒
/// 3. 到达通知
class NavigationRepositoryImpl implements NavigationRepository {
  final NavigationDataSource _dataSource;
  final EventBus _eventBus;
  
  StreamSubscription? _navigationSubscription;
  Timer? _deviationCheckTimer;
  RouteInfo? _activeRoute;

  NavigationRepositoryImpl({
    required NavigationDataSource dataSource,
    required EventBus eventBus,
  })  : _dataSource = dataSource,
        _eventBus = eventBus;

  @override
  Future<RouteInfo> planRoute({required String destination}) async {
    final route = await _dataSource.planRoute(destination: destination);

    // 通过语音播报路线概要
    _eventBus.fire(SpeakRequestEvent(
      text: '已规划到${route.destination}的路线，'
          '全程${route.totalDistance.round()}米，'
          '预计步行${route.estimatedMinutes}分钟，'
          '共${route.steps.length}个步骤。'
          '说"开始导航"即可出发。',
      priority: FeedbackPriority.information,
      sourceModule: 'navigation',
    ));

    return route;
  }

  @override
  Stream<RouteStep> startNavigation(RouteInfo route) {
    _activeRoute = route;
    _dataSource.startNavigation(route);

    // 监听导航指令并通过事件总线播报
    _navigationSubscription?.cancel();
    _navigationSubscription = _dataSource.navigationStream.listen((step) {
      _eventBus.fire(NavigationEvent(
        instruction: step.instruction,
        distanceToNext: step.distance,
      ));

      // 播报导航指令
      String speechText = step.instruction;
      if (step.landmark != null) {
        speechText += '，参考地标：${step.landmark}';
      }
      
      _eventBus.fire(SpeakRequestEvent(
        text: speechText,
        priority: FeedbackPriority.navigation,
        sourceModule: 'navigation',
      ));
    });

    // 启动定期偏航检测
    _startDeviationCheck(route);

    // 播报开始导航
    _eventBus.fire(SpeakRequestEvent(
      text: '导航开始，${route.steps.isNotEmpty ? route.steps[0].instruction : ""}',
      priority: FeedbackPriority.navigation,
      interruptCurrent: true,
      sourceModule: 'navigation',
    ));

    return _dataSource.navigationStream;
  }

  @override
  Future<void> stopNavigation() async {
    _activeRoute = null;
    _navigationSubscription?.cancel();
    _deviationCheckTimer?.cancel();
    _dataSource.stopNavigation();

    _eventBus.fire(SpeakRequestEvent(
      text: '导航已停止',
      priority: FeedbackPriority.information,
      sourceModule: 'navigation',
    ));

    AppLogger.info('导航已停止', tag: 'NavRepo');
  }

  @override
  Future<List<POIResult>> searchPOI(String keyword, {double radius = 1000}) {
    return _dataSource.searchPOI(keyword, radius: radius);
  }

  @override
  Future<LocationInfo> getCurrentLocation() {
    return _dataSource.getCurrentLocation();
  }

  @override
  Future<double?> checkDeviation(RouteInfo route) {
    return _dataSource.checkDeviation(route);
  }

  /// 定期检查偏航
  void _startDeviationCheck(RouteInfo route) {
    _deviationCheckTimer?.cancel();
    _deviationCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        if (_activeRoute == null) return;
        
        final deviation = await _dataSource.checkDeviation(route);
        if (deviation != null) {
          _eventBus.fire(NavigationEvent(
            instruction: '您已偏离路线${deviation.round()}米，正在重新规划',
            isDeviationAlert: true,
          ));

          _eventBus.fire(SpeakRequestEvent(
            text: '注意，您已偏离路线${deviation.round()}米，正在为您重新规划路线',
            priority: FeedbackPriority.navigation,
            interruptCurrent: true,
            sourceModule: 'navigation',
          ));

          // 自动重新规划
          try {
            final newRoute = await planRoute(destination: route.destination);
            _dataSource.stopNavigation();
            _dataSource.startNavigation(newRoute);
            _activeRoute = newRoute;
          } catch (e) {
            AppLogger.error('重新规划路线失败', tag: 'NavRepo', error: e);
          }
        }
      },
    );
  }

  /// 释放资源
  Future<void> dispose() async {
    _navigationSubscription?.cancel();
    _deviationCheckTimer?.cancel();
    await _dataSource.dispose();
  }
}
