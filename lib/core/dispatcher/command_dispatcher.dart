import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/voice_interaction/domain/entities/voice_command.dart';
import '../../features/voice_interaction/presentation/providers/voice_provider.dart';
import '../../features/obstacle_detection/presentation/providers/detection_provider.dart';
import '../../features/navigation/presentation/providers/navigation_provider.dart';
import '../../features/ocr_recognition/presentation/providers/ocr_provider.dart';
import '../../features/screen_reader/presentation/providers/screen_reader_provider.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import '../router/app_router.dart';
import '../utils/logger.dart';

/// 全局指令调度器
/// 
/// 接收语音模块解析出的VoiceCommand，分发到对应的功能模块执行。
/// 这是所有语音指令的中央路由枢纽。
class CommandDispatcher {
  final Ref _ref;

  CommandDispatcher(this._ref);

  /// 调度指令到对应模块
  Future<void> dispatch(VoiceCommand command) async {
    AppLogger.info(
      '调度指令: ${command.type.name}, 参数: ${command.parameters}',
      tag: 'Dispatcher',
    );

    switch (command.type) {
      // ===== 导航类 =====
      case CommandType.navigate:
        final dest = command.parameters['destination'];
        if (dest != null) {
          await _ref.read(navigationNotifierProvider.notifier).planRoute(dest);
        } else {
          _speak('请告诉我你要去哪里');
        }
        break;

      case CommandType.searchNearby:
        final keyword = command.parameters['keyword'] ?? '附近';
        await _ref.read(navigationNotifierProvider.notifier).searchNearby(keyword);
        break;

      case CommandType.stopNavigation:
        await _ref.read(navigationNotifierProvider.notifier).stopNavigation();
        break;

      case CommandType.currentLocation:
        await _ref.read(navigationNotifierProvider.notifier).refreshLocation();
        final location = _ref.read(navigationNotifierProvider).currentLocation;
        if (location != null) {
          _speak('您当前在北纬${location.latitude.toStringAsFixed(4)}，'
              '东经${location.longitude.toStringAsFixed(4)}附近');
        } else {
          _speak('正在获取位置信息，请稍候');
        }
        break;

      // ===== 障碍检测类 =====
      case CommandType.startDetection:
        await _ref.read(detectionNotifierProvider.notifier).startDetection();
        _speak('障碍物检测已开启');
        break;

      case CommandType.stopDetection:
        await _ref.read(detectionNotifierProvider.notifier).stopDetection();
        _speak('障碍物检测已关闭');
        break;

      case CommandType.queryObstacle:
        final state = _ref.read(detectionNotifierProvider);
        if (state.currentObstacles.isEmpty) {
          _speak('前方暂未检测到障碍物');
        } else {
          final descriptions = state.currentObstacles
              .map((o) => o.toSpeechText())
              .join('，');
          _speak('当前检测到${state.currentObstacles.length}个障碍物：$descriptions');
        }
        break;

      // ===== OCR类 =====
      case CommandType.readText:
        await _ref.read(ocrNotifierProvider.notifier).recognizeFromCamera();
        break;

      case CommandType.startRealTimeOcr:
        await _ref.read(ocrNotifierProvider.notifier).startRealTimeOcr();
        _speak('实时文字识别已开启');
        break;

      case CommandType.stopOcr:
        await _ref.read(ocrNotifierProvider.notifier).stopRealTimeOcr();
        _speak('文字识别已停止');
        break;

      // ===== App解读类 =====
      case CommandType.readScreen:
        await _ref.read(screenReaderNotifierProvider.notifier).readCurrentScreen();
        break;

      case CommandType.readElement:
        // 需要位置信息，暂时触发全局解读
        await _ref.read(screenReaderNotifierProvider.notifier).readCurrentScreen();
        break;

      case CommandType.listButtons:
        await _ref.read(screenReaderNotifierProvider.notifier).findElements('button');
        break;

      case CommandType.performAction:
        final target = command.parameters['target'];
        if (target != null) {
          await _ref.read(screenReaderNotifierProvider.notifier)
              .performAction('click', params: {'target': target});
        }
        break;

      case CommandType.findElement:
        final target = command.parameters['target'];
        if (target != null) {
          await _ref.read(screenReaderNotifierProvider.notifier).findElements(target);
        }
        break;

      // ===== 系统类 =====
      case CommandType.goHome:
        // 通过路由返回主页
        try {
          _ref.read(appRouterProvider).go('/');
        } catch (_) {}
        _speak('已返回主页');
        break;

      case CommandType.goBack:
        try {
          final router = _ref.read(appRouterProvider);
          if (router.canPop()) {
            router.pop();
            _speak('已返回上一页');
          } else {
            _speak('已经在主页了');
          }
        } catch (_) {
          _speak('返回失败');
        }
        break;

      case CommandType.openSettings:
        try {
          _ref.read(appRouterProvider).push('/settings');
        } catch (_) {}
        _speak('正在打开设置');
        break;

      case CommandType.adjustVolume:
        final direction = command.parameters['direction'];
        final currentVolume = _ref.read(settingsNotifierProvider).config.speechVolume;
        final newVolume = direction == 'up'
            ? (currentVolume + 0.1).clamp(0.0, 1.0)
            : (currentVolume - 0.1).clamp(0.0, 1.0);
        await _ref.read(voiceNotifierProvider.notifier).updateVolume(newVolume);
        _speak('音量已调整为${(newVolume * 100).round()}%');
        break;

      case CommandType.adjustSpeed:
        final direction = command.parameters['direction'];
        final currentRate = _ref.read(settingsNotifierProvider).config.speechRate;
        final newRate = direction == 'up'
            ? (currentRate + 0.1).clamp(0.1, 1.0)
            : (currentRate - 0.1).clamp(0.1, 1.0);
        await _ref.read(voiceNotifierProvider.notifier).updateSpeechRate(newRate);
        _speak('语速已调整');
        break;

      case CommandType.repeatLast:
        await _ref.read(voiceNotifierProvider.notifier).repeatLast();
        break;

      case CommandType.help:
        _speak(
          '您可以使用以下功能：'
          '说"导航到某地"开始导航，'
          '说"开始检测"检测障碍物，'
          '说"读一下"识别文字，'
          '说"解读一下"了解屏幕内容，'
          '说"再说一遍"重复播报。'
        );
        break;

      // ===== 未处理的指令（含 unknown、未实现的类型）=====
      default:
        AppLogger.warning(
          '未处理的指令类型: ${command.type.name}',
          tag: 'Dispatcher',
        );
        _speak('抱歉，我还不支持这个功能');
        break;
    }
  }

  /// 便捷播报方法
  void _speak(String text) {
    _ref.read(voiceNotifierProvider.notifier).speak(text, interrupt: true);
  }
}

/// 指令调度器Provider
final commandDispatcherProvider = Provider<CommandDispatcher>((ref) {
  return CommandDispatcher(ref);
});
