import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/voice_interaction/presentation/providers/voice_provider.dart';
import '../dispatcher/command_dispatcher.dart';

/// 全局语音浮动操作按钮
/// 
/// 悬浮在所有页面上，用户可以随时长按唤起语音指令。
/// 支持三种交互方式：
/// 1. 单击：开始/停止语音识别
/// 2. 长按：重复上一次播报
/// 
/// 注意：此 Widget 返回普通 Widget（不是 Positioned），外层由 app.dart 统一用 Align 放置。
class VoiceFloatingButton extends ConsumerStatefulWidget {
  const VoiceFloatingButton({super.key});

  @override
  ConsumerState<VoiceFloatingButton> createState() => _VoiceFloatingButtonState();
}

class _VoiceFloatingButtonState extends ConsumerState<VoiceFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceNotifierProvider);

    // 监听指令变化，自动调度
    ref.listen<VoiceUiState>(voiceNotifierProvider, (previous, next) {
      if (next.lastCommand != null &&
          next.lastCommand != previous?.lastCommand) {
        ref.read(commandDispatcherProvider).dispatch(next.lastCommand!);
      }
    });

    // 控制脉冲动画
    if (voiceState.state == VoiceInteractionState.listening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }

    // 不返回 Positioned，由 app.dart 的 Align 放置
    return Semantics(
      label: _getSemanticLabel(voiceState),
      hint: '单击开始语音指令，长按重复上次播报',
      button: true,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: voiceState.state == VoiceInteractionState.listening
                ? _pulseAnimation.value
                : 1.0,
            child: child,
          );
        },
        child: GestureDetector(
          onLongPress: () {
            ref.read(voiceNotifierProvider.notifier).repeatLast();
          },
          child: FloatingActionButton.large(
            heroTag: 'voice_fab',
            backgroundColor: _getButtonColor(voiceState),
            onPressed: () => _handleTap(voiceState),
            child: Icon(
              _getButtonIcon(voiceState),
              size: 36,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(VoiceUiState voiceState) {
    if (voiceState.state == VoiceInteractionState.listening) {
      ref.read(voiceNotifierProvider.notifier).stopListening();
    } else if (voiceState.isSpeaking) {
      ref.read(voiceNotifierProvider.notifier).stopSpeaking();
    } else {
      ref.read(voiceNotifierProvider.notifier).startListening();
    }
  }

  String _getSemanticLabel(VoiceUiState state) {
    return switch (state.state) {
      VoiceInteractionState.idle => '语音助手',
      VoiceInteractionState.listening => '正在听取语音指令',
      VoiceInteractionState.processing => '正在处理语音',
      VoiceInteractionState.speaking => '正在播报',
      VoiceInteractionState.error => '语音助手出错',
    };
  }

  Color _getButtonColor(VoiceUiState state) {
    return switch (state.state) {
      VoiceInteractionState.listening => const Color(0xFFC62828),
      VoiceInteractionState.processing => const Color(0xFFE65100),
      VoiceInteractionState.speaking => const Color(0xFF1565C0),
      VoiceInteractionState.error => Colors.grey,
      _ => const Color(0xFF6A1B9A),
    };
  }

  IconData _getButtonIcon(VoiceUiState state) {
    return switch (state.state) {
      VoiceInteractionState.listening => Icons.mic,
      VoiceInteractionState.processing => Icons.hourglass_top,
      VoiceInteractionState.speaking => Icons.volume_up,
      VoiceInteractionState.error => Icons.mic_off,
      _ => Icons.mic_none,
    };
  }
}
