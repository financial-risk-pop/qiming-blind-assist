import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../utils/logger.dart';
import '../../features/debug/presentation/pages/debug_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/navigation/presentation/pages/navigation_page.dart';
import '../../features/obstacle_detection/presentation/pages/obstacle_detection_page.dart';
import '../../features/ocr_recognition/presentation/pages/ocr_page.dart';
import '../../features/onboarding/presentation/pages/permission_onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/recognize/presentation/pages/recognize_channel_page.dart';
import '../../features/screen_reader/presentation/pages/screen_reader_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../shared/theme/app_theme.dart';

/// 路由配置 Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    errorBuilder: (context, state) {
      AppLogger.error(
        '路由错误: ${state.uri} - ${state.error}',
        tag: 'Router',
        error: state.error,
      );
      return _ErrorPage(message: state.error?.toString() ?? '页面不存在');
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (c, s) => _safe(() => const SplashPage(), '启动页'),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (c, s) =>
            _safe(() => const PermissionOnboardingPage(), '权限引导'),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (c, s) => _safe(() => const HomePage(), '主页'),
      ),
      GoRoute(
        path: '/navigation',
        name: 'navigation',
        builder: (c, s) => _safe(() => const NavigationPage(), '语音导航'),
      ),
      GoRoute(
        path: '/obstacle-detection',
        name: 'obstacle_detection',
        builder: (c, s) => _safe(() => const ObstacleDetailPage(), '障碍检测'),
      ),
      GoRoute(
        path: '/ocr',
        name: 'ocr',
        builder: (c, s) => _safe(() => const OcrPage(), '文字识别'),
      ),
      GoRoute(
        path: '/screen-reader',
        name: 'screen_reader',
        builder: (c, s) => _safe(() => const ScreenReaderPage(), '应用解读'),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (c, s) => _safe(() => const SettingsPage(), '设置'),
      ),
      GoRoute(
        path: '/debug',
        name: 'debug',
        builder: (c, s) => _safe(() => const DebugPage(), '系统诊断'),
      ),
      // 识别频道
      GoRoute(
        path: '/recognize/money',
        builder: (c, s) => _safe(
            () => const RecognizeChannelPage(type: ChannelType.money),
            '识别钞票'),
      ),
      GoRoute(
        path: '/recognize/color',
        builder: (c, s) => _safe(
            () => const RecognizeChannelPage(type: ChannelType.color),
            '识别颜色'),
      ),
      GoRoute(
        path: '/recognize/light',
        builder: (c, s) => _safe(
            () => const RecognizeChannelPage(type: ChannelType.light),
            '识别光线'),
      ),
      GoRoute(
        path: '/recognize/scene',
        builder: (c, s) => _safe(
            () => const RecognizeChannelPage(type: ChannelType.scene),
            '识别场景'),
      ),
    ],
  );
});

Widget _safe(Widget Function() builder, String pageName) {
  try {
    return builder();
  } catch (e, st) {
    AppLogger.error(
      '$pageName 页面构建失败',
      tag: 'Router',
      error: e,
      stackTrace: st,
    );
    return _ErrorPage(message: '$pageName 加载失败：$e');
  }
}

class _ErrorPage extends StatelessWidget {
  final String message;
  const _ErrorPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('启明')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warning, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  '页面暂时无法打开',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回主页'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
