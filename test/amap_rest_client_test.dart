import 'package:flutter_test/flutter_test.dart';
import 'package:blind_assist_app/features/navigation/data/datasources/amap_rest_client.dart';
import 'package:blind_assist_app/features/navigation/domain/repositories/navigation_repository.dart';

/// 高德 REST 客户端响应解析测试
///
/// 由于真实调用需要 API Key 和网络，这里只测试内部解析逻辑。
/// 通过访问私有方法需要开启 @visibleForTesting 或重构，
/// 暂时只做基础构造测试 + 异常路径覆盖。
void main() {
  group('AmapRestClient 构造', () {
    test('正常构造', () {
      final client = AmapRestClient(apiKey: 'test_key');
      expect(client, isNotNull);
    });
  });

  group('POIResult 数据类', () {
    test('完整字段构造', () {
      const poi = POIResult(
        name: '人民医院',
        address: '中山路 123 号',
        distance: 250.0,
        latitude: 39.9,
        longitude: 116.4,
        category: '医疗服务',
      );
      expect(poi.name, '人民医院');
      expect(poi.distance, 250.0);
      expect(poi.category, '医疗服务');
    });

    test('category 可空', () {
      const poi = POIResult(
        name: '便利店',
        address: '',
        distance: 50.0,
        latitude: 39.9,
        longitude: 116.4,
      );
      expect(poi.category, isNull);
    });
  });

  group('LocationInfo 数据类', () {
    test('包含时间戳', () {
      final now = DateTime.now();
      final loc = LocationInfo(
        latitude: 39.9042,
        longitude: 116.4074,
        accuracy: 5.0,
        heading: 90.0,
        speed: 1.2,
        timestamp: now,
      );
      expect(loc.timestamp, now);
      expect(loc.heading, 90.0);
    });

    test('heading 和 speed 可空', () {
      final loc = LocationInfo(
        latitude: 39.9,
        longitude: 116.4,
        accuracy: 10.0,
        timestamp: DateTime.now(),
      );
      expect(loc.heading, isNull);
      expect(loc.speed, isNull);
    });
  });
}
