import 'package:flutter_test/flutter_test.dart';
import 'package:blind_assist_app/core/event_bus/event_bus.dart';

/// 事件总线核心行为测试
///
/// 覆盖：
/// - 事件发送与订阅
/// - 按类型过滤
/// - 多订阅者广播
/// - 资源释放
void main() {
  late EventBus bus;

  setUp(() {
    bus = EventBus();
  });

  tearDown(() {
    bus.dispose();
  });

  group('EventBus 基础订阅', () {
    test('订阅者能收到 fire 的事件', () async {
      final received = <SpeakRequestEvent>[];
      bus.on<SpeakRequestEvent>().listen(received.add);

      bus.fire(SpeakRequestEvent(
        text: 'hello',
        sourceModule: 'test',
      ));

      // 异步事件，等一小段时间让 stream 交付
      await Future.delayed(const Duration(milliseconds: 10));

      expect(received, hasLength(1));
      expect(received.first.text, 'hello');
    });

    test('按类型过滤：只收到匹配类型', () async {
      final speaks = <SpeakRequestEvent>[];
      final navs = <NavigationEvent>[];

      bus.on<SpeakRequestEvent>().listen(speaks.add);
      bus.on<NavigationEvent>().listen(navs.add);

      bus.fire(SpeakRequestEvent(text: 'a', sourceModule: 'x'));
      bus.fire(NavigationEvent(instruction: '左转', distanceToNext: 10));
      bus.fire(SpeakRequestEvent(text: 'b', sourceModule: 'x'));

      await Future.delayed(const Duration(milliseconds: 10));

      expect(speaks, hasLength(2));
      expect(navs, hasLength(1));
    });

    test('多订阅者广播：每个订阅者都收到', () async {
      final a = <AppEvent>[];
      final b = <AppEvent>[];
      bus.on<SpeakRequestEvent>().listen(a.add);
      bus.on<SpeakRequestEvent>().listen(b.add);

      bus.fire(SpeakRequestEvent(text: 'x', sourceModule: 't'));

      await Future.delayed(const Duration(milliseconds: 10));

      expect(a, hasLength(1));
      expect(b, hasLength(1));
    });

    test('allEvents 收到所有类型', () async {
      final all = <AppEvent>[];
      bus.allEvents.listen(all.add);

      bus.fire(SpeakRequestEvent(text: 'x', sourceModule: 't'));
      bus.fire(NavigationEvent(instruction: 'y', distanceToNext: 5));
      bus.fire(OcrResultEvent(
        recognizedText: 'z',
        confidence: 0.9,
        source: 'device',
      ));

      await Future.delayed(const Duration(milliseconds: 10));

      expect(all, hasLength(3));
    });
  });

  group('SpeakRequestEvent', () {
    test('默认优先级为 information', () {
      final e = SpeakRequestEvent(text: 'x', sourceModule: 't');
      expect(e.priority, FeedbackPriority.information);
      expect(e.interruptCurrent, false);
    });

    test('critical 优先级可配置打断', () {
      final e = SpeakRequestEvent(
        text: 'urgent',
        priority: FeedbackPriority.critical,
        interruptCurrent: true,
        sourceModule: 'obstacle',
      );
      expect(e.priority, FeedbackPriority.critical);
      expect(e.interruptCurrent, true);
    });
  });

  group('FeedbackPriority 枚举', () {
    test('优先级顺序：critical > navigation > information', () {
      expect(FeedbackPriority.values.length, 3);
      // 只确保所有枚举值存在即可
      expect(FeedbackPriority.critical.index, 0);
      expect(FeedbackPriority.navigation.index, 1);
      expect(FeedbackPriority.information.index, 2);
    });
  });
}
