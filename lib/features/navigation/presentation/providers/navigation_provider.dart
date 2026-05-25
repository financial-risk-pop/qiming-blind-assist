import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/route_info.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../../data/datasources/navigation_data_source.dart';
import '../../data/repositories/navigation_repository_impl.dart';
import '../../../voice_interaction/presentation/providers/voice_provider.dart';

/// 导航状态
class NavigationState {
  final NavigationPageStatus status;
  final RouteInfo? currentRoute;
  final RouteStep? currentStep;
  final LocationInfo? currentLocation;
  final List<POIResult> searchResults;
  final String? errorMessage;

  const NavigationState({
    this.status = NavigationPageStatus.idle,
    this.currentRoute,
    this.currentStep,
    this.currentLocation,
    this.searchResults = const [],
    this.errorMessage,
  });

  NavigationState copyWith({
    NavigationPageStatus? status,
    Object? currentRoute = _navSentinel,
    Object? currentStep = _navSentinel,
    Object? currentLocation = _navSentinel,
    List<POIResult>? searchResults,
    Object? errorMessage = _navSentinel,
  }) {
    return NavigationState(
      status: status ?? this.status,
      currentRoute: currentRoute == _navSentinel
          ? this.currentRoute
          : currentRoute as RouteInfo?,
      currentStep: currentStep == _navSentinel
          ? this.currentStep
          : currentStep as RouteStep?,
      currentLocation: currentLocation == _navSentinel
          ? this.currentLocation
          : currentLocation as LocationInfo?,
      searchResults: searchResults ?? this.searchResults,
      errorMessage: errorMessage == _navSentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _navSentinel = Object();

/// 导航页面状态枚举
enum NavigationPageStatus {
  idle,
  planning,
  navigating,
  arrived,
  error,
}

/// 导航Notifier
class NavigationNotifier extends StateNotifier<NavigationState> {
  final NavigationRepositoryImpl _repository;
  StreamSubscription? _navigationSubscription;

  NavigationNotifier({required NavigationRepositoryImpl repository})
      : _repository = repository,
        super(const NavigationState());

  /// 规划路线
  Future<void> planRoute(String destination) async {
    try {
      state = state.copyWith(status: NavigationPageStatus.planning);
      final route = await _repository.planRoute(destination: destination);
      state = state.copyWith(
        status: NavigationPageStatus.idle,
        currentRoute: route,
      );
    } catch (e) {
      state = state.copyWith(
        status: NavigationPageStatus.error,
        errorMessage: '路线规划失败: $e',
      );
    }
  }

  /// 开始导航
  Future<void> startNavigation() async {
    final route = state.currentRoute;
    if (route == null) {
      state = state.copyWith(
        errorMessage: '请先规划路线再开始导航',
      );
      return;
    }

    try {
      state = state.copyWith(
        status: NavigationPageStatus.navigating,
        errorMessage: null,
      );

      _navigationSubscription?.cancel();
      _navigationSubscription = _repository.startNavigation(route).listen(
        (step) {
          state = state.copyWith(currentStep: step);
        },
        onError: (error) {
          state = state.copyWith(
            status: NavigationPageStatus.error,
            errorMessage: '导航出错',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: NavigationPageStatus.error,
        errorMessage: '启动导航失败',
      );
    }
  }

  /// 停止导航
  Future<void> stopNavigation() async {
    _navigationSubscription?.cancel();
    try {
      await _repository.stopNavigation();
    } catch (e) {
      // 即使 stop 出错也要更新状态
    }
    state = NavigationState(
      status: NavigationPageStatus.idle,
    );
  }

  /// 搜索附近POI
  Future<void> searchNearby(String keyword) async {
    try {
      final results = await _repository.searchPOI(keyword);
      state = state.copyWith(searchResults: results);
    } catch (e) {
      state = state.copyWith(errorMessage: 'POI搜索失败');
    }
  }

  /// 获取当前位置
  Future<void> refreshLocation() async {
    try {
      final location = await _repository.getCurrentLocation();
      state = state.copyWith(currentLocation: location);
    } catch (e) {
      state = state.copyWith(errorMessage: '获取位置失败');
    }
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}

/// ========== Providers ==========

/// 导航数据源Provider
final navigationDataSourceProvider = Provider<NavigationDataSource>((ref) {
  final ds = NavigationDataSource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

/// 导航仓库Provider
final navigationRepositoryProvider = Provider<NavigationRepositoryImpl>((ref) {
  final dataSource = ref.watch(navigationDataSourceProvider);
  final eventBus = ref.watch(eventBusProvider);
  return NavigationRepositoryImpl(
    dataSource: dataSource,
    eventBus: eventBus,
  );
});

/// 导航状态Provider
final navigationNotifierProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  final repository = ref.watch(navigationRepositoryProvider);
  return NavigationNotifier(repository: repository);
});
