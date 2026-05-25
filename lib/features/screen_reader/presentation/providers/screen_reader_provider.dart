import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_info.dart';
import '../../domain/entities/screen_element.dart';
import '../../domain/entities/screen_read_result.dart';
import '../../domain/repositories/screen_reader_repository.dart' show AccessibilityAction;
import '../../data/datasources/screen_reader_platform_data_source.dart';
import '../../data/datasources/app_knowledge_data_source.dart';
import '../../data/repositories/screen_reader_repository_impl.dart';
import '../../../../core/accessibility/a11y_config.dart';
import '../../../../core/network/network_info.dart';
import '../../../voice_interaction/presentation/providers/voice_provider.dart';
import '../../../ocr_recognition/presentation/providers/ocr_provider.dart';

/// App解读状态
class ScreenReaderState {
  final ScreenReaderPageStatus status;
  final bool isServiceEnabled;
  final AppInfo? currentApp;
  final ScreenReadResult? lastResult;
  final List<ScreenElement> foundElements;
  final String? errorMessage;

  const ScreenReaderState({
    this.status = ScreenReaderPageStatus.checking,
    this.isServiceEnabled = false,
    this.currentApp,
    this.lastResult,
    this.foundElements = const [],
    this.errorMessage,
  });

  ScreenReaderState copyWith({
    ScreenReaderPageStatus? status,
    bool? isServiceEnabled,
    AppInfo? currentApp,
    ScreenReadResult? lastResult,
    List<ScreenElement>? foundElements,
    String? errorMessage,
  }) {
    return ScreenReaderState(
      status: status ?? this.status,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      currentApp: currentApp ?? this.currentApp,
      lastResult: lastResult ?? this.lastResult,
      foundElements: foundElements ?? this.foundElements,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// App解读页面状态枚举
enum ScreenReaderPageStatus {
  checking,
  serviceDisabled,
  ready,
  reading,
  error,
}

/// App解读Notifier
class ScreenReaderNotifier extends StateNotifier<ScreenReaderState> {
  final ScreenReaderRepositoryImpl _repository;
  StreamSubscription? _screenChangeSubscription;

  ScreenReaderNotifier({required ScreenReaderRepositoryImpl repository})
      : _repository = repository,
        super(const ScreenReaderState());

  /// 初始化并检查无障碍服务状态
  Future<void> initialize() async {
    try {
      await _repository.initialize();

      final isEnabled = await _repository.isAccessibilityServiceEnabled();
      state = state.copyWith(
        isServiceEnabled: isEnabled,
        status: isEnabled
            ? ScreenReaderPageStatus.ready
            : ScreenReaderPageStatus.serviceDisabled,
      );

      if (isEnabled) {
        _startScreenChangeListener();
      }
    } catch (e) {
      state = state.copyWith(
        status: ScreenReaderPageStatus.error,
        errorMessage: '初始化失败',
      );
    }
  }

  /// 刷新无障碍服务状态
  Future<void> refreshServiceStatus() async {
    try {
      final isEnabled = await _repository.isAccessibilityServiceEnabled();
      state = state.copyWith(
        isServiceEnabled: isEnabled,
        status: isEnabled
            ? ScreenReaderPageStatus.ready
            : ScreenReaderPageStatus.serviceDisabled,
      );

      if (isEnabled) {
        _startScreenChangeListener();
      }
    } catch (e) {
      // 刷新状态失败不阻塞 UI
      state = state.copyWith(
        status: ScreenReaderPageStatus.serviceDisabled,
        isServiceEnabled: false,
      );
    }
  }

  /// 打开无障碍设置
  Future<void> openAccessibilitySettings() async {
    try {
      await _repository.requestAccessibilityService();
    } catch (e) {
      // 打开设置失败不阻塞 UI
    }
  }

  /// 解读当前屏幕
  Future<void> readCurrentScreen() async {
    try {
      state = state.copyWith(status: ScreenReaderPageStatus.reading);
      final result = await _repository.readCurrentScreen();
      state = state.copyWith(
        status: ScreenReaderPageStatus.ready,
        lastResult: result,
        currentApp: result.appInfo,
      );
    } catch (e) {
      state = state.copyWith(
        status: ScreenReaderPageStatus.error,
        errorMessage: '解读失败: $e',
      );
    }
  }

  /// 获取当前App信息
  Future<void> refreshAppInfo() async {
    try {
      final appInfo = await _repository.getCurrentAppInfo();
      state = state.copyWith(currentApp: appInfo);
    } catch (e) {
      state = state.copyWith(errorMessage: '获取App信息失败');
    }
  }

  /// 搜索元素
  Future<void> findElements(String query) async {
    try {
      final elements = await _repository.findElements(query);
      state = state.copyWith(foundElements: elements);
    } catch (e) {
      state = state.copyWith(errorMessage: '搜索失败');
    }
  }

  /// 执行屏幕操作
  /// 
  /// [action] 可为：
  /// - `'click'` / `'long_click'` / `'scroll_forward'` / `'scroll_backward'` / `'focus'`
  /// [params] 可选参数，至少包含 `elementId` 或 `target`
  Future<void> performAction(
    String action, {
    Map<String, dynamic>? params,
  }) async {
    final elementId = params?['elementId'] as String? ??
        params?['target'] as String? ??
        '';
    final accAction = switch (action) {
      'click' => AccessibilityAction.click,
      'long_click' => AccessibilityAction.longClick,
      'scroll_forward' => AccessibilityAction.scrollForward,
      'scroll_backward' => AccessibilityAction.scrollBackward,
      'focus' => AccessibilityAction.focus,
      'clear_focus' => AccessibilityAction.clearFocus,
      'set_text' => AccessibilityAction.setText,
      'copy' => AccessibilityAction.copy,
      'paste' => AccessibilityAction.paste,
      _ => AccessibilityAction.click,
    };
    await _repository.performAction(elementId, accAction);
    // 操作后重新解读
    await readCurrentScreen();
  }

  /// 监听屏幕变化
  void _startScreenChangeListener() {
    _screenChangeSubscription?.cancel();
    _screenChangeSubscription = _repository.screenChangeStream.listen(
      (event) {
        // 屏幕变化时自动刷新App信息
        refreshAppInfo();
      },
    );
  }

  @override
  void dispose() {
    _screenChangeSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}

/// ========== Providers ==========

/// 无障碍配置Provider
final a11yConfigProvider = Provider<AccessibilityConfig>((ref) {
  return AccessibilityConfig();
});

/// ScreenReader Platform数据源Provider
final screenReaderPlatformProvider =
    Provider<ScreenReaderPlatformDataSource>((ref) {
  final ds = ScreenReaderPlatformDataSource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

/// App知识库数据源Provider
final appKnowledgeProvider = Provider<AppKnowledgeDataSource>((ref) {
  final ds = AppKnowledgeDataSource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

/// ScreenReader仓库Provider
final screenReaderRepositoryProvider =
    Provider<ScreenReaderRepositoryImpl>((ref) {
  final platformDS = ref.watch(screenReaderPlatformProvider);
  final knowledgeDS = ref.watch(appKnowledgeProvider);
  final eventBus = ref.watch(eventBusProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  final config = ref.watch(a11yConfigProvider);
  return ScreenReaderRepositoryImpl(
    platformDataSource: platformDS,
    knowledgeDataSource: knowledgeDS,
    eventBus: eventBus,
    networkInfo: networkInfo,
    config: config,
  );
});

/// App解读状态Provider
final screenReaderNotifierProvider =
    StateNotifierProvider<ScreenReaderNotifier, ScreenReaderState>((ref) {
  final repository = ref.watch(screenReaderRepositoryProvider);
  return ScreenReaderNotifier(repository: repository);
});
