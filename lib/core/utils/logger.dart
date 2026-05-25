import 'package:logger/logger.dart' as log_lib;

/// 全局日志工具
/// 
/// 统一日志输出格式，方便调试和问题排查
class AppLogger {
  static final log_lib.Logger _logger = log_lib.Logger(
    printer: log_lib.PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: log_lib.DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// 调试日志
  static void debug(String message, {String? tag}) {
    _logger.d('${tag != null ? '[$tag] ' : ''}$message');
  }

  /// 信息日志
  static void info(String message, {String? tag}) {
    _logger.i('${tag != null ? '[$tag] ' : ''}$message');
  }

  /// 警告日志
  static void warning(String message, {String? tag}) {
    _logger.w('${tag != null ? '[$tag] ' : ''}$message');
  }

  /// 错误日志
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _logger.e(
      '${tag != null ? '[$tag] ' : ''}$message',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
