import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:vibration/vibration.dart';

import '../../../../core/camera/camera_session.dart';
import '../../../../core/tts/safe_tts.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/status_card.dart';

class ObstacleDetailPage extends ConsumerStatefulWidget {
  const ObstacleDetailPage({super.key});

  @override
  ConsumerState<ObstacleDetailPage> createState() => _ObstacleDetailPageState();
}

class _ObstacleDetailPageState extends ConsumerState<ObstacleDetailPage>
    with WidgetsBindingObserver {
  CameraInitResult? _camResult;
  final SafeTts _tts = SafeTts();
  ImageLabeler? _labeler;
  Timer? _timer;
  bool _initializing = true;
  bool _detecting = false;
  String _currentObstacle = '等待开始检测';
  int _scanCount = 0;

  CameraController? get _camera => _camResult?.controller;
  bool get _ready => _camResult?.isSuccess == true && _camera != null;

  // 危险物体标签
  static const _dangerLabels = {
    'Person', 'Man', 'Woman', 'Child', 'People',
    'Car', 'Vehicle', 'Truck', 'Bus', 'Motorcycle', 'Bicycle',
    'Dog', 'Cat', 'Animal',
    'Stairs', 'Step', 'Wall', 'Pole', 'Fence', 'Barrier',
    'Table', 'Chair', 'Furniture',
  };
  static const _labelZh = {
    'Person': '行人', 'Man': '行人', 'Woman': '行人', 'Child': '儿童',
    'People': '人群', 'Car': '汽车', 'Vehicle': '车辆', 'Truck': '卡车',
    'Bus': '公交车', 'Motorcycle': '摩托车', 'Bicycle': '自行车',
    'Dog': '狗', 'Cat': '猫', 'Animal': '动物',
    'Stairs': '台阶', 'Step': '台阶', 'Wall': '墙壁', 'Pole': '柱子',
    'Fence': '围栏', 'Barrier': '障碍物',
    'Table': '桌子', 'Chair': '椅子', 'Furniture': '家具',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.init();
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && !_ready && !_initializing) _init();
  }

  Future<void> _init() async {
    if (mounted) setState(() => _initializing = true);
    final result = await CameraSession.initCamera(resolution: ResolutionPreset.medium);
    if (!mounted) { result.controller?.dispose(); return; }
    setState(() {
      _camResult?.controller?.dispose();
      _camResult = result;
      _initializing = false;
    });
  }

  Future<void> _toggle() async {
    HapticFeedback.mediumImpact();
    if (!_ready) return;
    if (_detecting) {
      _timer?.cancel();
      _timer = null;
      await _tts.stop();
      setState(() { _detecting = false; _currentObstacle = '已停止'; });
      _tts.speak('障碍物检测已停止');
    } else {
      setState(() { _detecting = true; _scanCount = 0; _currentObstacle = '检测中…'; });
      _tts.speak('障碍物检测已开启，请将手机对准前方');
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _emit());
    }
  }

  Future<void> _emit() async {
    if (!_detecting || !mounted || _camera == null) return;
    _scanCount++;

    try {
      final pic = await _camera!.takePicture().timeout(const Duration(seconds: 3));
      final inputImage = InputImage.fromFilePath(pic.path);

      _labeler ??= ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.4));
      final labels = await _labeler!.processImage(inputImage)
          .timeout(const Duration(seconds: 5));

      // 找危险物体
      final dangers = labels.where((l) => _dangerLabels.contains(l.label)).toList();

      String obstacle;
      if (dangers.isNotEmpty) {
        final top = dangers.first;
        final name = _labelZh[top.label] ?? top.label;
        obstacle = '注意！前方检测到$name';
      } else if (labels.isNotEmpty) {
        final names = labels.take(2).map((l) => _labelZh[l.label] ?? l.label).join('、');
        obstacle = '前方安全，检测到$names';
      } else {
        obstacle = '前方安全';
      }

      try { await File(pic.path).delete(); } catch (_) {}

      if (!mounted) return;
      setState(() => _currentObstacle = obstacle);

      if (dangers.isNotEmpty) {
        _tts.speak(obstacle);
        try {
          final v = await Vibration.hasVibrator();
          if (v == true) Vibration.vibrate(duration: 300);
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) setState(() => _currentObstacle = '扫描中…');
    }
  }

  bool get _isSafe => _currentObstacle.contains('前方安全') || _currentObstacle.contains('等待') || _currentObstacle.contains('扫描');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _camera?.dispose();
    _labeler?.close();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('障碍检测'),
        actions: [
          IconButton(tooltip: '重新初始化', icon: const Icon(Icons.refresh_rounded), onPressed: _init),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
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
          if (_ready)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity, height: 76,
                child: ElevatedButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_detecting ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 32),
                  label: Text(_detecting ? '停止检测' : '开始检测',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _detecting ? AppTheme.danger : AppTheme.channelObstacle,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildPreview() {
    if (_initializing) {
      return Container(color: Colors.black, child: const LoadingPlaceholder(message: '正在启动摄像头…', color: Colors.white));
    }
    if (_ready && _camera != null) {
      return Stack(fit: StackFit.expand, children: [
        CameraPreview(_camera!),
        Positioned(
          top: 16, left: 16, right: 16,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _detecting
                  ? (_isSafe ? AppTheme.success.withOpacity(0.92) : AppTheme.danger.withOpacity(0.92))
                  : Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Icon(
                _detecting ? (_isSafe ? Icons.check_circle : Icons.warning_amber) : Icons.pause_circle_outline,
                color: Colors.white, size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_currentObstacle,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ]);
    }
    return StatusCard.error(
      title: _camResult?.message ?? '初始化失败',
      description: '请点重试',
      detail: _camResult?.detail ?? '',
      onRetry: _init,
      onOpenSettings: () async => await openAppSettings(),
    );
  }
}

class ObstacleDetectionOverlay extends StatelessWidget {
  const ObstacleDetectionOverlay({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
