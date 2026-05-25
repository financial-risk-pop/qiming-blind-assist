import 'dart:ui';

import '../entities/app_info.dart';
import '../entities/screen_element.dart';
import '../entities/screen_read_result.dart';
import '../repositories/screen_reader_repository.dart';

/// 读取当前屏幕用例
class ReadCurrentScreenUseCase {
  final ScreenReaderRepository _repository;

  ReadCurrentScreenUseCase(this._repository);

  Future<ScreenReadResult> call() {
    return _repository.readCurrentScreen();
  }
}

/// 获取App信息用例
class GetAppInfoUseCase {
  final ScreenReaderRepository _repository;

  GetAppInfoUseCase(this._repository);

  Future<AppInfo> call() {
    return _repository.getCurrentAppInfo();
  }
}

/// 读取指定位置元素详情用例
class ReadElementDetailUseCase {
  final ScreenReaderRepository _repository;

  ReadElementDetailUseCase(this._repository);

  Future<ScreenElement?> call(Offset position) {
    return _repository.readElementAt(position);
  }
}

/// 搜索页面元素用例
class FindElementUseCase {
  final ScreenReaderRepository _repository;

  FindElementUseCase(this._repository);

  /// [query] 搜索关键词，如"付款"、"扫一扫"
  Future<List<ScreenElement>> call(String query) {
    return _repository.findElements(query);
  }
}

/// 执行操作用例（代理用户点击/滑动等）
class PerformActionUseCase {
  final ScreenReaderRepository _repository;

  PerformActionUseCase(this._repository);

  Future<bool> call(String elementId, AccessibilityAction action) {
    return _repository.performAction(elementId, action);
  }
}
