import '../entities/route_info.dart';
import '../repositories/navigation_repository.dart';

/// 路线规划用例
class PlanRouteUseCase {
  final NavigationRepository _repository;

  PlanRouteUseCase(this._repository);

  /// 执行路线规划
  Future<RouteInfo> call({required String destination}) {
    return _repository.planRoute(destination: destination);
  }
}

/// 开始导航用例
class StartNavigationUseCase {
  final NavigationRepository _repository;

  StartNavigationUseCase(this._repository);

  /// 执行开始导航
  Stream<RouteStep> call(RouteInfo route) {
    return _repository.startNavigation(route);
  }
}

/// POI搜索用例
class SearchPOIUseCase {
  final NavigationRepository _repository;

  SearchPOIUseCase(this._repository);

  /// 执行POI搜索
  Future<List<POIResult>> call(String keyword, {double radius = 1000}) {
    return _repository.searchPOI(keyword, radius: radius);
  }
}
