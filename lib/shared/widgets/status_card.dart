import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// 错误状态卡片 - 用于摄像头/麦克风/网络初始化失败时
///
/// 提供清晰的错误描述 + 可选的"重试"和"打开设置"按钮
class StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? detail;
  final Color? iconColor;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;
  final List<Widget> extraActions;

  const StatusCard({
    super.key,
    this.icon = Icons.info_outline_rounded,
    required this.title,
    required this.description,
    this.detail,
    this.iconColor,
    this.onRetry,
    this.onOpenSettings,
    this.extraActions = const [],
  });

  /// 加载中状态
  factory StatusCard.loading({
    String title = '准备中',
    String description = '正在初始化…',
  }) =>
      StatusCard(
        icon: Icons.hourglass_top_rounded,
        title: title,
        description: description,
        iconColor: AppTheme.primary,
      );

  /// 权限缺失状态
  factory StatusCard.noPermission({
    required String permName,
    required VoidCallback onRetry,
    required VoidCallback onOpenSettings,
  }) =>
      StatusCard(
        icon: Icons.lock_outline_rounded,
        title: '需要$permName权限',
        description: '为了使用这个功能，需要先开启$permName权限',
        iconColor: AppTheme.warning,
        onRetry: onRetry,
        onOpenSettings: onOpenSettings,
      );

  /// 超时状态
  factory StatusCard.timeout({
    required String name,
    required VoidCallback onRetry,
  }) =>
      StatusCard(
        icon: Icons.timer_outlined,
        title: '$name启动超时',
        description: '可能被其他 App 占用，请关闭其他相关 App 后重试',
        iconColor: AppTheme.warning,
        onRetry: onRetry,
      );

  /// 通用错误
  factory StatusCard.error({
    required String title,
    required String description,
    String? detail,
    VoidCallback? onRetry,
    VoidCallback? onOpenSettings,
  }) =>
      StatusCard(
        icon: Icons.warning_amber_rounded,
        title: title,
        description: description,
        detail: detail,
        iconColor: AppTheme.danger,
        onRetry: onRetry,
        onOpenSettings: onOpenSettings,
      );

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.primary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    detail!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (onRetry != null || onOpenSettings != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onRetry != null) ...[
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 22),
                          label: const Text('重试'),
                        ),
                      ),
                      if (onOpenSettings != null) const SizedBox(width: 12),
                    ],
                    if (onOpenSettings != null)
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: onOpenSettings,
                          icon: const Icon(Icons.settings_rounded, size: 22),
                          label: const Text('打开设置'),
                        ),
                      ),
                  ],
                ),
              ],
              ...extraActions,
            ],
          ),
        ),
      ),
    );
  }
}

/// 加载占位 - 简单的居中圆环 + 文字
class LoadingPlaceholder extends StatelessWidget {
  final String message;
  final Color? color;

  const LoadingPlaceholder({
    super.key,
    this.message = '准备中…',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
