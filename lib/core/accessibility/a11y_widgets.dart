import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// 无障碍增强按钮 - 确保所有按钮都有完整的语义标注和足够大的触摸区域
class A11yButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback onPressed;
  final IconData? icon;
  final double minSize;
  final bool isEnabled;
  final Color? backgroundColor;

  const A11yButton({
    super.key,
    required this.label,
    this.hint,
    required this.onPressed,
    this.icon,
    this.minSize = 56.0,
    this.isEnabled = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ??
        theme.colorScheme.primary.withOpacity(isEnabled ? 1.0 : 0.3);
    final fgColor = theme.colorScheme.onPrimary;

    return Semantics(
      label: label,
      hint: hint ?? '双击$label',
      button: true,
      enabled: isEnabled,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minSize,
              minHeight: minSize,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null)
                    Icon(
                      icon,
                      size: 32,
                      color: fgColor,
                    ),
                  if (icon != null) const SizedBox(height: 8),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: fgColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 无障碍信息卡片 - 用于展示信息内容，带完整语义标注
class A11yInfoCard extends StatelessWidget {
  final String title;
  final String content;
  final String? semanticLabel;
  final VoidCallback? onTap;

  const A11yInfoCard({
    super.key,
    required this.title,
    required this.content,
    this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? '$title: $content',
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 无障碍状态指示器 - 用于显示当前功能状态
class A11yStatusIndicator extends StatelessWidget {
  final String statusLabel;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;

  const A11yStatusIndicator({
    super.key,
    required this.statusLabel,
    required this.isActive,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? Colors.green)
        : (inactiveColor ?? Colors.grey);

    return Semantics(
      label: '$statusLabel: ${isActive ? "已开启" : "已关闭"}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// 为已有Widget快速包裹Semantics的扩展方法
extension A11yExtension on Widget {
  Widget withSemantics({
    required String label,
    String? hint,
    bool? button,
    bool? header,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: button,
      header: header,
      onTap: onTap,
      child: this,
    );
  }
}
