import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/utils/logger.dart';

/// 应用入口
void main() async {
  // 关键：全局错误捕获
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(
      '⚠️ Flutter 异常: ${details.exceptionAsString()}',
      tag: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // 自定义错误显示（在 main 一开始就设置，避免 build 时反复设置）
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.orange, size: 80),
                const SizedBox(height: 24),
                const Text(
                  '页面出现问题',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  details.exceptionAsString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  '请按返回键回到主页重试',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  try {
    // 锁定竖屏
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 高对比度状态栏
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    // Hive 本地存储
    await Hive.initFlutter();

    AppLogger.info('应用初始化完成', tag: 'Main');
  } catch (e, st) {
    AppLogger.error('初始化异常（已忽略）',
        tag: 'Main', error: e, stackTrace: st);
  }

  runApp(
    const ProviderScope(
      child: BlindAssistApp(),
    ),
  );
}
