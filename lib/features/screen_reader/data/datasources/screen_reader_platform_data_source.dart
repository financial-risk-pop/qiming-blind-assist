import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/app_info.dart';
import '../../domain/entities/screen_element.dart';
import '../../domain/entities/screen_read_result.dart';

/// App内容解读 - Platform Channel数据源
/// 
/// 通过Platform Channel与Android/iOS原生层通信：
/// 
/// Android端：
///   - AccessibilityService获取屏幕元素树
///   - 监听窗口变化事件（App切换/页面切换）
/// iOS端：
///   - UIAccessibility API获取元素信息
/// 
/// 注意：当前为Flutter端桩实现，真实功能需要原生层配合。
/// 原生层未实现时，所有方法会返回空数据或false。
class ScreenReaderPlatformDataSource {
  static const _channel = MethodChannel(AppConstants.screenReaderChannel);
  static const _eventChannel =
      EventChannel('${AppConstants.screenReaderChannel}/events');

  // 屏幕变化事件流
  final _screenChangeController =
      StreamController<ScreenChangeEvent>.broadcast();
  Stream<ScreenChangeEvent> get screenChangeStream =>
      _screenChangeController.stream;

  StreamSubscription? _eventSubscription;

  // ==================== 初始化 ====================

  /// 初始化Platform Channel监听
  Future<void> initialize() async {
    try {
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          try {
            final data = Map<String, dynamic>.from(event as Map);
            final changeEvent = _parseScreenChangeEvent(data);
            _screenChangeController.add(changeEvent);
          } catch (e) {
            AppLogger.error('解析屏幕变化事件失败', tag: 'ScreenDS', error: e);
          }
        },
        onError: (error) {
          AppLogger.warning('屏幕事件流错误（原生层未实现）', tag: 'ScreenDS');
        },
      );
    } catch (e) {
      AppLogger.warning('EventChannel 初始化失败（原生层未实现）', tag: 'ScreenDS');
    }

    AppLogger.info('ScreenReader Platform数据源初始化完成', tag: 'ScreenDS');
  }

  // ==================== 无障碍服务检查 ====================

  /// 检查无障碍服务是否启用
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isServiceEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.warning('无障碍服务检查失败（原生层未实现）: ${e.message}', tag: 'ScreenDS');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 引导用户开启无障碍服务
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      throw AccessibilityServiceException(
        message: '打开无障碍设置失败: ${e.message}',
      );
    } on MissingPluginException {
      throw const AccessibilityServiceException(
        message: '无障碍服务原生层未实现',
      );
    }
  }

  // ==================== 屏幕元素获取 ====================

  /// 获取当前屏幕的完整元素树
  Future<List<ScreenElement>> getScreenElements() async {
    try {
      final result = await _channel.invokeMethod<String>('getScreenElements');
      if (result == null || result.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(result);
      return jsonList.map((e) => _parseScreenElement(e)).toList();
    } on PlatformException catch (e) {
      AppLogger.warning('获取屏幕元素失败: ${e.message}', tag: 'ScreenDS');
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  /// 获取当前前台App信息
  Future<AppInfo> getCurrentAppInfo() async {
    try {
      final result =
          await _channel.invokeMethod<Map>('getCurrentAppInfo');
      if (result == null) {
        return _unknownAppInfo();
      }

      final data = Map<String, dynamic>.from(result);
      return AppInfo(
        packageName: data['packageName'] as String? ?? '',
        appName: data['appName'] as String? ?? '未知应用',
        currentActivity: data['currentActivity'] as String?,
        category: _mapCategory(data['category'] as String?),
        description: data['description'] as String?,
      );
    } on PlatformException catch (e) {
      AppLogger.warning('获取App信息失败: ${e.message}', tag: 'ScreenDS');
      return _unknownAppInfo();
    } on MissingPluginException {
      return _unknownAppInfo();
    }
  }

  AppInfo _unknownAppInfo() {
    return const AppInfo(
      packageName: '',
      appName: '未知应用',
      category: AppCategory.unknown,
    );
  }

  /// 获取指定位置的元素详情
  Future<ScreenElement?> getElementAt(Offset position) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'getElementAt',
        {'x': position.dx, 'y': position.dy},
      );
      if (result == null) return null;

      final data = json.decode(result);
      return _parseScreenElement(data);
    } on PlatformException catch (e) {
      AppLogger.warning('获取元素详情失败: ${e.message}', tag: 'ScreenDS');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 在屏幕上搜索匹配的元素
  Future<List<ScreenElement>> findElements(String query) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'findElements',
        {'query': query},
      );
      if (result == null || result.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(result);
      return jsonList.map((e) => _parseScreenElement(e)).toList();
    } on PlatformException catch (e) {
      AppLogger.warning('搜索元素失败: ${e.message}', tag: 'ScreenDS');
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  // ==================== 执行操作 ====================

  /// 在屏幕上执行操作（点击/滚动等）
  Future<bool> performAction(
    String action, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'performAction',
        {
          'action': action,
          ...?params,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.warning('执行操作失败: $action, ${e.message}', tag: 'ScreenDS');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ==================== 解析工具 ====================

  /// 解析屏幕元素
  ScreenElement _parseScreenElement(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);

    // 递归解析子元素
    List<ScreenElement> children = const [];
    if (map['children'] != null) {
      children = (map['children'] as List)
          .map((child) => _parseScreenElement(child))
          .toList();
    }

    return ScreenElement(
      id: map['id'] as String? ??
          '${map['packageName'] ?? 'unknown'}_${DateTime.now().microsecondsSinceEpoch}',
      type: _mapElementType(map['elementType'] as String?),
      text: map['text'] as String?,
      contentDescription: map['contentDescription'] as String?,
      bounds: _parseBounds(map['bounds']),
      isClickable: map['isClickable'] as bool? ?? false,
      isScrollable: map['isScrollable'] as bool? ?? false,
      isFocused: map['isFocused'] as bool? ?? false,
      isVisible: map['isVisible'] as bool? ?? true,
      isChecked: map['isChecked'] as bool?,
      children: children,
      indexInParent: map['indexInParent'] as int?,
    );
  }

  /// 解析屏幕变化事件
  ScreenChangeEvent _parseScreenChangeEvent(Map<String, dynamic> data) {
    return ScreenChangeEvent(
      type: _mapChangeType(data['changeType'] as String?),
      newAppInfo: data['packageName'] != null
          ? AppInfo(
              packageName: data['packageName'] as String,
              appName: data['appName'] as String? ?? '未知应用',
            )
          : null,
      description: data['description'] as String?,
      timestamp: DateTime.now(),
    );
  }

  /// 解析边界框 [left, top, right, bottom]
  Rect _parseBounds(dynamic bounds) {
    if (bounds == null) return Rect.zero;
    if (bounds is List && bounds.length == 4) {
      return Rect.fromLTRB(
        (bounds[0] as num).toDouble(),
        (bounds[1] as num).toDouble(),
        (bounds[2] as num).toDouble(),
        (bounds[3] as num).toDouble(),
      );
    }
    return Rect.zero;
  }

  /// 映射元素类型
  ScreenElementType _mapElementType(String? type) {
    return switch (type) {
      'button' => ScreenElementType.button,
      'text' => ScreenElementType.text,
      'edittext' || 'input' => ScreenElementType.textField,
      'image' => ScreenElementType.image,
      'icon' => ScreenElementType.icon,
      'checkbox' => ScreenElementType.checkbox,
      'radio' => ScreenElementType.radioButton,
      'switch' || 'toggle' => ScreenElementType.switchWidget,
      'slider' || 'seekbar' => ScreenElementType.slider,
      'list' || 'recyclerview' || 'listitem' => ScreenElementType.listItem,
      'tab' => ScreenElementType.tab,
      'navigation' || 'navbar' => ScreenElementType.navigationBar,
      'toolbar' => ScreenElementType.toolbar,
      'dialog' => ScreenElementType.dialog,
      'scrollable' => ScreenElementType.scrollable,
      'container' => ScreenElementType.container,
      _ => ScreenElementType.unknown,
    };
  }

  /// 映射App分类
  AppCategory _mapCategory(String? category) {
    return switch (category) {
      'social' => AppCategory.social,
      'shopping' => AppCategory.shopping,
      'payment' || 'finance' => AppCategory.payment,
      'navigation' || 'map' => AppCategory.navigation,
      'food' => AppCategory.food,
      'travel' => AppCategory.travel,
      'news' => AppCategory.news,
      'entertainment' || 'video' => AppCategory.entertainment,
      'education' => AppCategory.education,
      'health' => AppCategory.health,
      'tool' || 'tools' || 'utility' => AppCategory.tools,
      'system' => AppCategory.system,
      _ => AppCategory.unknown,
    };
  }

  /// 映射变化类型
  ScreenChangeType _mapChangeType(String? type) {
    return switch (type) {
      'app_switch' => ScreenChangeType.appSwitch,
      'page_change' => ScreenChangeType.pageChange,
      'content_update' => ScreenChangeType.contentUpdate,
      'dialog_show' || 'dialog_shown' => ScreenChangeType.dialogShown,
      'dialog_dismiss' || 'dialog_dismissed' =>
        ScreenChangeType.dialogDismissed,
      'notification' => ScreenChangeType.notification,
      _ => ScreenChangeType.contentUpdate,
    };
  }

  // ==================== 资源释放 ====================

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _screenChangeController.close();
  }
}
