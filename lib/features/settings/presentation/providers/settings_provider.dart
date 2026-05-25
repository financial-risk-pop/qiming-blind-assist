import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/accessibility/a11y_config.dart';
import '../../../../core/utils/logger.dart';
import '../../../voice_interaction/presentation/providers/voice_provider.dart';

/// 设置状态
class SettingsState {
  final AccessibilityConfig config;
  final bool isLoading;

  const SettingsState({
    required this.config,
    this.isLoading = false,
  });

  SettingsState copyWith({
    AccessibilityConfig? config,
    bool? isLoading,
  }) {
    return SettingsState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 设置Notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  Box? _settingsBox;

  SettingsNotifier(this._ref)
      : super(SettingsState(config: AccessibilityConfig()));

  /// 初始化，从本地存储加载设置
  Future<void> initialize() async {
    try {
      _settingsBox = await Hive.openBox('settings');
      final savedConfig = _settingsBox?.get('config');
      if (savedConfig != null) {
        try {
          final config = AccessibilityConfig.fromJson(
            Map<String, dynamic>.from(savedConfig as Map),
          );
          state = SettingsState(config: config);
          AppLogger.info('已加载本地设置', tag: 'Settings');
        } catch (e) {
          AppLogger.warning('加载本地设置失败，使用默认值: $e', tag: 'Settings');
        }
      }
      // 应用到 TTS 引擎
      _applyTtsSettings();
    } catch (e) {
      AppLogger.error('Settings 初始化失败: $e', tag: 'Settings');
    }
  }

  /// 将当前 TTS 相关配置同步到语音引擎
  void _applyTtsSettings() {
    try {
      final voiceNotifier = _ref.read(voiceNotifierProvider.notifier);
      voiceNotifier.updateSpeechRate(state.config.speechRate);
      voiceNotifier.updateVolume(state.config.speechVolume);
    } catch (_) {
      // voice 可能还未初始化，忽略
    }
  }

  /// 保存设置到本地
  Future<void> _saveConfig() async {
    try {
      await _settingsBox?.put('config', state.config.toJson());
    } catch (e) {
      AppLogger.error('保存设置失败: $e', tag: 'Settings');
    }
  }

  /// 统一更新入口：用 copyWith 保留其他字段
  Future<void> _update(AccessibilityConfig Function(AccessibilityConfig c) mutate,
      {bool applyToTts = false}) async {
    final newConfig = mutate(state.config);
    state = state.copyWith(config: newConfig);
    await _saveConfig();
    if (applyToTts) _applyTtsSettings();
  }

  /// 更新TTS语速（0.1 - 1.0）
  Future<void> updateSpeechRate(double rate) async {
    final clamped = rate.clamp(0.1, 1.0);
    await _update((c) => c.copyWith(speechRate: clamped), applyToTts: true);
  }

  /// 更新TTS音量（0.0 - 1.0）
  Future<void> updateSpeechVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _update((c) => c.copyWith(speechVolume: clamped), applyToTts: true);
  }

  /// 更新TTS音调（0.5 - 2.0）
  Future<void> updateSpeechPitch(double pitch) async {
    final clamped = pitch.clamp(0.5, 2.0);
    await _update((c) => c.copyWith(speechPitch: clamped));
  }

  /// 更新震动设置
  Future<void> updateVibrationEnabled(bool enabled) =>
      _update((c) => c.copyWith(hapticEnabled: enabled));

  /// 更新震动强度
  Future<void> updateHapticIntensity(double intensity) =>
      _update((c) => c.copyWith(hapticIntensity: intensity.clamp(0.5, 2.0)));

  /// 更新字体缩放
  Future<void> updateFontScale(double scale) =>
      _update((c) => c.copyWith(fontScale: scale.clamp(1.0, 3.0)));

  /// 更新高对比度模式
  Future<void> updateHighContrast(bool enabled) =>
      _update((c) => c.copyWith(highContrastMode: enabled));

  /// 更新App解读开关
  Future<void> updateScreenReaderEnabled(bool enabled) =>
      _update((c) => c.copyWith(screenReaderEnabled: enabled));

  /// 更新AI增强开关
  Future<void> updateAiEnhanced(bool enabled) =>
      _update((c) => c.copyWith(aiEnhancedReadingEnabled: enabled));

  /// 更新切换App时自动播报
  Future<void> updateAutoAnnounce(bool enabled) =>
      _update((c) => c.copyWith(autoAnnounceAppSwitch: enabled));

  /// 更新告警距离（米）
  Future<void> updateAlertDistance(double distance) =>
      _update((c) => c.copyWith(minAlertDistance: distance.clamp(1.0, 10.0)));

  /// 更新紧急告警距离
  Future<void> updateUrgentAlertDistance(double distance) => _update(
      (c) => c.copyWith(urgentAlertDistance: distance.clamp(0.3, 3.0)));

  /// 更新敏感App列表
  Future<void> updateSensitiveApps(List<String> packages) =>
      _update((c) => c.copyWith(sensitiveAppPackages: packages));
}

/// 设置状态Provider
final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
