import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui';

import '../../domain/entities/app_info.dart';
import '../../domain/entities/screen_element.dart';
import '../../domain/entities/screen_read_result.dart';
import '../../domain/repositories/screen_reader_repository.dart';
import '../datasources/screen_reader_platform_data_source.dart';
import '../datasources/app_knowledge_data_source.dart';
import '../datasources/screen_ai_data_source.dart';
import '../../../../core/accessibility/a11y_config.dart';
import '../../../../core/event_bus/event_bus.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/logger.dart';

/// App内容解读仓库实现
/// 
/// 核心处理流程：
/// 1. Platform Channel获取屏幕元素树
/// 2. 知识库匹配 → 如果命中，提供结构化描述
/// 3. AI增强 → 如果开启且有网络，对图像/无描述元素进行AI解读
/// 4. 融合生成 → 组合多数据源的结果
/// 5. 缓存管理 → 减少重复解读
class ScreenReaderRepositoryImpl implements ScreenReaderRepository {
  final ScreenReaderPlatformDataSource _platformDataSource;
  final AppKnowledgeDataSource _knowledgeDataSource;
  final ScreenAiDataSource _screenAiDataSource;
  final EventBus _eventBus;
  final NetworkInfo _networkInfo;
  final AccessibilityConfig _config;

  // 上一次解读结果缓存
  ScreenReadResult? _lastResult;

  ScreenReaderRepositoryImpl({
    required ScreenReaderPlatformDataSource platformDataSource,
    required AppKnowledgeDataSource knowledgeDataSource,
    ScreenAiDataSource? screenAiDataSource,
    required EventBus eventBus,
    required NetworkInfo networkInfo,
    required AccessibilityConfig config,
  })  : _platformDataSource = platformDataSource,
        _knowledgeDataSource = knowledgeDataSource,
        _screenAiDataSource = screenAiDataSource ?? ScreenAiDataSource(),
        _eventBus = eventBus,
        _networkInfo = networkInfo,
        _config = config;

  @override
  Future<ScreenReadResult> readCurrentScreen() async {
    // 1. 获取当前App信息
    final appInfo = await _platformDataSource.getCurrentAppInfo();

    // 2. 隐私检查：是否为敏感App
    if (_config.sensitiveAppPackages.contains(appInfo.packageName)) {
      final result = ScreenReadResult(
        appInfo: appInfo,
        pageSummary: '当前在${appInfo.appName}中，该应用已设置为敏感应用，不进行内容解读',
        elements: const [],
        interactiveElementCount: 0,
        hints: const [],
        source: ScreenReadSource.cached,
        timestamp: DateTime.now(),
      );
      _notifySpeech(result.pageSummary);
      return result;
    }

    // 3. 检查缓存
    final cacheKey = _knowledgeDataSource.generateCacheKey(
      appInfo.packageName,
      appInfo.currentActivity,
    );
    final cachedDesc = _knowledgeDataSource.getCachedDescription(cacheKey);
    if (cachedDesc != null) {
      AppLogger.debug('命中缓存: $cacheKey', tag: 'ScreenRepo');
      // 即使使用缓存，也获取最新元素信息
    }

    // 4. 获取屏幕元素树
    final elements = await _platformDataSource.getScreenElements();

    // 5. 知识库匹配
    final knowledgeContext =
        _knowledgeDataSource.generateContextDescription(appInfo);
    final pageGuide = _knowledgeDataSource.getPageGuide(
      appInfo.packageName,
      appInfo.currentActivity,
    );

    // 6. 生成页面摘要
    String pageSummary = _generatePageSummary(appInfo, elements, pageGuide);

    // 7. AI增强（如果开启）
    String? aiDescription;
    if (_config.aiEnhancedReadingEnabled && await _networkInfo.isConnected) {
      aiDescription = await _getAiEnhancedDescription(
        appInfo,
        elements,
        knowledgeContext,
      );
      if (aiDescription != null) {
        pageSummary = aiDescription;
      }
    }

    // 8. 生成操作提示
    final hints = _generateInteractionHints(elements);

    // 9. 计算可交互元素数量
    final interactiveCount = elements.where((e) => e.isClickable).length;

    // 10. 组装结果
    final result = ScreenReadResult(
      appInfo: appInfo,
      pageSummary: pageSummary,
      elements: elements,
      interactiveElementCount: interactiveCount,
      hints: hints,
      aiEnhancedDescription: aiDescription,
      source: aiDescription != null
          ? ScreenReadSource.merged
          : ScreenReadSource.accessibilityApi,
      timestamp: DateTime.now(),
    );

    // 11. 缓存结果
    await _knowledgeDataSource.cacheScreenDescription(
      cacheKey: cacheKey,
      description: pageSummary,
    );

    _lastResult = result;

    // 12. 推送语音播报
    _notifySpeech(pageSummary);

    // 13. 推送事件
    _eventBus.fire(ScreenReadEvent(
      description: pageSummary,
      appName: appInfo.appName,
      requestType: 'summary',
    ));

    return result;
  }

  @override
  Future<AppInfo> getCurrentAppInfo() async {
    return _platformDataSource.getCurrentAppInfo();
  }

  @override
  Future<ScreenElement?> readElementAt(Offset position) async {
    final element = await _platformDataSource.getElementAt(position);
    if (element != null) {
      final speech = element.toSpeechText();
      _notifySpeech(speech);
    }
    return element;
  }

  @override
  Future<List<ScreenElement>> findElements(String query) async {
    final elements = await _platformDataSource.findElements(query);

    if (elements.isEmpty) {
      _notifySpeech('未找到匹配"$query"的元素');
    } else {
      final description = elements.map((e) => e.toSpeechText()).join('，');
      _notifySpeech('找到${elements.length}个匹配项：$description');
    }

    return elements;
  }

