import 'package:equatable/equatable.dart';

/// App信息实体 - 描述当前运行的App
class AppInfo extends Equatable {
  /// App包名（如 com.tencent.mm）
  final String packageName;

  /// App显示名称（如"微信"）
  final String appName;

  /// 当前页面/Activity名称
  final String? currentActivity;

  /// App分类
  final AppCategory? category;

  /// App功能简介
  final String? description;

  /// App图标数据
  final String? iconBase64;

  /// App版本
  final String? version;

  const AppInfo({
    required this.packageName,
    required this.appName,
    this.currentActivity,
    this.category,
    this.description,
    this.iconBase64,
    this.version,
  });

  /// 生成语音播报文本
  String toSpeechText() {
    final buffer = StringBuffer('当前在$appName');
    if (description != null && description!.isNotEmpty) {
      buffer.write('，$description');
    } else if (category != null) {
      buffer.write('，这是一个${category!.label}应用');
    }
    return buffer.toString();
  }

  @override
  List<Object?> get props => [packageName, appName, currentActivity];
}

/// App分类
enum AppCategory {
  social('社交聊天'),
  shopping('购物'),
  payment('支付金融'),
  navigation('地图导航'),
  entertainment('娱乐'),
  news('新闻资讯'),
  tools('工具'),
  education('教育'),
  health('健康医疗'),
  food('餐饮外卖'),
  travel('出行旅游'),
  system('系统应用'),
  unknown('未知分类');

  final String label;
  const AppCategory(this.label);
}
