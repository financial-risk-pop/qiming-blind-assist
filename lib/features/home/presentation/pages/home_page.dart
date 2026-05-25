import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/logger.dart';
import '../../../../shared/theme/app_theme.dart';

/// 启明主页 - 仿 Seeing AI / 豆芽看见的极简风格
///
/// 设计：
/// 1. 顶部品牌区（Logo + slogan + 右上角设置）
/// 2. "今天，启明能为你做什么？"引导文案
/// 3. 4 个核心功能卡片（大、显眼）
/// 4. 4 个识别频道小卡片（次要功能）
/// 5. 底部"按住右下角浮按钮快速识别"提示
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // 权限请求已迁移到独立的引导页 PermissionOnboardingPage
  // 主页不再自动请求权限，避免和引导页冲突

  @override
  void initState() {
    super.initState();
    // 延迟播报欢迎语
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      try {
        const channel = MethodChannel('com.blindassist/tts');
        channel.invokeMethod('speak', {'text': '欢迎使用启明'});
      } catch (_) {}
    });
  }

  void _go(BuildContext context, String route, String name) {
    HapticFeedback.mediumImpact();
    AppLogger.info('点击 $name → $route', tag: 'Home');
    try {
      context.push(route);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开 $name 失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 顶部 - 品牌 + 设置入口
            SliverToBoxAdapter(child: _buildHeader(context)),

            // Slogan 区
            SliverToBoxAdapter(child: _buildIntro(context)),

            // 4 个核心功能（2x2 大卡片）
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildListDelegate([
                  _PrimaryCard(
                    icon: Icons.navigation_rounded,
                    label: '语音导航',
                    sub: '说出目的地',
                    color: AppTheme.channelNavi,
                    onTap: () => _go(context, '/navigation', '语音导航'),
                  ),
                  _PrimaryCard(
                    icon: Icons.visibility_rounded,
                    label: '障碍检测',
                    sub: '识别前方障碍',
                    color: AppTheme.channelObstacle,
                    onTap: () => _go(context, '/obstacle-detection', '障碍检测'),
                  ),
                  _PrimaryCard(
                    icon: Icons.text_snippet_rounded,
                    label: '文字识别',
                    sub: '拍照朗读文字',
                    color: AppTheme.channelText,
                    onTap: () => _go(context, '/ocr', '文字识别'),
                  ),
                  _PrimaryCard(
                    icon: Icons.smart_toy_rounded,
                    label: '应用解读',
                    sub: '智能解读应用',
                    color: AppTheme.channelScreen,
                    onTap: () => _go(context, '/screen-reader', '应用解读'),
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 「更多识别」标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(
                  children: [
                    Text('更多识别',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('NEW',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent)),
                    ),
                  ],
                ),
              ),
            ),

            // 识别频道（4 个，列表卡片）
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ChannelTile(
                    icon: Icons.payments_rounded,
                    title: '识别钞票',
                    sub: '拍一下识别现金面值（人民币）',
                    color: AppTheme.channelMoney,
                    onTap: () => _go(context, '/recognize/money', '识别钞票'),
                  ),
                  const SizedBox(height: 10),
                  _ChannelTile(
                    icon: Icons.color_lens_rounded,
                    title: '识别颜色',
                    sub: '识别衣物或物品的颜色',
                    color: AppTheme.channelColor,
                    onTap: () => _go(context, '/recognize/color', '识别颜色'),
                  ),
                  const SizedBox(height: 10),
                  _ChannelTile(
                    icon: Icons.wb_sunny_rounded,
                    title: '识别光线',
                    sub: '判断当前环境光线明暗',
                    color: AppTheme.channelLight,
                    onTap: () => _go(context, '/recognize/light', '识别光线'),
                  ),
                  const SizedBox(height: 10),
                  _ChannelTile(
                    icon: Icons.image_search_rounded,
                    title: '识别场景',
                    sub: 'AI 描述眼前的场景（需联网）',
                    color: AppTheme.channelScene,
                    onTap: () => _go(context, '/recognize/scene', '识别场景'),
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // 底部小提示卡片
            SliverToBoxAdapter(child: _buildTip(context)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  /// 顶部品牌头
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          // Logo - 一颗启明星
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          // 品牌名
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('启明',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Text('愿你眼中有光',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.0)),
            ],
          ),
          const Spacer(),
          // 诊断按钮
          _CircleIconButton(
            icon: Icons.bug_report_outlined,
            tooltip: '系统诊断',
            onTap: () => _go(context, '/debug', '系统诊断'),
          ),
          const SizedBox(width: 8),
          // 权限管理按钮
          _CircleIconButton(
            icon: Icons.shield_outlined,
            tooltip: '权限管理',
            onTap: () => _go(context, '/onboarding', '权限管理'),
          ),
          const SizedBox(width: 8),
          // 设置按钮
          _CircleIconButton(
            icon: Icons.settings_rounded,
            tooltip: '设置',
            onTap: () => _go(context, '/settings', '设置'),
          ),
        ],
      ),
    );
  }

  /// Slogan 引导
  Widget _buildIntro(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '你好',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '今天我能为你做什么？',
            style: Theme.of(context).textTheme.displayMedium,
          ),
        ],
      ),
    );
  }

  /// 底部提示
  Widget _buildTip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lightbulb_rounded,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('小提示',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                  const SizedBox(height: 2),
                  Text(
                    '所有识别都在手机本地处理，保护你的隐私',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主功能大卡片
class _PrimaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label，$sub',
      button: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: color.withOpacity(0.12),
          highlightColor: color.withOpacity(0.06),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontSize: 19)),
                    const SizedBox(height: 3),
                    Text(sub,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 频道列表卡片
class _ChannelTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title，$sub',
      button: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: color.withOpacity(0.12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(sub,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆形图标按钮
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.divider),
            ),
            child: Icon(icon, color: AppTheme.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}
