/// 服务器异常
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({required this.message, this.statusCode});

  @override
  String toString() => 'ServerException: $message (code: $statusCode)';
}

/// 缓存异常
class CacheException implements Exception {
  final String message;

  const CacheException({this.message = '缓存操作失败'});

  @override
  String toString() => 'CacheException: $message';
}

/// 设备异常
class DeviceException implements Exception {
  final String message;

  const DeviceException({required this.message});

  @override
  String toString() => 'DeviceException: $message';
}

/// AI模型异常
class AIModelException implements Exception {
  final String message;

  const AIModelException({required this.message});

  @override
  String toString() => 'AIModelException: $message';
}

/// 无障碍服务异常
class AccessibilityServiceException implements Exception {
  final String message;

  const AccessibilityServiceException({
    this.message = '无障碍服务不可用',
  });

  @override
  String toString() => 'AccessibilityServiceException: $message';
}
