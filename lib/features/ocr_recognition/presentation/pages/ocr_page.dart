import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../../../../core/camera/camera_session.dart';
import '../../../../core/tts/safe_tts.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/status_card.dart';

class OcrPage extends ConsumerStatefulWidget {
  const OcrPage({super.key});

  @override
  ConsumerState<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends ConsumerState<OcrPage>
    with WidgetsBindingObserver {
  CameraInitResult? _camResult;
  TextRecognizer? _recognizer;
  final SafeTts _tts = SafeTts();
  bool _initializing = true;
  bool _busy = false;
  String _result = '';

  CameraController? get _camera => _camResult?.controller;
  bool get _ready => _camResult?.isSuccess == true && _camera != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.init(); // fire-and-forget，不阻塞
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && !_ready && !_initializing) _init();
  }

  Future<void> _init() async {
    if (mounted) setState(() => _initializing = true);

    final result =
        await CameraSession.initCamera(resolution: ResolutionPreset.high);

    if (!mounted) {
      result.controller?.dispose();
      return;
    }

    setState(() {
      _camResult?.controller?.dispose();
      _camResult = result;
      _initializing = false;
    });

    if (result.isSuccess) {
      try {
        _recognizer?.close();
        // 用默认 latin 脚本——它也能识别中文数字
        // TextRecognitionScript.chinese 需要额外的 ML Kit 中文包，缺包会崩溃
        _recognizer = TextRecognizer();
      } catch (e) {
        debugPrint('TextRecognizer 创建失败: $e');
      }
    }
  }

  Future<void> _capture() async {
    HapticFeedback.mediumImpact();
    if (!_ready || _busy) return;
    if (_recognizer == null) {
      // 尝试重建
      try {
        _recognizer = TextRecognizer();
      } catch (e) {
        if (mounted) {
          setState(() => _result = '文字识别引擎加载失败：$e');
        }
        return;
      }
    }
    setState(() {
      _busy = true;
      _result = '';
    });
    await _tts.stop();
    try {
      final pic =
          await _camera!.takePicture().timeout(const Duration(seconds: 5));
      final input = InputImage.fromFilePath(pic.path);
      final text = await _recognizer!
          .processImage(input)
          .timeout(const Duration(seconds: 10));
      final r = text.text.trim();
      if (mounted) {
        setState(() {
          _result = r.isEmpty ? '未识别到文字，请调整角度后重试' : r;
          _busy = false;
        });
      }
      if (r.isNotEmpty) {
        _tts.speak('识别到：$r');
      } else {
        _tts.speak('未识别到文字');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = '识别出错：$e';
          _busy = false;
        });
      }
      _tts.speak('识别出错，请重试');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _recognizer?.close();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('文字识别'),
        actions: [
          IconButton(
            tooltip: '重新初始化',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _init,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: _ready ? Colors.black : AppTheme.background,
                    child: _buildPreview(),
                  ),
                ),
              ),
            ),
            if (_ready && _result.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.channelText.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.text_snippet_rounded,
                            color: AppTheme.channelText, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('识别结果',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text(_result,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_ready)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 76,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _capture,
                    icon: Icon(
                      _busy ? Icons.hourglass_bottom : Icons.camera,
                      size: 28,
                    ),
                    label: Text(
                      _busy ? '识别中…' : '拍照识别',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.channelText,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_initializing) {
      return Container(
        color: Colors.black,
        child: const LoadingPlaceholder(
          message: '正在启动摄像头…',
          color: Colors.white,
        ),
      );
    }
    if (_ready && _camera != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_camera!),
          Center(
            child: Container(
              margin: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                border:
                    Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      );
    }
    return StatusCard.error(
      title: _camResult?.message ?? '初始化失败',
      description: '请点重试，如反复失败请检查摄像头权限',
      detail: _camResult?.detail ?? '',
      onRetry: _init,
      onOpenSettings: () async => await openAppSettings(),
    );
  }
}
