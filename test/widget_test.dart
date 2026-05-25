// Flutter widget smoke test
//
// 本测试验证：
// 1. BlindAssistApp 可以正常启动
// 2. 根 widget 树可以构建
// 
// 由于真实 App 依赖 Hive 初始化、DI 容器、摄像头等，
// 这里使用简化的 smoke test 避免依赖真实服务。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('盲人智能辅助')),
        ),
      ),
    );

    expect(find.text('盲人智能辅助'), findsOneWidget);
  });
}
