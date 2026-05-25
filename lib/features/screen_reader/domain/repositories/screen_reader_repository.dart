import 'dart:typed_data';
import 'dart:ui';

import '../entities/app_info.dart';
import '../entities/screen_element.dart';
import '../entities/screen_read_result.dart';

/// App内容解读仓库接口
/// 
/// 核心职责：
/// 1. 通过无障碍API获取屏幕UI元素树（路径1）
/// 2. 通过截图+AI进行视觉理解（路径2）
/// 3. 融合两路数据生成完整的解读结果
/// 4. 管理解读结果缓存
/// 5. 监听屏幕变化事件
abstract class ScreenReaderRepository {
  /// 获取当前屏幕的完整解读
  /// 
  /// 流程：
  /// 1. 调用无障碍API获取UI节点树
  /// 2. 检查是否有元素缺失描述
  /// 3. 如需要，触发AI视觉分析补充
  /// 4. 融合结果并返回
  Future<ScreenReadResult> readCurrentScreen();

  /// 获取当前App的基本信息
  Future<AppInfo> getCurrentAppInfo();

  /// 获取指定屏幕位置的元素详情（用户触摸时）
  Future<ScreenElement?> readElementAt(Offset position);

  /// 在当前页面搜索指定功能/元素
  /// [query] 搜索关键词（如"付款"、"设置"、"搜索框"）
  Future<List<ScreenElement>> findElements(String query);

  /// AI增强解读 — 对屏幕截图调用大模型分析
  /// [screenshot] 屏幕截图数据
  Future<String> getAiEnhancedDescription(Uint8List screenshot);

  /// 执行操作（点击/滑动指定元素）
  /// [elementId] 目标元素ID
  /// [action] 操作类型
  Future<bool> performAction(String elementId, AccessibilityAction action);

  /// 屏幕变化事件流（监听App切换、页面变化等）
  Stream<ScreenChangeEvent> get screenChangeStream;

  /// 检查无障碍服务是否已开启
  Future<bool> isAccessibilityServiceEnabled();

  /// 引导用户开启无障碍服务
  Future<void> requestAccessibilityService();
}

/// 无障碍操作类型
enum AccessibilityAction {
  click('点击'),
  longClick('长按'),
  scrollForward('向下滚动'),
  scrollBackward('向上滚动'),
  focus('获取焦点'),
  clearFocus('清除焦点'),
  setText('设置文本'),
  copy('复制'),
  paste('粘贴');

  final String label;
  const AccessibilityAction(this.label);
}
