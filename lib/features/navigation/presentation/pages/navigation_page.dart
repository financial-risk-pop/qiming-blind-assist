import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/amap_nav_service.dart';
import '../../../../core/speech/native_speech.dart';
import '../../../../core/tts/safe_tts.dart';
import '../../../../shared/theme/app_theme.dart';

class NavigationPage extends ConsumerStatefulWidget {
  const NavigationPage({super.key});

  @override
  ConsumerState<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends ConsumerState<NavigationPage> {
  final SafeTts _tts = SafeTts();
  final NativeSpeech _speech = NativeSpeech();
  final TextEditingController _textCtl = TextEditingController();

  bool _planning = false;
  bool _speechAvailable = false;
  bool _intentAvailable = false;
  NavResult? _routeResult;
  String? _currentAddress;

  static const _quickDests = [
    '最近的医院', '最近的超市', '最近的地铁站',
    '最近的公交站', '最近的药店', '最近的银行',
  ];

  @override
  void initState() {
    super.initState();
    _tts.init();
    _checkSpeech();
    _loadCurrentAddress();
  }

  Future<void> _checkSpeech() async {
    final sr = await NativeSpeech.isAvailable();
    final intent = await NativeSpeech.isIntentAvailable();
    if (mounted) {
      setState(() {
        _speechAvailable = sr;
        _intentAvailable = intent;
      });
    }
  }

  Future<void> _loadCurrentAddress() async {
    final pos = await AmapNavService.getCurrentLocation();
    if (pos != null && mounted) {
      final addr =
          await AmapNavService.reverseGeocode(pos.longitude, pos.latitude);
      if (mounted) setState(() => _currentAddress = addr);
    }
  }

  Future<void> _planRoute(String dest) async {
    if (_planning || dest.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() {
      _planning = true;
      _routeResult = null;
    });
    _tts.speak('正在为您规划到$dest的路线');

    final result = await AmapNavService.navigate(dest.trim());

    if (!mounted) return;
    setState(() {
      _routeResult = result;
      _planning = false;
    });
    // 自动播报路线
    _tts.speak(result.speakText);
  }

  void _onSubmit() {
    final text = _textCtl.text.trim();
    if (text.isEmpty) return;
    _planRoute(text);
    _textCtl.clear();
  }

  /// 语音输入——直接尝试启动，不管 isAvailable
  Future<void> _voiceInput() async {
    HapticFeedback.mediumImpact();
    _tts.speak('请说出目的地');
    await Future.delayed(const Duration(milliseconds: 1200));

    // 设置回调
    _speech.onResult = (text) {
      if (text.isNotEmpty && mounted) _planRoute(text);
    };
    _speech.onError = (err) {
      if (!mounted) return;
      _tts.speak('语音识别失败，请用键盘输入');
    };

    // 直接尝试启动（某些手机 isAvailable=false 但实际能用）
    try {
      await _speech.startListening();
    } catch (_) {
      // 备选：Intent 方式
      try {
        final text = await _speech.startListeningWithIntent();
        if (text != null && text.isNotEmpty && mounted) {
          _planRoute(text);
        }
      } catch (_) {
        _tts.speak('语音识别不可用，请用键盘输入');
      }
    }
  }

  @override
  void dispose() {
    _speech.dispose();
    _tts.dispose();
    _textCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVoice = true; // 始终显示语音按钮，让用户尝试

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('语音导航')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 当前位置
              if (_currentAddress != null)
                _card(
                  child: Row(children: [
                    const Icon(Icons.my_location,
                        color: AppTheme.channelNavi, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('当前位置：$_currentAddress',
                          style: const TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),

              const SizedBox(height: 12),

              // 搜索框 + 语音按钮
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.08),
                      blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppTheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _textCtl,
                        decoration: const InputDecoration(
                          hintText: '输入目的地',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        style: const TextStyle(fontSize: 18),
                        onSubmitted: (_) => _onSubmit(),
                      ),
                    ),
                    // 语音按钮
                    if (hasVoice)
                      IconButton(
                        onPressed: _planning ? null : _voiceInput,
                        icon: const Icon(Icons.mic_rounded),
                        color: AppTheme.channelNavi,
                        iconSize: 28,
                        tooltip: '语音输入',
                      ),
                    // 搜索按钮
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _planning ? null : _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.channelNavi,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: Text(_planning ? '规划中' : '导航',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 语音大按钮（如果可用）
              if (hasVoice)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity, height: 64,
                    child: ElevatedButton.icon(
                      onPressed: _planning ? null : _voiceInput,
                      icon: const Icon(Icons.mic_rounded, size: 28),
                      label: const Text('按住说出目的地',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),

              // 快捷目的地
              const Text('常用目的地',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _quickDests.map((dest) {
                  return ActionChip(
                    label: Text(dest, style: const TextStyle(fontSize: 15)),
                    avatar: const Icon(Icons.place, size: 18),
                    onPressed: _planning ? null : () => _planRoute(dest),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color: AppTheme.channelNavi.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // 规划中
              if (_planning)
                _card(
                  child: const Column(children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在规划路线…',
                        style: TextStyle(fontSize: 18,
                            color: AppTheme.textSecondary)),
                  ]),
                ),

              // 路线结果
              if (_routeResult != null && !_planning)
                _buildRouteResult(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: child,
    );
  }

  Widget _buildRouteResult() {
    final r = _routeResult!;
    final color = r.success ? AppTheme.channelNavi : AppTheme.danger;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(
                  r.success ? Icons.directions_walk : Icons.error_outline,
                  color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(r.success ? '步行路线' : '规划失败',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: color)),
            ),
            if (r.success)
              IconButton(
                onPressed: () => _tts.speak(r.speakText),
                icon: const Icon(Icons.volume_up_rounded, size: 28),
                color: color,
                tooltip: '播报路线',
              ),
          ]),
          const SizedBox(height: 12),
          if (r.success) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12)),
              child: Text(r.summary,
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w600, height: 1.5)),
            ),
            const SizedBox(height: 16),
            ...r.stepsText.split('\n').where((s) => s.isNotEmpty).map((step) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 8, height: 8,
                          margin: const EdgeInsets.only(top: 7),
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(step,
                          style: const TextStyle(fontSize: 15, height: 1.5))),
                    ]),
              );
            }),
          ] else
            Text(r.errorMsg ?? '未知错误',
                style: const TextStyle(fontSize: 16, color: AppTheme.danger)),
        ],
      ),
    );
  }
}
