/// 全局无障碍配置
/// 
/// 统一管理整个App的无障碍相关设置，包括：
/// - 语音播报速度/音量
/// - 震动反馈开关
/// - 高对比度模式
/// - 字体缩放
/// - 触摸区域大小
class AccessibilityConfig {
  // ===== 语音设置 =====
  
  /// TTS语速（0.0-1.0，默认0.5为正常速度）
  double speechRate;
  
  /// TTS音量（0.0-1.0）
  double speechVolume;
  
  /// TTS音调（0.5-2.0，默认1.0为正常音调）
  double speechPitch;
  
  /// TTS语言
  String speechLocale;

  // ===== 震动设置 =====
  
  /// 是否启用震动反馈
  bool hapticEnabled;
  
  /// 震动强度倍率（0.5-2.0）
  double hapticIntensity;

  // ===== 界面设置 =====
  
  /// 是否启用高对比度模式
  bool highContrastMode;
  
  /// 字体缩放比例（1.0-3.0）
  double fontScale;
  
  /// 最小触摸区域大小（dp）
  double minTouchTargetSize;

  // ===== 检测设置 =====
  
  /// 障碍物最小告警距离（米）
  double minAlertDistance;
  
  /// 障碍物紧急告警距离（米）
  double urgentAlertDistance;
  
  /// 障碍物告警间隔（秒，避免过于频繁）
  double alertCooldownSeconds;

  // ===== App解读设置 =====
  
  /// 是否启用App解读功能
  bool screenReaderEnabled;
  
  /// 是否启用AI增强解读（需要网络）
  bool aiEnhancedReadingEnabled;
  
  /// 切换App时是否自动播报
  bool autoAnnounceAppSwitch;
  
  /// 敏感App包名列表（禁用截图分析）
  List<String> sensitiveAppPackages;

  AccessibilityConfig({
    this.speechRate = 0.5,
    this.speechVolume = 1.0,
    this.speechPitch = 1.0,
    this.speechLocale = 'zh-CN',
    this.hapticEnabled = true,
    this.hapticIntensity = 1.0,
    this.highContrastMode = true,
    this.fontScale = 1.5,
    this.minTouchTargetSize = 56.0,
    this.minAlertDistance = 5.0,
    this.urgentAlertDistance = 1.0,
    this.alertCooldownSeconds = 3.0,
    this.screenReaderEnabled = true,
    this.aiEnhancedReadingEnabled = true,
    this.autoAnnounceAppSwitch = true,
    List<String>? sensitiveAppPackages,
  }) : sensitiveAppPackages = sensitiveAppPackages ??
            [
              // 默认的敏感App列表（银行/支付类）
              'com.eg.android.AlipayGphone', // 支付宝
              'com.tencent.mm',              // 微信支付相关页面
              'com.icbc',                     // 工商银行
              'com.ccb.mobile',               // 建设银行
              'com.chinamworld.bocmbci',      // 中国银行
              'com.abchina.sj',               // 农业银行
            ];

  /// 复制并修改部分字段
  AccessibilityConfig copyWith({
    double? speechRate,
    double? speechVolume,
    double? speechPitch,
    String? speechLocale,
    bool? hapticEnabled,
    double? hapticIntensity,
    bool? highContrastMode,
    double? fontScale,
    double? minTouchTargetSize,
    double? minAlertDistance,
    double? urgentAlertDistance,
    double? alertCooldownSeconds,
    bool? screenReaderEnabled,
    bool? aiEnhancedReadingEnabled,
    bool? autoAnnounceAppSwitch,
    List<String>? sensitiveAppPackages,
  }) {
    return AccessibilityConfig(
      speechRate: speechRate ?? this.speechRate,
      speechVolume: speechVolume ?? this.speechVolume,
      speechPitch: speechPitch ?? this.speechPitch,
      speechLocale: speechLocale ?? this.speechLocale,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      fontScale: fontScale ?? this.fontScale,
      minTouchTargetSize: minTouchTargetSize ?? this.minTouchTargetSize,
      minAlertDistance: minAlertDistance ?? this.minAlertDistance,
      urgentAlertDistance: urgentAlertDistance ?? this.urgentAlertDistance,
      alertCooldownSeconds: alertCooldownSeconds ?? this.alertCooldownSeconds,
      screenReaderEnabled: screenReaderEnabled ?? this.screenReaderEnabled,
      aiEnhancedReadingEnabled:
          aiEnhancedReadingEnabled ?? this.aiEnhancedReadingEnabled,
      autoAnnounceAppSwitch:
          autoAnnounceAppSwitch ?? this.autoAnnounceAppSwitch,
      sensitiveAppPackages: sensitiveAppPackages ?? this.sensitiveAppPackages,
    );
  }

  /// 从本地存储恢复配置
  factory AccessibilityConfig.fromJson(Map<String, dynamic> json) {
    return AccessibilityConfig(
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      speechVolume: (json['speechVolume'] as num?)?.toDouble() ?? 1.0,
      speechPitch: (json['speechPitch'] as num?)?.toDouble() ?? 1.0,
      speechLocale: json['speechLocale'] as String? ?? 'zh-CN',
      hapticEnabled: json['hapticEnabled'] as bool? ?? true,
      hapticIntensity: (json['hapticIntensity'] as num?)?.toDouble() ?? 1.0,
      highContrastMode: json['highContrastMode'] as bool? ?? true,
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.5,
      minTouchTargetSize: (json['minTouchTargetSize'] as num?)?.toDouble() ?? 56.0,
      minAlertDistance: (json['minAlertDistance'] as num?)?.toDouble() ?? 5.0,
      urgentAlertDistance: (json['urgentAlertDistance'] as num?)?.toDouble() ?? 1.0,
      alertCooldownSeconds: (json['alertCooldownSeconds'] as num?)?.toDouble() ?? 3.0,
      screenReaderEnabled: json['screenReaderEnabled'] as bool? ?? true,
      aiEnhancedReadingEnabled: json['aiEnhancedReadingEnabled'] as bool? ?? true,
      autoAnnounceAppSwitch: json['autoAnnounceAppSwitch'] as bool? ?? true,
      sensitiveAppPackages: (json['sensitiveAppPackages'] as List?)?.cast<String>(),
    );
  }

  /// 序列化为JSON用于本地存储
  Map<String, dynamic> toJson() {
    return {
      'speechRate': speechRate,
      'speechVolume': speechVolume,
      'speechPitch': speechPitch,
      'speechLocale': speechLocale,
      'hapticEnabled': hapticEnabled,
      'hapticIntensity': hapticIntensity,
      'highContrastMode': highContrastMode,
      'fontScale': fontScale,
      'minTouchTargetSize': minTouchTargetSize,
      'minAlertDistance': minAlertDistance,
      'urgentAlertDistance': urgentAlertDistance,
      'alertCooldownSeconds': alertCooldownSeconds,
      'screenReaderEnabled': screenReaderEnabled,
      'aiEnhancedReadingEnabled': aiEnhancedReadingEnabled,
      'autoAnnounceAppSwitch': autoAnnounceAppSwitch,
      'sensitiveAppPackages': sensitiveAppPackages,
    };
  }
}
