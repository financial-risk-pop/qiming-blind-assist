import 'package:equatable/equatable.dart';

/// 语音指令实体
class VoiceCommand extends Equatable {
  /// 指令类型
  final CommandType type;

  /// 指令参数
  final Map<String, dynamic> parameters;

  /// 识别置信度
  final double confidence;

  /// 原始文本
  final String rawText;

  /// 识别时间
  final DateTime? timestamp;

  const VoiceCommand({
    required this.type,
    this.parameters = const {},
    this.confidence = 1.0,
    required this.rawText,
    this.timestamp,
  });

  /// 兼容旧代码的别名：params => parameters
  Map<String, dynamic> get params => parameters;

  @override
  List<Object?> get props => [type, rawText, timestamp, parameters];
}

/// 指令类型枚举
enum CommandType {
  // ===== 导航类 =====
  navigate('导航'),
  stopNavigation('停止导航'),
  searchNearby('搜索附近'),
  currentLocation('当前位置'),

  // ===== 障碍检测类 =====
  startDetection('开始检测'),
  stopDetection('停止检测'),
  queryObstacle('查询障碍'),
  whatIsAhead('前方有什么'),

  // ===== OCR类 =====
  readText('读文字'),
  readSign('读牌子'),
  startRealTimeOcr('实时识别'),
  stopOcr('停止识别'),

  // ===== App解读类 =====
  whatApp('在哪个App'),
  whatOnScreen('屏幕有什么'),
  readScreen('读取屏幕'),
  readElement('读取元素'),
  listButtons('列出按钮'),
  performAction('执行操作'),
  findElement('查找元素'),
  clickElement('点击'),
  describeElement('描述这个'),
  howTo('怎么操作'),

  // ===== 系统类 =====
  help('帮助'),
  settings('设置'),
  openSettings('打开设置'),
  cancel('取消'),
  confirm('确认'),
  goHome('回到首页'),
  goBack('返回'),
  adjustVolume('调节音量'),
  adjustSpeed('调节语速'),
  repeatLast('重复上一次'),

  // ===== 未识别 =====
  unknown('未识别');

  final String label;
  const CommandType(this.label);
}

/// 语音交互状态
enum VoiceState {
  /// 空闲状态
  idle,
  /// 等待唤醒词
  wakeListening,
  /// 正在监听指令
  commandListening,
  /// 处理指令中
  processing,
  /// 正在语音播报
  speaking,
  /// 错误状态
  error,
}
