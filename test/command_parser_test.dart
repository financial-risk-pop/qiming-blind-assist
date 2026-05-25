import 'package:flutter_test/flutter_test.dart';
import 'package:blind_assist_app/features/voice_interaction/data/parsers/command_parser.dart';
import 'package:blind_assist_app/features/voice_interaction/domain/entities/voice_command.dart';

void main() {
  late CommandParser parser;

  setUp(() {
    parser = CommandParser();
  });

  group('导航类指令', () {
    test('解析"导航到人民医院"', () {
      final command = parser.parse('导航到人民医院');
      expect(command, isNotNull);
      expect(command!.type, CommandType.navigate);
      expect(command.parameters['destination'], '人民医院');
    });

    test('解析"带我去火车站"', () {
      final command = parser.parse('带我去火车站');
      expect(command, isNotNull);
      expect(command!.type, CommandType.navigate);
      expect(command.parameters['destination'], '火车站');
    });

    test('解析"搜索附近的药店"', () {
      final command = parser.parse('搜索附近的药店');
      expect(command, isNotNull);
      expect(command!.type, CommandType.searchNearby);
    });

    test('解析"停止导航"', () {
      final command = parser.parse('停止导航');
      expect(command, isNotNull);
      expect(command!.type, CommandType.stopNavigation);
    });

    test('解析"我在哪"', () {
      final command = parser.parse('我在哪');
      expect(command, isNotNull);
      expect(command!.type, CommandType.currentLocation);
    });
  });

  group('障碍检测类指令', () {
    test('解析"开始检测"', () {
      final command = parser.parse('开始检测');
      expect(command, isNotNull);
      expect(command!.type, CommandType.startDetection);
    });

    test('解析"前面有什么"', () {
      final command = parser.parse('前面有什么');
      expect(command, isNotNull);
      expect(command!.type, CommandType.queryObstacle);
    });
  });

  group('OCR类指令', () {
    test('解析"帮我看看上面写了什么"', () {
      final command = parser.parse('帮我看看上面写了什么');
      expect(command, isNotNull);
      expect(command!.type, CommandType.readText);
    });
  });

  group('App解读类指令', () {
    test('解析"屏幕上有什么"', () {
      final command = parser.parse('屏幕上有什么');
      expect(command, isNotNull);
      expect(command!.type, CommandType.readScreen);
    });

    test('解析"有哪些按钮"', () {
      final command = parser.parse('有哪些按钮');
      expect(command, isNotNull);
      expect(command!.type, CommandType.listButtons);
    });

    test('解析"帮我点确认"', () {
      final command = parser.parse('帮我点确认');
      expect(command, isNotNull);
      expect(command!.type, CommandType.performAction);
      expect(command.parameters['target'], '确认');
    });
  });

  group('系统类指令', () {
    test('解析"调大音量"', () {
      final command = parser.parse('调大音量');
      expect(command, isNotNull);
      expect(command!.type, CommandType.adjustVolume);
      expect(command.parameters['direction'], 'up');
    });

    test('解析"说慢一点"', () {
      final command = parser.parse('说慢一点');
      expect(command, isNotNull);
      expect(command!.type, CommandType.adjustSpeed);
      expect(command.parameters['direction'], 'down');
    });

    test('解析"再说一遍"', () {
      final command = parser.parse('再说一遍');
      expect(command, isNotNull);
      expect(command!.type, CommandType.repeatLast);
    });

    test('解析"帮助"', () {
      final command = parser.parse('帮助');
      expect(command, isNotNull);
      expect(command!.type, CommandType.help);
    });
  });

  group('无法识别的指令', () {
    test('空字符串返回null', () {
      final command = parser.parse('');
      expect(command, isNull);
    });

    test('无关文本返回null', () {
      final command = parser.parse('今天天气真好');
      expect(command, isNull);
    });
  });
}
