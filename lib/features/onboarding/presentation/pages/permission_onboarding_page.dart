import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/tts/safe_tts.dart';

import '../../../../shared/theme/app_theme.dart';

/// 权限项定义
class _PermItem {
  final String key;
  final String name;
  final String purpose; // 一句话用途
  final String example; // 举例（让用户更好理解）
  final IconData icon;
  final Color color;
  final Permission permission;
  final bool required;

  const _PermItem({
    required this.key,
    required this.name,
    required this.purpose,
    required this.example,
    required this.icon,
    required this.color,
    required this.permission,
    required this.required,
  });
}

/// 权限引导页
///
/// 设计原则：
/// 1. 不一次性弹出全部系统弹窗
/// 2. 用大字 + 图标 + 人话解释每个权限
/// 3. 用户主动勾选并逐个授予
/// 4. 显示每个权限的当前状态
/// 5. 完成后写入 Hive 标记，下次不再显示
class PermissionOnboardingPage extends StatefulWidget {
  const PermissionOnboardingPage({super.key});

  @override
  State<PermissionOnboardingPage> createState() =>
      _PermissionOnboardingPageState();
}

class _PermissionOnboardingPageState extends State<PermissionOnboardingPage>
    with WidgetsBindingObserver {
  final SafeTts _tts = SafeTts();

  // 当前页：0=欢迎页 1=权限列表 2=完成页
  int _step = 0;

  // 4 个权限定义
  static const List<_PermItem> _items = [
    _PermItem(
      key: 'camera',
      name: '摄像头',
      purpose: '看见前方的世界',
      example: '识别文字、检测障碍物、看钞票颜色',
      icon: Icons.camera_alt_rounded,
      color: AppTheme.channelText,
      permission: Permission.camera,
      required: true,
    ),
    _PermItem(
      key: 'microphone',
      name: '麦克风',
      purpose: '听见您的声音',
      example: '语音说出目的地、语音指令操作',
      icon: Icons.mic_rounded,
      color: AppTheme.channelObstacle,
      permission: Permission.microphone,
      required: true,
    ),
    _PermItem(
      key: 'location',
      name: '位置信息',
      purpose: '知道您在哪里',
      example: '语音导航、查找附近的地方',
      icon: Icons.location_on_rounded,
      color: AppTheme.channelNavi,
      permission: Permission.location,
      required: true,
    ),
    _PermItem(
      key: 'notification',
      name: '通知',
      purpose: '及时提醒您重要信息',
      example: '导航语音提示、紧急避障提醒',
      icon: Icons.notifications_rounded,
      color: AppTheme.accent,
      permission: Permission.notification,
      required: false,
    ),
  ];

  // 每个权限的当前状态
  Map<String, PermissionStatus> _status = {};

  // 用户勾选要授予的权限（默认全选必需的）
  Map<String, bool> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final item in _items) {
      _selected[item.key] = item.required; // 默认勾选必需权限
    }
    _tts.init();
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 用户从系统设置回来，自动刷新状态
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _refreshStatus() async {
    final newStatus = <String, PermissionStatus>{};
    for (final item in _items) {
      try {
        newStatus[item.key] = await item.permission.status;
      } catch (_) {
        newStatus[item.key] = PermissionStatus.denied;
      }
    }
    if (mounted) {
      setState(() => _status = newStatus);
    }
  }

  /// 单独请求一个权限
  Future<void> _requestOne(_PermItem item) async {
    HapticFeedback.lightImpact();

    final current = _status[item.key];
    if (current?.isGranted == true) {
      _speak('${item.name}权限已经开启');
      return;
    }

    if (current?.isPermanentlyDenied == true) {
      // 永久拒绝必须去设置开
      _speak('${item.name}权限被禁用，请到系统设置中手动开启');
      await _showOpenSettingsDialog(item);
      return;
    }

    _speak('正在申请${item.name}权限');
    try {
      final status = await item.permission
          .request()
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() => _status[item.key] = status);

      if (status.isGranted) {
        _speak('${item.name}权限已授予');
        HapticFeedback.mediumImpact();
      } else if (status.isPermanentlyDenied) {
        _speak('${item.name}权限被禁用，请到系统设置中开启');
        await _showOpenSettingsDialog(item);
      } else {
        _speak('${item.name}权限被拒绝');
      }
    } catch (_) {
      if (mounted) {
        _speak('申请权限超时，请重试');
      }
    }
  }

  /// 引导去系统设置
  Future<void> _showOpenSettingsDialog(_PermItem item) async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('开启${item.name}权限'),
        content: Text(
          '${item.name}权限被禁用，需要您到系统设置中手动开启。\n\n'
          '路径：设置 → 应用 → 启明 → 权限 → ${item.name}',
          style: const TextStyle(fontSize: 16, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍后', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去设置', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (go == true) {
      await openAppSettings();
    }
  }

  /// 一键授予所有勾选的权限
  Future<void> _requestSelected() async {
    HapticFeedback.mediumImpact();
    _speak('开始依次申请您勾选的权限');
    for (final item in _items) {
      if (_selected[item.key] != true) continue;
      final current = _status[item.key];
      if (current?.isGranted == true) continue;
      await _requestOne(item);
      // 等用户处理完一个再下一个
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// 完成引导
  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    try {
      final box = await Hive.openBox('app_state');
      await box.put('permission_onboarded', true);
    } catch (_) {}
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildWelcomePage();
      case 1:
        return _buildPermissionListPage();
      case 2:
      default:
        return _buildFinishPage();
    }
  }

  // ============================================================
  //                        第 1 屏：欢迎
  // ============================================================
  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          // Logo
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 56, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '欢迎使用启明',
            style: Theme.of(context).textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '愿你眼中有光',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // 说明卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '为了帮您看见世界',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '启明需要您授权使用一些手机功能。\n\n'
                  '我们会逐项告诉您每个权限的用途，'
                  '由您决定是否授予。\n\n'
                  '所有数据都在您的手机本地处理，不会上传到任何服务器。',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.7,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 下一步按钮
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _step = 1);
              _speak('请逐项查看并授予所需权限');
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '查看权限说明',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 跳过
          TextButton(
            onPressed: _finish,
            child: const Text(
              '稍后再说，先进入应用',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //                      第 2 屏：权限清单
  // ============================================================
  Widget _buildPermissionListPage() {
    final granted = _items.where((i) => _status[i.key]?.isGranted == true).length;
    final required = _items.where((i) => i.required).length;
    final requiredGranted = _items
        .where((i) => i.required && _status[i.key]?.isGranted == true)
        .length;

    return Column(
      key: const ValueKey('list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部进度条
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _step = 0),
                icon: const Icon(Icons.arrow_back_rounded),
                iconSize: 28,
                tooltip: '返回',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '权限管理',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已授予 $granted / ${_items.length}（必需 $requiredGranted / $required）',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 权限卡片列表
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _buildPermissionCard(item);
            },
          ),
        ),

        // 底部操作区
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 一键授权
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestSelected,
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text(
                    '授予已勾选的权限',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 完成
              TextButton(
                onPressed: () {
                  if (requiredGranted < required) {
                    setState(() => _step = 2);
                  } else {
                    _finish();
                  }
                },
                child: Text(
                  requiredGranted >= required ? '✓ 完成进入主页' : '稍后再说',
                  style: TextStyle(
                    fontSize: 16,
                    color: requiredGranted >= required
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                    fontWeight: requiredGranted >= required
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionCard(_PermItem item) {
    final status = _status[item.key];
    final granted = status?.isGranted == true;
    final permanentlyDenied = status?.isPermanentlyDenied == true;
    final selected = _selected[item.key] ?? false;

    return Semantics(
      label: '${item.name}权限，${granted ? "已授予" : "未授予"}',
      hint: granted ? '双击查看详情' : '双击授予',
      button: true,
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          onTap: () => _requestOne(item),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: granted ? AppTheme.success : AppTheme.divider,
                width: granted ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 勾选框
                    if (!granted)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selected[item.key] = !selected;
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: selected ? item.color : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? item.color : AppTheme.divider,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                      )
                    else
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 20),
                      ),

                    const SizedBox(width: 12),

                    // 图标
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color, size: 28),
                    ),

                    const SizedBox(width: 12),

                    // 名称 + 标签
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              _buildBadge(
                                item.required ? '必需' : '可选',
                                item.required
                                    ? AppTheme.danger
                                    : AppTheme.textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.purpose,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 用途详情
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          size: 16, color: item.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '用于：${item.example}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 状态 + 操作
                Row(
                  children: [
                    Expanded(child: _buildStatusChip(status)),
                    const SizedBox(width: 8),
                    if (granted)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '✓ 已开启',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      )
                    else if (permanentlyDenied)
                      ElevatedButton.icon(
                        onPressed: () => _showOpenSettingsDialog(item),
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('去设置开启'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warning,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => _requestOne(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: item.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                        child: const Text(
                          '授予',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusChip(PermissionStatus? status) {
    String text;
    Color color;
    IconData icon;
    if (status == null) {
      text = '检查中…';
      color = AppTheme.textSecondary;
      icon = Icons.hourglass_empty;
    } else if (status.isGranted) {
      text = '已授予';
      color = AppTheme.success;
      icon = Icons.check_circle;
    } else if (status.isPermanentlyDenied) {
      text = '已禁用';
      color = AppTheme.danger;
      icon = Icons.block;
    } else if (status.isDenied) {
      text = '未授予';
      color = AppTheme.warning;
      icon = Icons.warning_amber_rounded;
    } else if (status.isRestricted) {
      text = '受限制';
      color = AppTheme.warning;
      icon = Icons.lock;
    } else {
      text = '未授予';
      color = AppTheme.textSecondary;
      icon = Icons.help_outline;
    }
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  //                       第 3 屏：完成
  // ============================================================
  Widget _buildFinishPage() {
    final required = _items.where((i) => i.required).length;
    final requiredGranted = _items
        .where((i) => i.required && _status[i.key]?.isGranted == true)
        .length;
    final allGood = requiredGranted >= required;

    return Padding(
      key: const ValueKey('finish'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: (allGood ? AppTheme.success : AppTheme.warning)
                  .withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              allGood ? Icons.check_circle : Icons.warning_amber_rounded,
              color: allGood ? AppTheme.success : AppTheme.warning,
              size: 80,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            allGood ? '准备就绪' : '部分功能受限',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          Text(
            allGood
                ? '所有必需权限已开启，您可以开始使用启明的全部功能'
                : '$required 项必需权限中，已开启 $requiredGranted 项。\n未开启的功能将无法使用，您可随时回到「设置」开启。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              children: _items.map((item) {
                final granted = _status[item.key]?.isGranted == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(item.icon, color: item.color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.name)),
                      Icon(
                        granted ? Icons.check_circle : Icons.cancel_outlined,
                        color: granted ? AppTheme.success : AppTheme.danger,
                        size: 20,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Spacer(),
          if (!allGood)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text(
                  '返回继续授权',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '进入主页',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
