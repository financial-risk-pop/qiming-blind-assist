import 'package:equatable/equatable.dart';

import 'app_info.dart';
import 'screen_element.dart';

/// 屏幕解读结果 - 包含当前屏幕的完整分析
class ScreenReadResult extends Equatable {
  /// 当前App信息
  final AppInfo appInfo;

  /// 页面概要描述
  final String pageSummary;

  /// 所有UI元素列表
  final List<ScreenElement> elements;

  /// 可交互元素数量
  final int interactiveElementCount;

  /// 操作提示列表
  final List<InteractionHint> hints;

  /// AI增强描述（来自云端大模型）
  final String? aiEnhancedDescription;

  /// 数据来源标记
  final ScreenReadSource source;

  /// 解读时间戳
  final DateTime timestamp;

  const ScreenReadResult({
    required this.appInfo,
    required this.pageSummary,
    required this.elements,
    required this.interactiveElementCount,
    this.hints = const [],
    this.aiEnhancedDescription,
    required this.source,
    required this.timestamp,
  });

  /// 获取需要AI补充描述的元素
  List<ScreenElement> get elementsNeedingAi {
    return elements.where((e) => e.needsAiDescription).toList();
  }

  /// 生成完整的语音播报文本
  String toFullSpeechText() {
    final buffer = StringBuffer();
    buffer.writeln(appInfo.toSpeechText());
    buffer.writeln(pageSummary);
    if (interactiveElementCount > 0) {
      buffer.writeln('共有$interactiveElementCount个可操作的元素');
    }
    if (hints.isNotEmpty) {
      buffer.writeln('操作提示：${hints.first.text}');
    }
    return buffer.toString();
  }

  /// 生成简要播报文本
  String toBriefSpeechText() {
    return '${appInfo.appName}，$pageSummary';
  }

  @override
  List<Object?> get props => [appInfo, pageSummary, timestamp];
}

/// 操作提示
class InteractionHint {
  /// 提示文本
  final String text;

  /// 相关元素ID（如果关联某个特定元素）
  final String? elementId;

  /// 提示类型
  final HintType type;

  const InteractionHint({
    required this.text,
    this.elementId,
    required this.type,
  });
}

/// 提示类型
enum HintType {
  tap('点击操作'),
  scroll('滚动操作'),
  input('输入操作'),
  navigation('页面导航'),
  shortcut('快捷操作');

  final String label;
  const HintType(this.label);
}

/// 解读数据来源
enum ScreenReadSource {
  /// 仅来自无障碍API
  accessibilityApi,
  /// 仅来自AI视觉分析
  aiVision,
  /// 两者融合
  merged,
  /// 来自缓存
  cached,
}

/// 屏幕变化事件
class ScreenChangeEvent {
  /// 变化类型
  final ScreenChangeType type;

  /// 新App信息（App切换时）
  final AppInfo? newAppInfo;

  /// 变化描述
  final String? description;

  /// 时间戳
  final DateTime timestamp;

  const ScreenChangeEvent({
    required this.type,
    this.newAppInfo,
    this.description,
    required this.timestamp,
  });
}

/// 屏幕变化类型
enum ScreenChangeType {
  /// App/窗口切换
  appSwitch,
  /// 页面切换（同一App内）
  pageChange,
  /// 内容更新（同一页面内容变化）
  contentUpdate,
  /// 对话框弹出
  dialogShown,
  /// 对话框关闭
  dialogDismissed,
  /// 通知出现
  notification,
}
