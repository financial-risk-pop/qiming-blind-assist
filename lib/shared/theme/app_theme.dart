import 'package:flutter/material.dart';

/// 启明 App 主题
///
/// 设计理念：
/// - 主色：深紫蓝（#5E35B1）—— 启明星色
/// - 强调色：温暖橙（#FF6F00）—— 提示和重点动作
/// - 大留白 + 大圆角 + 大字 + 高对比度
/// - 卡片化布局，触摸区域 ≥ 64dp
class AppTheme {
  AppTheme._();

  // ===== 品牌色 =====
  static const Color primary = Color(0xFF5E35B1); // 深紫
  static const Color primaryLight = Color(0xFF9162E4);
  static const Color primaryDark = Color(0xFF280680);

  static const Color accent = Color(0xFFFF6F00); // 暖橙
  static const Color accentLight = Color(0xFFFFA040);

  static const Color success = Color(0xFF2E7D32); // 绿
  static const Color warning = Color(0xFFF57C00); // 黄
  static const Color danger = Color(0xFFC62828); // 红

  // ===== 中性色 =====
  static const Color background = Color(0xFFF5F4F8); // 暖灰底
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E); // 深蓝黑
  static const Color textSecondary = Color(0xFF5C5C6E);
  static const Color divider = Color(0xFFE5E5EC);

  // ===== 频道色（每个识别功能一个色） =====
  static const Color channelText = Color(0xFF1565C0); // 蓝-文字
  static const Color channelObstacle = Color(0xFFC62828); // 红-障碍
  static const Color channelNavi = Color(0xFF00897B); // 青-导航
  static const Color channelScreen = Color(0xFF6A1B9A); // 紫-应用解读
  static const Color channelMoney = Color(0xFF2E7D32); // 绿-钞票
  static const Color channelColor = Color(0xFFE91E63); // 粉-颜色
  static const Color channelLight = Color(0xFFFBC02D); // 黄-光线
  static const Color channelScene = Color(0xFF5E35B1); // 紫-场景

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: danger,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'sans-serif',
    );

    return base.copyWith(
      // 文字
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5),
        displayMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3),
        displaySmall: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
        titleMedium: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.normal,
            color: textPrimary,
            height: 1.5),
        bodyMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.normal,
            color: textSecondary,
            height: 1.5),
        labelLarge: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
      ),

      // AppBar - 透明 + 大字
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 28),
      ),

      // 按钮 - 大圆角 + 大触摸
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          side: const BorderSide(color: primary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // 卡片
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: divider, width: 1),
        ),
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        subtitleTextStyle:
            TextStyle(fontSize: 15, color: textSecondary, height: 1.4),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return primary;
          return divider;
        }),
      ),

      // 滑块
      sliderTheme: const SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: divider,
        thumbColor: primary,
        trackHeight: 6,
      ),

      // 分割
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 0,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
