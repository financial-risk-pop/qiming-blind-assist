import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'shared/theme/app_theme.dart';

/// 启明 App 根Widget
///
/// MVP 极简版：
/// - 只关心路由和主题
/// - 不再叠加全局浮层（VoiceFloatingButton 移到主页内部，避免 Stack 命中冲突）
/// - 强制亮色主题保证可读性
class BlindAssistApp extends ConsumerWidget {
  const BlindAssistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '启明',
      debugShowCheckedModeBanner: false,

      // 主题 - 启明品牌主题
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,

      routerConfig: router,

      // 国际化
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
