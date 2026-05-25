import 'package:get_it/get_it.dart';

import '../event_bus/event_bus.dart';
import '../network/network_info.dart';
import '../network/api_client.dart';
import '../utils/haptic_feedback.dart';
import '../utils/permission_handler.dart';
import '../accessibility/a11y_config.dart';

/// 全局依赖注入容器
final getIt = GetIt.instance;

/// 初始化所有依赖注入
/// 
/// 注册顺序很重要：
/// 1. 核心服务（事件总线、网络、权限等）
/// 2. 数据源
/// 3. 仓库
/// 4. 用例
Future<void> configureDependencies() async {
  // ===== 核心服务（全局单例） =====
  
  // 事件总线
  getIt.registerLazySingleton<EventBus>(() => EventBus());
  
  // 网络信息
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfo());
  
  // API客户端
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  
  // 震动反馈管理器
  getIt.registerLazySingleton<HapticFeedbackManager>(
    () => HapticFeedbackManager(),
  );
  
  // 权限管理器
  getIt.registerLazySingleton<PermissionManager>(
    () => PermissionManager(),
  );
  
  // 无障碍配置
  getIt.registerLazySingleton<AccessibilityConfig>(() => AccessibilityConfig());

  // ===== 数据源 =====
  // 注意：数据源通过Riverpod Provider管理生命周期
  // GetIt主要用于非Widget上下文的服务定位

  // ===== 仓库 =====
  // 通过Riverpod Provider管理

  // ===== 用例 =====
  // 通过Riverpod Provider管理
}
