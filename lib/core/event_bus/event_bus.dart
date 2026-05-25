import 'dart:async';
import 'package:rxdart/rxdart.dart';

/// 全局事件总线 - 跨模块通信的核心枢纽
/// 
/// 所有模块通过事件总线进行解耦通信：
/// - 障碍物检测模块 → 发出障碍物告警事件
/// - 导航模块 → 发出导航指令事件
/// - OCR模块 → 发出识别结果事件
/// - App解读模块 → 发出解读结果事件
/// - 语音模块 → 监听所有事件，按优先级播报
class EventBus {
  // 使用RxDart的PublishSubject支持多播
  final _eventController = PublishSubject<AppEvent>();

  /// 发送事件
  void fire(AppEvent event) {
    _eventController.add(event);
  }

  /// 监听特定类型的事件
  Stream<T> on<T extends AppEvent>() {
    return _eventController.stream.whereType<T>();
  }

  /// 监听所有事件
  Stream<AppEvent> get allEvents => _eventController.stream;

  /// 释放资源
  void dispose() {
    _eventController.close();
  }
}

// =============================================
// 基础事件定义
// =============================================

/// 所有事件的基类
abstract class AppEvent {
  final DateTime timestamp;
  final String sourceModule;

  AppEvent({
    DateTime? timestamp,
    required this.sourceModule,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 播报优先级
enum FeedbackPriority {
  /// 紧急障碍物警报（立即打断当前播报）
  critical,
  /// 导航指令（排队等待）
  navigation,
  /// 一般信息反馈（排队等待）
  information,
}

// =============================================
// 语音播报请求事件（所有模块共用）
// =============================================

/// 语音播报请求事件
class SpeakRequestEvent extends AppEvent {
  /// 播报内容
  final String text;

  /// 播报优先级
  final FeedbackPriority priority;

  /// 是否打断当前播报
  final bool interruptCurrent;

  SpeakRequestEvent({
    required this.text,
    this.priority = FeedbackPriority.information,
    this.interruptCurrent = false,
    required super.sourceModule,
  });
}

// =============================================
// 障碍物检测事件
// =============================================

/// 障碍物告警事件
class ObstacleAlertEvent extends AppEvent {
  final List<ObstacleInfo> obstacles;
  final FeedbackPriority priority;

  ObstacleAlertEvent({
    required this.obstacles,
    required this.priority,
  }) : super(sourceModule: 'obstacle_detection');
}

/// 障碍物简要信息（事件传输用）
class ObstacleInfo {
  final String type;
  final double distance;
  final String direction;
  final double confidence;

  const ObstacleInfo({
    required this.type,
    required this.distance,
    required this.direction,
    required this.confidence,
  });
}

// =============================================
// 导航事件
// =============================================

/// 导航指令事件
class NavigationEvent extends AppEvent {
  final String instruction;
  final double? distanceToNext;
  final bool isDeviationAlert;

  NavigationEvent({
    required this.instruction,
    this.distanceToNext,
    this.isDeviationAlert = false,
  }) : super(sourceModule: 'navigation');
}

// =============================================
// OCR事件
// =============================================

/// OCR识别结果事件
class OcrResultEvent extends AppEvent {
  final String recognizedText;
  final double confidence;
  final String source; // 'device' or 'cloud'

  OcrResultEvent({
    required this.recognizedText,
    required this.confidence,
    required this.source,
  }) : super(sourceModule: 'ocr');
}

// =============================================
// App解读事件
// =============================================

/// App解读结果事件
class ScreenReadEvent extends AppEvent {
  final String description;
  final String appName;
  final String requestType; // 'summary', 'detail', 'element'

  ScreenReadEvent({
    required this.description,
    required this.appName,
    required this.requestType,
  }) : super(sourceModule: 'screen_reader');
}

/// 屏幕变化通知事件
class ScreenChangedEvent extends AppEvent {
  final String changeType; // 'app_switch', 'page_change', 'content_update'
  final String? newAppName;
  final String? changeDescription;

  ScreenChangedEvent({
    required this.changeType,
    this.newAppName,
    this.changeDescription,
  }) : super(sourceModule: 'screen_reader');
}
