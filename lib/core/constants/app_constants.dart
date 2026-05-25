/// 全局常量定义
class AppConstants {
  AppConstants._();

  // ===== App信息 =====
  static const String appName = '启明';
  static const String appVersion = '1.0.0';

  // ===== Platform Channel名称 =====
  static const String accessibilityChannel = 'com.blindassist/accessibility';
  static const String iosAccessibilityChannel = 'com.blindassist/ios_accessibility';
  static const String sensorChannel = 'com.blindassist/sensors';
  static const String screenReaderChannel = 'com.blindassist/screen_reader';

  // ===== 检测参数 =====
  /// 摄像头采集帧率（行走模式）
  static const int walkingFps = 15;
  /// 摄像头采集帧率（静止模式）
  static const int stationaryFps = 5;
  /// 摄像头采集帧率（行走模式，别名）
  static const int walkingDetectionFps = walkingFps;
  /// 障碍物检测模型输入尺寸
  static const int detectionModelInputSize = 320;
  /// 障碍物检测模型输入尺寸（别名）
  static const int modelInputSize = detectionModelInputSize;
  /// 最小检测置信度
  static const double minDetectionConfidence = 0.5;
  /// 检测置信度阈值（别名）
  static const double confidenceThreshold = minDetectionConfidence;
  /// OCR最小置信度（低于此值切换云端）
  static const double minOcrConfidence = 0.7;

  // ===== 导航参数 =====
  /// 偏航检测阈值（米）
  static const double deviationThreshold = 30.0;
  /// 偏航检测间隔（秒）
  static const int deviationCheckInterval = 5;
  /// 特殊路段预警距离（米）
  static const double specialSegmentAlertDistance = 20.0;

  // ===== 语音参数 =====
  /// 默认TTS语速
  static const double defaultSpeechRate = 0.5;
  /// 默认TTS音量
  static const double defaultSpeechVolume = 1.0;
  /// 唤醒词
  static const String wakeWord = '小助手';

  // ===== 缓存参数 =====
  /// App解读AI结果缓存时长（分钟）
  static const int screenReadCacheDurationMinutes = 30;
  /// App解读本地缓存时长（小时）
  static const int screenReadLocalCacheHours = 24;

  // ===== 震动参数（毫秒）=====
  /// 普通障碍物震动时长
  static const int normalObstacleVibration = 100;
  /// 近距离障碍物震动模式
  static const List<int> nearObstacleVibrationPattern = [0, 100, 50, 100];
  /// 紧急障碍物震动时长
  static const int urgentObstacleVibration = 500;
  /// 导航转弯提示震动模式
  static const List<int> turnVibrationPattern = [0, 50, 30, 50, 30, 50];
  /// 操作确认轻震
  static const int confirmVibration = 30;

  // ===== 网络参数 =====
  /// AI视觉理解API超时（秒）
  static const int aiVisionTimeout = 10;
  /// 云端OCR超时（秒）
  static const int cloudOcrTimeout = 5;
  /// API基础地址
  static const String apiBaseUrl = 'https://api.blindassist.com/v1';

  // ===== 本地存储Key =====
  static const String boxSettings = 'settings';
  static const String boxCache = 'cache';
  static const String boxAppKnowledge = 'app_knowledge';
  static const String keyA11yConfig = 'accessibility_config';
  static const String keyUserPreferences = 'user_preferences';
}

/// 障碍物类型
enum ObstacleType {
  pedestrian('行人'),
  vehicle('车辆'),
  stairs('台阶'),
  pothole('坑洞'),
  barrier('路障'),
  pillar('柱子'),
  pole('杆子'),
  curb('路沿'),
  bicycle('自行车'),
  animal('动物'),
  other('其他'),
  unknown('未知物体');

  final String label;
  const ObstacleType(this.label);
}

/// 相对方位
enum Direction {
  leftFar('左前方远处'),
  leftNear('左前方'),
  left('左侧'),
  frontLeft('正前偏左'),
  front('正前方'),
  frontRight('正前偏右'),
  right('右侧'),
  rightNear('右前方'),
  rightFar('右前方远处'),
  farLeft('远左'),
  farRight('远右');

  final String label;
  const Direction(this.label);
}
