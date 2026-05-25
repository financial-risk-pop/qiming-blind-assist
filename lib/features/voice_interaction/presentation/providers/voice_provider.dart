import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/voice_command.dart';
import '../../data/datasources/voice_data_source.dart';
import '../../data/repositories/voice_repository_impl.dart';
import '../../../../core/event_bus/event_bus.dart';
import '../../../../core/utils/logger.dart';

/// 语音交互状态枚举（UI 层用）
/// 
/// 与 domain 层的 [VoiceState] 不同，这是 UI 展示用的精简状态机。
enum VoiceInteractionState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

/// 语音 UI 状态（注意：与 domain 层的 [VoiceState] 枚举区分）
class VoiceUiState {
  final VoiceInteractionState state;
  final String? recognizedText;
  final String? partialText;
  final VoiceCommand? lastCommand;
  final String? errorMessage;
  final bool isSpeaking;

  const VoiceUiState({
    this.state = VoiceInteractionState.idle,
    this.recognizedText,
    this.partialText,
    this.lastCommand,
    this.errorMessage,
    this.isSpeaking = false,
  });

  /// copyWith 支持显式清除 nullable 字段为 null
  /// 传入 _sentinel 表示不修改，传入 null 表示清除
  VoiceUiState copyWith({
    VoiceInteractionState? state,
    Object? recognizedText = _sentinel,
    Object? partialText = _sentinel,
    Object? lastCommand = _sentinel,
    Object? errorMessage = _sentinel,
    bool? isSpeaking,
  }) {
    return VoiceUiState(
      state: state ?? this.state,
      recognizedText: recognizedText == _sentinel
          ? this.recognizedText
          : recognizedText as String?,
      partialText: partialText == _sentinel
          ? this.partialText
          : partialText as String?,
      lastCommand: lastCommand == _sentinel
          ? this.lastCommand
          : lastCommand as VoiceCommand?,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

/// Sentinel 值，用于区分"未传参"和"传入 null"
const Object _sentinel = Object();

/// 语音交互Notifier
class VoiceNotifier extends StateNotifier<VoiceUiState> {
  final VoiceRepositoryImpl _repository;
  final EventBus _eventBus;

  StreamSubscription? _speakRequestSubscription;
  StreamSubscription? _stateSubscription;

  VoiceNotifier({
    required VoiceRepositoryImpl repository,
    required EventBus eventBus,
  })  : _repository = repository,
        _eventBus = eventBus,
        super(const VoiceUiState()) {
    _listenToSpeakRequests();
    _listenToVoiceState();
  }

  /// 监听数据源状态流，同步 isSpeaking（TTS 播完自动恢复 false）
  void _listenToVoiceState() {
    _stateSubscription = _repository.stateStream.listen(
      (voiceState) {
        if (!mounted) return;
        switch (voiceState) {
          case VoiceState.idle:
            // TTS 播完或 ASR 停止时，恢复 isSpeaking 为 false
            if (state.isSpeaking) {
              state = state.copyWith(isSpeaking: false);
            }
            break;
          case VoiceState.speaking:
            if (!state.isSpeaking) {
              state = state.copyWith(isSpeaking: true);
            }
            break;
          default:
            break;
        }
      },
      onError: (_) {},
    );
  }

  /// 监听事件总线上的播报请求
  void _listenToSpeakRequests() {
    _speakRequestSubscription = _eventBus.on<SpeakRequestEvent>().listen(
      (event) {
        final priority = switch (event.priority) {
          FeedbackPriority.critical => 10,
          FeedbackPriority.navigation => 5,
          FeedbackPriority.information => 1,
        };

        _repository.speakWithPriority(
          event.text,
          priority: priority,
          interruptCurrent: event.interruptCurrent,
        );

        state = state.copyWith(isSpeaking: true);
      },
    );
  }

  /// 初始化语音服务
  /// 失败不进入 error 状态，让用户后续仍能尝试使用（权限授予后会自动生效）
  Future<void> initialize() async {
    try {
      await _repository.initialize();
      AppLogger.info('语音Notifier初始化完成', tag: 'VoiceNotifier');
    } catch (e) {
      AppLogger.warning('语音服务初始化失败（可忽略，后续调用会重试）: $e',
          tag: 'VoiceNotifier');
    }
  }

  /// 开始语音识别
  Future<void> startListening() async {
    try {
      state = state.copyWith(
        state: VoiceInteractionState.listening,
        partialText: null,
        recognizedText: null,
        errorMessage: null,
      );

      final result = await _repository.recognizeSpeech(
        timeout: const Duration(seconds: 10),
      );

      if (!mounted) return;

      if (result.isNotEmpty) {
        state = state.copyWith(
          state: VoiceInteractionState.processing,
          recognizedText: result,
        );

        // 解析指令
        final command = _repository.parseCommand(result);
        if (command != null) {
          state = state.copyWith(
            state: VoiceInteractionState.idle,
            lastCommand: command,
          );
        } else {
          // 未识别到有效指令
          await _repository.speak('没有理解您的指令，请再说一遍', interrupt: true);
          state = state.copyWith(state: VoiceInteractionState.idle);
        }
      } else {
        await _repository.speak('没有听到您说话', interrupt: true);
        state = state.copyWith(state: VoiceInteractionState.idle);
      }
    } catch (e) {
      AppLogger.error('语音识别出错', tag: 'VoiceNotifier', error: e);
      if (!mounted) return;
      state = state.copyWith(
        state: VoiceInteractionState.idle,
        errorMessage: '语音识别出错',
      );
    }
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    try {
      await _repository.stopListening();
    } catch (e) {
      AppLogger.error('停止语音识别出错', tag: 'VoiceNotifier', error: e);
    }
    if (mounted) {
      state = state.copyWith(state: VoiceInteractionState.idle);
    }
  }

  /// 直接播报文本
  Future<void> speak(String text, {bool interrupt = false}) async {
    try {
      await _repository.speak(text, interrupt: interrupt);
      if (mounted) {
        state = state.copyWith(isSpeaking: true);
      }
    } catch (e) {
      AppLogger.error('播报出错', tag: 'VoiceNotifier', error: e);
    }
  }

  /// 停止播报
  Future<void> stopSpeaking() async {
    try {
      await _repository.stopSpeaking();
    } catch (e) {
      AppLogger.error('停止播报出错', tag: 'VoiceNotifier', error: e);
    }
    if (mounted) {
      state = state.copyWith(isSpeaking: false);
    }
  }

  /// 重复上一次播报
  Future<void> repeatLast() async {
    try {
      await _repository.repeatLast();
    } catch (e) {
      AppLogger.error('重复播报出错', tag: 'VoiceNotifier', error: e);
    }
  }

  /// 更新TTS语速
  Future<void> updateSpeechRate(double rate) async {
    try {
      await _repository.updateSpeechRate(rate);
    } catch (e) {
      AppLogger.error('更新语速出错', tag: 'VoiceNotifier', error: e);
    }
  }

  /// 更新TTS音量
  Future<void> updateVolume(double volume) async {
    try {
      await _repository.updateVolume(volume);
    } catch (e) {
      AppLogger.error('更新音量出错', tag: 'VoiceNotifier', error: e);
    }
  }

  @override
  void dispose() {
    _speakRequestSubscription?.cancel();
    _stateSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}

/// ========== Providers ==========

/// 事件总线Provider（全局单例）
final eventBusProvider = Provider<EventBus>((ref) {
  final bus = EventBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});

/// 语音数据源Provider
final voiceDataSourceProvider = Provider<VoiceDataSource>((ref) {
  final ds = VoiceDataSource();
  ref.onDispose(() => ds.dispose());
  return ds;
});

/// 语音仓库Provider
final voiceRepositoryProvider = Provider<VoiceRepositoryImpl>((ref) {
  final dataSource = ref.watch(voiceDataSourceProvider);
  final repo = VoiceRepositoryImpl(dataSource: dataSource);
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// 语音交互状态Provider
final voiceNotifierProvider =
    StateNotifierProvider<VoiceNotifier, VoiceUiState>((ref) {
  final repository = ref.watch(voiceRepositoryProvider);
  final eventBus = ref.watch(eventBusProvider);
  return VoiceNotifier(repository: repository, eventBus: eventBus);
});