  @override
  Future<String> getAiEnhancedDescription(Uint8List screenshot) async {
    if (!await _networkInfo.isConnected) {
      AppLogger.warning('无网络，跳过 AI 增强解读', tag: 'ScreenRepo');
      return '';
    }

    try {
      final appInfo = await _platformDataSource.getCurrentAppInfo();
      final platform = Platform.isIOS ? 'ios' : 'android';

      final result = await _screenAiDataSource.analyzeScreen(
        screenshot,
        appName: appInfo.appName,
        platform: platform,
      );

      AppLogger.info(
        'AI 解读完成，置信度: ${result.confidence}',
        tag: 'ScreenRepo',
      );
      return result.description;
    } catch (e) {
      AppLogger.error('AI 增强解读失败', tag: 'ScreenRepo', error: e);
      return '';
    }
  }

  @override
  Future<bool> performAction(
    String elementId,
    AccessibilityAction action,
  ) async {
    final actionName = _mapActionName(action);
    final success = await _platformDataSource.performAction(
      actionName,
      params: {'elementId': elementId},
    );
    if (success) {
      _notifySpeech('${action.label}已执行');
    } else {
      _notifySpeech('${action.label}失败');
    }
    return success;
  }

  String _mapActionName(AccessibilityAction action) {
    return switch (action) {
      AccessibilityAction.click => 'click',
      AccessibilityAction.longClick => 'long_click',
      AccessibilityAction.scrollForward => 'scroll_forward',
      AccessibilityAction.scrollBackward => 'scroll_backward',
      AccessibilityAction.focus => 'focus',
      AccessibilityAction.clearFocus => 'clear_focus',
      AccessibilityAction.setText => 'set_text',
      AccessibilityAction.copy => 'copy',
      AccessibilityAction.paste => 'paste',
    };
  }

  @override
  Stream<ScreenChangeEvent> get screenChangeStream =>
      _platformDataSource.screenChangeStream;

  @override
  Future<bool> isAccessibilityServiceEnabled() async {
    return _platformDataSource.isAccessibilityServiceEnabled();
  }

  @override
  Future<void> requestAccessibilityService() async {
    await _platformDataSource.openAccessibilitySettings();
  }

  // ==================== 内部方法 ====================

  /// 生成页面摘要
  String _generatePageSummary(
    AppInfo appInfo,
    List<ScreenElement> elements,
    String? pageGuide,
  ) {
    final buffer = StringBuffer();
    buffer.write('当前在${appInfo.appName}');

    // 使用知识库页面引导
    if (pageGuide != null) {
      buffer.write('，$pageGuide');
    } else {
      // 基于元素分析生成摘要
      final buttons = elements.where((e) => e.isClickable).toList();
      final texts = elements
          .where((e) => e.text != null && e.text!.isNotEmpty)
          .toList();
      final editables = elements
          .where((e) => e.type == ScreenElementType.textField)
          .toList();

      buffer.write('，页面包含');
      final parts = <String>[];
      if (buttons.isNotEmpty) parts.add('${buttons.length}个可点击按钮');
      if (texts.isNotEmpty) parts.add('${texts.length}个文本内容');
      if (editables.isNotEmpty) parts.add('${editables.length}个输入框');
      buffer.write(parts.isEmpty ? '暂无可识别元素' : parts.join('、'));
    }

    return buffer.toString();
  }

  /// AI增强解读
  Future<String?> _getAiEnhancedDescription(
    AppInfo appInfo,
    List<ScreenElement> elements,
    String? knowledgeContext,
  ) async {
    try {
      // TODO: 调用AI云端API进行图像理解
      // 请求参数：
      // - 屏幕截图
      // - 元素树结构
      // - App知识库上下文
      // 返回：自然语言页面描述

      AppLogger.info('AI增强解读暂未实现', tag: 'ScreenRepo');
      return null;
    } catch (e) {
      AppLogger.error('AI增强解读失败', tag: 'ScreenRepo', error: e);
      return null;
    }
  }

  /// 生成操作提示
  List<InteractionHint> _generateInteractionHints(
    List<ScreenElement> elements,
  ) {
    final hints = <InteractionHint>[];

    for (final element in elements) {
      if (element.isClickable && element.text != null) {
        hints.add(InteractionHint(
          text: '可以双击"${element.text}"按钮',
          elementId: element.id,
          type: HintType.tap,
        ));
      }
      if (element.type == ScreenElementType.textField) {
        hints.add(InteractionHint(
          text: '在${element.contentDescription ?? element.text ?? '输入框'}中可输入文字',
          elementId: element.id,
          type: HintType.input,
        ));
      }
      if (element.isScrollable) {
        hints.add(InteractionHint(
          text: '上下滑动可以浏览更多内容',
          elementId: element.id,
          type: HintType.scroll,
        ));
      }
    }

    return hints;
  }

  /// 通过事件总线推送语音播报
  void _notifySpeech(String text) {
    if (_config.screenReaderEnabled) {
      _eventBus.fire(SpeakRequestEvent(
        text: text,
        priority: FeedbackPriority.information,
        sourceModule: 'screen_reader',
      ));
    }
  }

  /// 获取上次结果（调试用）
  ScreenReadResult? get lastResult => _lastResult;

  /// 获取常见操作列表
  List<Map<String, String>> getCommonOperations(String packageName) {
    return _knowledgeDataSource.getCommonOperations(packageName);
  }

  // ==================== 初始化和销毁 ====================

  Future<void> initialize() async {
    await _platformDataSource.initialize();
    await _knowledgeDataSource.initialize();
  }

  Future<void> dispose() async {
    await _platformDataSource.dispose();
    await _knowledgeDataSource.dispose();
  }
}
