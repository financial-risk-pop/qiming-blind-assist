import 'dart:ui';
import 'package:equatable/equatable.dart';

/// 屏幕元素实体 - 表示App界面上的一个UI元素
class ScreenElement extends Equatable {
  /// 元素唯一标识
  final String id;

  /// 元素类型
  final ScreenElementType type;

  /// 元素文本（如有）
  final String? text;

  /// 无障碍描述（系统提供的content description）
  final String? contentDescription;

  /// AI增强描述（由大模型补充的描述）
  final String? aiDescription;

  /// 在屏幕上的位置和大小
  final Rect bounds;

  /// 是否可点击
  final bool isClickable;

  /// 是否可滚动
  final bool isScrollable;

  /// 是否获得焦点
  final bool isFocused;

  /// 是否可见
  final bool isVisible;

  /// 是否已选中（复选框、单选按钮等）
  final bool? isChecked;

  /// 子元素
  final List<ScreenElement> children;

  /// 在父容器中的索引（用于定位描述）
  final int? indexInParent;

  const ScreenElement({
    required this.id,
    required this.type,
    this.text,
    this.contentDescription,
    this.aiDescription,
    required this.bounds,
    this.isClickable = false,
    this.isScrollable = false,
    this.isFocused = false,
    this.isVisible = true,
    this.isChecked,
    this.children = const [],
    this.indexInParent,
  });

  /// 获取最佳描述文本（优先级：AI描述 > 无障碍描述 > 元素文本 > 类型描述）
  String get bestDescription {
    if (aiDescription != null && aiDescription!.isNotEmpty) return aiDescription!;
    if (contentDescription != null && contentDescription!.isNotEmpty) return contentDescription!;
    if (text != null && text!.isNotEmpty) return text!;
    return type.label;
  }

  /// 是否需要AI补充描述（没有文字也没有无障碍描述的元素）
  bool get needsAiDescription {
    return (text == null || text!.isEmpty) &&
        (contentDescription == null || contentDescription!.isEmpty);
  }

  /// 生成语音播报文本
  String toSpeechText() {
    final buffer = StringBuffer();
    buffer.write(bestDescription);
    if (isClickable) buffer.write('，可点击');
    if (isScrollable) buffer.write('，可滚动');
    if (isChecked != null) {
      buffer.write(isChecked! ? '，已选中' : '，未选中');
    }
    return buffer.toString();
  }

  @override
  List<Object?> get props => [id, type, text, bounds];
}

/// 屏幕元素类型
enum ScreenElementType {
  button('按钮'),
  textField('输入框'),
  text('文本'),
  image('图片'),
  icon('图标'),
  listItem('列表项'),
  checkbox('复选框'),
  radioButton('单选按钮'),
  switchWidget('开关'),
  slider('滑块'),
  tab('标签页'),
  navigationBar('导航栏'),
  toolbar('工具栏'),
  dialog('对话框'),
  scrollable('可滚动区域'),
  container('容器'),
  unknown('未知元素');

  final String label;
  const ScreenElementType(this.label);
}
