import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/tts/safe_tts.dart';
import '../../../../shared/theme/app_theme.dart';

class ScreenReaderPage extends ConsumerStatefulWidget {
  const ScreenReaderPage({super.key});

  @override
  ConsumerState<ScreenReaderPage> createState() => _ScreenReaderPageState();
}

class _ScreenReaderPageState extends ConsumerState<ScreenReaderPage>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.blindassist/accessibility');
  final SafeTts _tts = SafeTts();
  bool _serviceEnabled = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.init();
    _checkService();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkService();
  }

  Future<void> _checkService() async {
    setState(() => _checking = true);
    bool enabled = false;
    try {
      enabled = await _channel
              .invokeMethod<bool>('isServiceEnabled')
              .timeout(const Duration(seconds: 2)) ??
          false;
    } catch (_) {
      enabled = false;
    }
    if (mounted) {
      setState(() {
        _serviceEnabled = enabled;
        _checking = false;
      });
    }
  }

  Future<void> _demoRead() async {
    HapticFeedback.mediumImpact();
    await _tts.speak(
      '当您打开微信时，启明会播报：'
      '当前在微信，主页有四个标签：微信、通讯录、发现、我。'
      '当前选中的是微信标签，下方是聊天列表，共有十二个对话。',
    );
  }

  Future<void> _openAccessibilitySettings() async {
    HapticFeedback.mediumImpact();
    try {
      await _channel
          .invokeMethod('openAccessibilitySettings')
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      if (mounted) _showSnack('请到 系统设置 > 无障碍 > 已下载的应用 中开启"启明"');
    }
  }

  Future<void> _openBatterySettings() async {
    HapticFeedback.mediumImpact();
    try {
      await _channel
          .invokeMethod('openBatterySettings')
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      if (mounted) _showSnack('请到 系统设置 > 电池 > 应用启动管理 中关闭对启明的限制');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('应用解读'),
        actions: [
          IconButton(
            tooltip: '刷新状态',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _checkService,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusBanner(),
              const SizedBox(height: 16),
              // 头图
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.channelScreen.withOpacity(0.15),
                      AppTheme.channelScreen.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.channelScreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.smart_toy_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text('让 AI 替你"看"应用',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    const Text(
                      '理解微信、支付宝、淘宝等应用的界面，\n并用语音告诉你当前能做什么',
                      style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 试听按钮
              SizedBox(
                width: double.infinity, height: 76,
                child: ElevatedButton.icon(
                  onPressed: _demoRead,
                  icon: const Icon(Icons.volume_up_rounded, size: 28),
                  label: const Text('听一段解读演示',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.channelScreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('如何启用',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              const _StepCard(step: 1, title: '打开无障碍设置', desc: '点击下方按钮，跳转到系统无障碍设置页'),
              const SizedBox(height: 10),
              const _StepCard(step: 2, title: '找到「启明」', desc: '在「已下载的应用」分类下找到启明'),
              const SizedBox(height: 10),
              const _StepCard(step: 3, title: '打开开关', desc: '把启明的开关打开，授予无障碍权限'),
              const SizedBox(height: 10),
              const _StepCard(step: 4, title: '保活设置（重要）', desc: '点击「打开省电设置」，把启明加入"省电白名单"'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 64,
                child: ElevatedButton.icon(
                  onPressed: _openAccessibilitySettings,
                  icon: const Icon(Icons.settings_accessibility, size: 24),
                  label: const Text('打开无障碍设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.channelScreen),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 56,
                child: OutlinedButton.icon(
                  onPressed: _openBatterySettings,
                  icon: const Icon(Icons.battery_charging_full_rounded, size: 22),
                  label: const Text('打开省电设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 20),
                      SizedBox(width: 8),
                      Text('为什么会被自动关闭？',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.warning)),
                    ]),
                    SizedBox(height: 8),
                    Text(
                      '华为、小米、OPPO、vivo 等系统会出于省电目的自动清理无障碍服务。\n\n'
                      '解决方法：\n'
                      '1. 把启明加入"省电白名单"\n'
                      '2. 允许启明"自启动"\n'
                      '3. 锁屏时不清理启明\n'
                      '4. 重启手机后重新开启',
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_checking) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('正在检查…', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
        ]),
      );
    }
    final color = _serviceEnabled ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(_serviceEnabled ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_serviceEnabled ? '无障碍服务已开启' : '无障碍服务未开启',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(_serviceEnabled ? '应用解读功能可以正常工作' : '请按下方步骤开启',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ])),
      ]),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final String desc;
  const _StepCard({required this.step, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.channelScreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text('$step', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.channelScreen)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(desc, style: Theme.of(context).textTheme.bodyMedium),
        ])),
      ]),
    );
  }
}
