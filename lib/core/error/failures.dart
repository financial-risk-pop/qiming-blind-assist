import 'package:equatable/equatable.dart';

/// 失败基类 - 所有业务错误的统一表示
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];

  /// 转为用户友好的语音播报文本
  String toSpeechText();
}

/// 服务器端错误
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});

  @override
  String toSpeechText() => '网络请求失败，$message';
}

/// 网络连接错误
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = '网络连接不可用', super.code});

  @override
  String toSpeechText() => '当前没有网络连接，部分功能可能不可用';
}

/// 权限错误
class PermissionFailure extends Failure {
  final String permissionName;

  const PermissionFailure({
    required this.permissionName,
    super.message = '权限未授予',
    super.code,
  });

  @override
  String toSpeechText() => '$permissionName权限未授予，请前往设置开启';

  @override
  List<Object?> get props => [message, code, permissionName];
}

/// 设备功能不可用
class DeviceFailure extends Failure {
  const DeviceFailure({required super.message, super.code});

  @override
  String toSpeechText() => '设备功能异常，$message';
}

/// AI推理/模型错误
class AIModelFailure extends Failure {
  const AIModelFailure({required super.message, super.code});

  @override
  String toSpeechText() => 'AI识别出错，$message';
}

/// 缓存错误
class CacheFailure extends Failure {
  const CacheFailure({super.message = '本地缓存异常', super.code});

  @override
  String toSpeechText() => '本地数据读取失败';
}

/// 无障碍服务错误
class AccessibilityServiceFailure extends Failure {
  const AccessibilityServiceFailure({
    super.message = '无障碍服务未启用',
    super.code,
  });

  @override
  String toSpeechText() => '无障碍服务未启用，App解读功能需要开启无障碍服务';
}

/// 语音识别错误
class SpeechRecognitionFailure extends Failure {
  const SpeechRecognitionFailure({
    super.message = '语音识别失败',
    super.code,
  });

  @override
  String toSpeechText() => '没有听清，请再说一遍';
}

/// 导航错误
class NavigationFailure extends Failure {
  const NavigationFailure({required super.message, super.code});

  @override
  String toSpeechText() => '导航出错，$message';
}

/// 超时错误
class TimeoutFailure extends Failure {
  const TimeoutFailure({super.message = '请求超时', super.code});

  @override
  String toSpeechText() => '操作超时，请重试';
}
