import '../../domain/entities/voice_command.dart';
import '../../../../core/utils/logger.dart';

/// 语音指令解析器
/// 
/// 负责将语音识别文本解析为结构化的VoiceCommand对象。
/// 支持22种指令类型的意图识别。
class CommandParser {
  // 指令模式映射表
  static final List<_CommandPattern> _patterns = [
    // ===== 导航类指令 =====
    _CommandPattern(
      type: CommandType.navigate,
      keywords: ['导航到', '带我去', '我要去', '去往', '前往', '怎么去'],
      extractor: _extractDestination,
    ),
    _CommandPattern(
      type: CommandType.searchNearby,
      keywords: ['附近有', '附近的', '搜索附近', '周围有没有', '找一下附近'],
      extractor: _extractSearchKeyword,
    ),
    _CommandPattern(
      type: CommandType.stopNavigation,
      keywords: ['停止导航', '结束导航', '取消导航', '不导航了'],
    ),
    _CommandPattern(
      type: CommandType.currentLocation,
      keywords: ['我在哪', '当前位置', '现在在哪', '我的位置'],
    ),

    // ===== 障碍检测类指令 =====
    _CommandPattern(
      type: CommandType.startDetection,
      keywords: ['开始检测', '打开检测', '开启障碍检测', '帮我看路', '检测前方'],
    ),
    _CommandPattern(
      type: CommandType.stopDetection,
      keywords: ['停止检测', '关闭检测', '不用检测了'],
    ),
    _CommandPattern(
      type: CommandType.queryObstacle,
      keywords: ['前面有什么', '前方情况', '路况怎样', '有障碍吗'],
    ),

    // ===== OCR类指令 =====
    _CommandPattern(
      type: CommandType.readText,
      keywords: ['读一下', '识别文字', '帮我看看', '上面写了什么', '念一下'],
    ),
    _CommandPattern(
      type: CommandType.startRealTimeOcr,
      keywords: ['实时识别', '连续识别', '持续读取'],
    ),
    _CommandPattern(
      type: CommandType.stopOcr,
      keywords: ['停止识别', '不用读了', '停止阅读'],
    ),

    // ===== App解读类指令 =====
    _CommandPattern(
      type: CommandType.readScreen,
      keywords: ['屏幕上有什么', '当前页面', '解读一下', '读一下屏幕', '帮我看看屏幕'],
    ),
    _CommandPattern(
      type: CommandType.readElement,
      keywords: ['这个是什么', '这个按钮', '帮我看看这个'],
    ),
    _CommandPattern(
      type: CommandType.listButtons,
      keywords: ['有哪些按钮', '列出按钮', '有什么可以点的'],
    ),
    _CommandPattern(
      type: CommandType.performAction,
      keywords: ['帮我点', '点击', '打开', '选择'],
      extractor: _extractActionTarget,
    ),
    _CommandPattern(
      type: CommandType.findElement,
      keywords: ['找到', '哪里有', '搜索'],
      extractor: _extractSearchTarget,
    ),

    // ===== 系统类指令 =====
    _CommandPattern(
      type: CommandType.goHome,
      keywords: ['回到主页', '返回首页', '回首页', '回去', '主页面'],
    ),
    _CommandPattern(
      type: CommandType.goBack,
      keywords: ['返回', '后退', '上一页', '退回去'],
    ),
    _CommandPattern(
      type: CommandType.openSettings,
      keywords: ['打开设置', '设置', '调整设置'],
    ),
    _CommandPattern(
      type: CommandType.adjustVolume,
      keywords: ['调大音量', '调小音量', '音量大一点', '音量小一点', '声音大', '声音小'],
      extractor: _extractVolumeDirection,
    ),
    _CommandPattern(
      type: CommandType.adjustSpeed,
      keywords: ['说快一点', '说慢一点', '快一些', '慢一些', '语速快', '语速慢'],
      extractor: _extractSpeedDirection,
    ),
    _CommandPattern(
      type: CommandType.repeatLast,
      keywords: ['再说一遍', '重复', '没听清', '什么', '你说什么'],
    ),
    _CommandPattern(
      type: CommandType.help,
      keywords: ['帮助', '怎么用', '使用说明', '有什么功能'],
    ),
  ];

  /// 解析语音文本为指令
  VoiceCommand? parse(String text) {
    if (text.trim().isEmpty) return null;

    final normalizedText = text.trim().toLowerCase();
    
    AppLogger.debug('解析语音指令: "$normalizedText"', tag: 'CommandParser');

    for (final pattern in _patterns) {
      for (final keyword in pattern.keywords) {
        if (normalizedText.contains(keyword)) {
          // 提取参数
          Map<String, String>? params;
          if (pattern.extractor != null) {
            params = pattern.extractor!(normalizedText, keyword);
          }

          final command = VoiceCommand(
            type: pattern.type,
            rawText: text,
            confidence: 0.9,
            parameters: params ?? {},
            timestamp: DateTime.now(),
          );

          AppLogger.info(
            '指令解析成功: ${pattern.type.name}, 参数: $params',
            tag: 'CommandParser',
          );

          return command;
        }
      }
    }

    // 未匹配到任何指令
    AppLogger.debug('未匹配到指令模式: "$normalizedText"', tag: 'CommandParser');
    return null;
  }

  // ==================== 参数提取器 ====================

  /// 提取目的地
  static Map<String, String>? _extractDestination(String text, String keyword) {
    final idx = text.indexOf(keyword);
    if (idx >= 0) {
      final destination = text.substring(idx + keyword.length).trim();
      if (destination.isNotEmpty) {
        return {'destination': destination};
      }
    }
    return null;
  }

  /// 提取搜索关键词
  static Map<String, String>? _extractSearchKeyword(String text, String keyword) {
    final idx = text.indexOf(keyword);
    if (idx >= 0) {
      final searchText = text.substring(idx + keyword.length).trim();
      if (searchText.isNotEmpty) {
        return {'keyword': searchText};
      }
    }
    return null;
  }

  /// 提取操作目标
  static Map<String, String>? _extractActionTarget(String text, String keyword) {
    final idx = text.indexOf(keyword);
    if (idx >= 0) {
      final target = text.substring(idx + keyword.length).trim();
      if (target.isNotEmpty) {
        return {'target': target};
      }
    }
    return null;
  }

  /// 提取搜索目标
  static Map<String, String>? _extractSearchTarget(String text, String keyword) {
    final idx = text.indexOf(keyword);
    if (idx >= 0) {
      final target = text.substring(idx + keyword.length).trim();
      if (target.isNotEmpty) {
        return {'target': target};
      }
    }
    return null;
  }

  /// 提取音量调节方向
  static Map<String, String>? _extractVolumeDirection(String text, String _) {
    if (text.contains('大') || text.contains('高')) {
      return {'direction': 'up'};
    } else if (text.contains('小') || text.contains('低')) {
      return {'direction': 'down'};
    }
    return {'direction': 'up'};
  }

  /// 提取语速调节方向
  static Map<String, String>? _extractSpeedDirection(String text, String _) {
    if (text.contains('快')) {
      return {'direction': 'up'};
    } else if (text.contains('慢')) {
      return {'direction': 'down'};
    }
    return {'direction': 'up'};
  }
}

/// 指令模式（内部用）
class _CommandPattern {
  final CommandType type;
  final List<String> keywords;
  final Map<String, String>? Function(String text, String keyword)? extractor;

  const _CommandPattern({
    required this.type,
    required this.keywords,
    this.extractor,
  });
}
