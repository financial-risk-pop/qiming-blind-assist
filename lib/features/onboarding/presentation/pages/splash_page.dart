import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../shared/theme/app_theme.dart';

/// 启动决策页
///
/// 决定是去权限引导页还是直接去主页：
/// - 首次启动（Hive 标记不存在）→ 引导页
/// - 必需权限有缺失 → 引导页
/// - 否则 → 主页
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _decide();
    });
  }

  Future<void> _decide() async {
    bool onboarded = false;
    try {
      final box = await Hive.openBox('app_state');
      onboarded = box.get('permission_onboarded', defaultValue: false) == true;
    } catch (_) {}

    // 检查必需权限是否齐全
    bool allRequiredGranted = true;
    try {
      final required = [
        Permission.camera,
        Permission.microphone,
        Permission.location,
      ];
      for (final p in required) {
        final s = await p.status;
        if (!s.isGranted) {
          allRequiredGranted = false;
          break;
        }
      }
    } catch (_) {
      allRequiredGranted = false;
    }

    if (!mounted) return;

    // 至少展示 800ms 启动动画
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    if (!onboarded || !allRequiredGranted) {
      context.go('/onboarding');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 72,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '启明',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '愿你眼中有光',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 64),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
