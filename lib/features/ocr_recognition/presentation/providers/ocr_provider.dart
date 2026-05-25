import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ocr_result.dart';
import '../../data/datasources/ocr_data_source.dart';
import '../../data/repositories/ocr_repository_impl.dart';
import '../../../../core/network/network_info.dart';
import '../../../voice_interaction/presentation/providers/voice_provider.dart';

/// OCR识别状态
class OcrState {
  final OcrPageStatus status;
  final OcrResult? lastResult;
  final bool isRealTimeActive;
  final String? errorMessage;

  const OcrState({
    this.status = OcrPageStatus.idle,
    this.lastResult,
    this.isRealTimeActive = false,
    this.errorMessage,
  });

  OcrState copyWith({
    OcrPageStatus? status,
    OcrResult? lastResult,
    bool? isRealTimeActive,
    String? errorMessage,
  }) {
    return OcrState(
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
      isRealTimeActive: isRealTimeActive ?? this.isRealTimeActive,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// OCR页面状态枚举
enum OcrPageStatus {
  idle,
  recognizing,
  realTime,
  error,
}

/// OCR Notifier
class OcrNotifier extends StateNotifier<OcrState> {
  final OcrRepositoryImpl _repository;
  StreamSubscription? _realTimeSubscription;

  OcrNotifier({required OcrRepositoryImpl repository})
      : _repository = repository,
        super(const OcrState());

  /// 初始化
  Future<void> initialize() async {
    try {
      await _repository.initialize();
    } catch (e) {
      state = state.copyWith(
        status: OcrPageStatus.error,
        errorMessage: 'OCR初始化失败',
      );
    }
  }

  /// 拍照识别
  Future<void> recognizeFromCamera({OcrMode mode = OcrMode.auto}) async {
    try {
      state = state.copyWith(status: OcrPageStatus.recognizing);
      final result = await _repository.recognizeFromCamera(mode: mode);
      state = state.copyWith(
        status: OcrPageStatus.idle,
        lastResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        status: OcrPageStatus.error,
        errorMessage: '识别失败: $e',
      );
    }
  }

  /// 开始实时识别
  Future<void> startRealTimeOcr() async {
    try {
      state = state.copyWith(
        status: OcrPageStatus.realTime,
        isRealTimeActive: true,
      );

      _realTimeSubscription?.cancel();
      _realTimeSubscription = _repository.startRealTimeOcr().listen(
        (result) {
          state = state.copyWith(lastResult: result);
        },
        onError: (error) {
          state = state.copyWith(
            status: OcrPageStatus.error,
            errorMessage: '实时识别出错',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: OcrPageStatus.error,
        errorMessage: '启动实时识别失败',
      );
    }
  }

  /// 停止实时识别
  Future<void> stopRealTimeOcr() async {
    _realTimeSubscription?.cancel();
    try {
      await _repository.stopRealTimeOcr();
    } catch (_) {
      // 即使 stop 出错也要更新状态
    }
    state = state.copyWith(
      status: OcrPageStatus.idle,
      isRealTimeActive: false,
    );
  }

  @override
  void dispose() {
    _realTimeSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}

/// ========== Providers ==========

/// 网络信息Provider
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfo();
});

/// OCR数据源Provider
final ocrDataSourceProvider = Provider<OcrDataSource>((ref) {
  final ds = OcrDataSource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

/// OCR仓库Provider
final ocrRepositoryProvider = Provider<OcrRepositoryImpl>((ref) {
  final dataSource = ref.watch(ocrDataSourceProvider);
  final eventBus = ref.watch(eventBusProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return OcrRepositoryImpl(
    dataSource: dataSource,
    eventBus: eventBus,
    networkInfo: networkInfo,
  );
});

/// OCR状态Provider
final ocrNotifierProvider =
    StateNotifierProvider<OcrNotifier, OcrState>((ref) {
  final repository = ref.watch(ocrRepositoryProvider);
  return OcrNotifier(repository: repository);
});
