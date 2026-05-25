import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/tts/safe_tts.dart';
import '../../../../shared/theme/app_theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final SafeTts _tts = SafeTts();
  Box? _box;
  double _speechRate = 0.5;
  double _volume = 1.0;
  bool _hapticEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _box = await Hive.openBox('settings');
      _speechRate = (_box?.get('speechRate') as num?)?.toDouble() ?? 0.5;
      _volume = (_box?.get('volume') as num?)?.toDouble() ?? 1.0;
      _hapticEnabled = _box?.get('hapticEnabled') as bool? ?? true;
      _tts.init();
      // 应用已保存的语速
      await _tts.setSpeechRate(_speechRate);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save(String key, dynamic value) async {
    try {
      await _box?.put(key, value);
    } catch (_) {}
  }

  Future<void> _testSpeech() async {
    HapticFeedback.lightImpact();
    await _tts.stop();
    await _tts.setSpeechRate(_speechRate);
    await _tts.speak('这是当前语速的效果，一二三四五');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _section('语音'),
                  _slider(
                    icon: Icons.speed_rounded,
                    title: '说话速度',
                    value: _speechRate,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    valueText: _speedLabel(_speechRate),
                    onChanged: (v) => setState(() => _speechRate = v),
                    onChangeEnd: (v) async {
                      await _save('speechRate', v);
                      await _tts.setSpeechRate(v);
                      await _testSpeech();
                    },
                  ),
                  const SizedBox(height: 12),
                  _slider(
                    icon: Icons.volume_up_rounded,
                    title: '音量',
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    valueText: '${(_volume * 100).round()}%',
                    onChanged: (v) => setState(() => _volume = v),
                    onChangeEnd: (v) async {
                      await _save('volume', v);
                      await _testSpeech();
                    },
                  ),
                  const SizedBox(height: 24),
                  _section('反馈'),
                  _switchTile(
                    icon: Icons.vibration_rounded,
                    title: '震动反馈',
                    sub: '点击和告警时震动',
                    value: _hapticEnabled,
                    onChanged: (v) async {
                      setState(() => _hapticEnabled = v);
                      await _save('hapticEnabled', v);
                      if (v) HapticFeedback.mediumImpact();
                    },
                  ),
                  const SizedBox(height: 24),
                  _section('关于'),
                  _aboutTile(
                    icon: Icons.info_outline_rounded,
                    title: '版本',
                    sub: '启明 v1.0.0 (MVP)',
                  ),
                  const SizedBox(height: 10),
                  _aboutTile(
                    icon: Icons.favorite_rounded,
                    title: '关于启明',
                    sub: '愿你眼中有光',
                    accent: true,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 0, 12),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppTheme.textSecondary)),
      );

  String _speedLabel(double v) {
    if (v < 0.3) return '慢';
    if (v < 0.6) return '正常';
    if (v < 0.8) return '快';
    return '极快';
  }

  Widget _slider({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueText,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: Colors.white,
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
                child: Icon(icon, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(valueText,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueText,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600)),
        subtitle: Text(sub,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textSecondary)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _aboutTile({
    required IconData icon,
    required String title,
    required String sub,
    bool accent = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent ? AppTheme.primary.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: accent
                ? AppTheme.primary.withOpacity(0.2)
                : AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent
                  ? AppTheme.primary.withOpacity(0.15)
                  : AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
