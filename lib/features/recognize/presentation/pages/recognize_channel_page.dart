import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../../../../core/camera/camera_session.dart';
import '../../../../core/tts/safe_tts.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/status_card.dart';

/// 识别频道类型
enum ChannelType {
  money(
    '识别钞票',
    '将钞票放在画面中央，保持平整',
    AppTheme.channelMoney,
    Icons.payments_rounded,
  ),
  color(
    '识别颜色',
    '将物品对准画面中央',
    AppTheme.channelColor,
    Icons.color_lens_rounded,
  ),
  light(
    '识别光线',
    '把镜头对准要测的方向',
    AppTheme.channelLight,
    Icons.wb_sunny_rounded,
  ),
  scene(
    '识别场景',
    '把镜头对准前方的场景',
    AppTheme.channelScene,
    Icons.image_search_rounded,
  );

  final String title;
  final String hint;
  final Color themeColor;
  final IconData icon;
  const ChannelType(this.title, this.hint, this.themeColor, this.icon);
}

/// 通用识别频道页 - 共享摄像头管线
class RecognizeChannelPage extends ConsumerStatefulWidget {
  final ChannelType type;
  const RecognizeChannelPage({super.key, required this.type});

  @override
  ConsumerState<RecognizeChannelPage> createState() =>
      _RecognizeChannelPageState();
}

class _RecognizeChannelPageState extends ConsumerState<RecognizeChannelPage>
    with WidgetsBindingObserver {
  CameraInitResult? _cameraResult;
  final SafeTts _tts = SafeTts();
  ImageLabeler? _labeler;
  bool _initializing = true;
  bool _busy = false;
  String _result = '';

  CameraController? get _camera => _cameraResult?.controller;
  bool get _ready => _cameraResult?.isSuccess == true && _camera != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_ready && !_initializing) {
      _init();
    }
  }

  Future<void> _init() async {
    if (mounted) setState(() => _initializing = true);

    _tts.init();

    // 摄像头初始化（带超时）
    final result = await CameraSession.initCamera(
      resolution: ResolutionPreset.medium,
    );

    if (!mounted) {
      // 页面已销毁，立即释放
      result.controller?.dispose();
      return;
    }

    setState(() {
      // 释放之前的 controller
      _cameraResult?.controller?.dispose();
      _cameraResult = result;
      _initializing = false;
    });
  }

  // （TTS 已在 SafeTts 中自动初始化）

  Future<void> _capture() async {
    HapticFeedback.mediumImpact();
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _result = '';
    });
    await _tts.stop();

    try {
      final pic = await _camera!.takePicture().timeout(
            const Duration(seconds: 5),
          );
      final bytes = await pic.readAsBytes();
      String result;
      switch (widget.type) {
        case ChannelType.color:
          result = await _analyzeColor(bytes);
          break;
        case ChannelType.light:
          result = await _analyzeLight(bytes);
          break;
        case ChannelType.money:
          result = await _analyzeMoney(bytes);
          break;
        case ChannelType.scene:
          result = await _analyzeScene(bytes);
          break;
      }
      if (mounted) {
        setState(() {
          _result = result;
          _busy = false;
        });
      }
      await _tts.speak(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = '识别出错：$e';
          _busy = false;
        });
      }
    }
  }

  // ============= 识别算法 =============

  Future<String> _analyzeColor(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      image.dispose();
      return '识别失败';
    }
    final pixels = byteData.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    int rSum = 0, gSum = 0, bSum = 0, count = 0;
    final cx0 = (w * 0.35).toInt();
    final cx1 = (w * 0.65).toInt();
    final cy0 = (h * 0.35).toInt();
    final cy1 = (h * 0.65).toInt();
    for (int y = cy0; y < cy1; y += 4) {
      for (int x = cx0; x < cx1; x += 4) {
        final i = (y * w + x) * 4;
        rSum += pixels[i];
        gSum += pixels[i + 1];
        bSum += pixels[i + 2];
        count++;
      }
    }
    image.dispose();
    if (count == 0) return '识别失败';
    final r = rSum ~/ count;
    final g = gSum ~/ count;
    final b = bSum ~/ count;
    return '主要颜色是${_colorNameOf(r, g, b)}';
  }

  Future<String> _analyzeLight(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      image.dispose();
      return '识别失败';
    }
    final pixels = byteData.buffer.asUint8List();
    int brightness = 0, count = 0;
    for (int i = 0; i < pixels.length; i += 16) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      brightness += ((r * 299 + g * 587 + b * 114) / 1000).toInt();
      count++;
    }
    image.dispose();
    final avg = brightness / count;
    String desc;
    if (avg < 30) {
      desc = '非常暗，几乎没有光线';
    } else if (avg < 70) {
      desc = '光线较暗，建议开灯';
    } else if (avg < 130) {
      desc = '光线柔和，比较舒适';
    } else if (avg < 200) {
      desc = '光线明亮';
    } else {
      desc = '光线很强';
    }
    return desc;
  }

  Future<String> _analyzeMoney(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      image.dispose();
      return '识别失败';
    }
    final pixels = byteData.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    int rSum = 0, gSum = 0, bSum = 0, count = 0;
    for (int y = (h * 0.2).toInt(); y < h * 0.8; y += 4) {
      for (int x = (w * 0.2).toInt(); x < w * 0.8; x += 4) {
        final i = (y * w + x) * 4;
        rSum += pixels[i];
        gSum += pixels[i + 1];
        bSum += pixels[i + 2];
        count++;
      }
    }
    image.dispose();
    final r = rSum ~/ count;
    final g = gSum ~/ count;
    final b = bSum ~/ count;
    String denom;
    if (r > 130 && r > g + 30 && r > b + 20) {
      denom = '一百元，红色为主';
    } else if (g > 100 && g > r && g > b - 10 && r < 130) {
      denom = '可能是五十元或一元（绿色）';
    } else if (b > 110 && b > r && b > g) {
      denom = '十元，蓝色为主';
    } else if (r > 100 && g < r && b < r && r < 160) {
      denom = '二十元，棕色为主';
    } else if (r > 100 && b > 100 && g < r) {
      denom = '五元，紫色为主';
    } else {
      denom = '无法确定，请放近一点重新拍摄';
    }
    return '$denom。提示：本功能为简易版';
  }

  Future<String> _analyzeScene(Uint8List bytes) async {
    // ML Kit 图片标签识别
    _labeler ??= ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));

    // 先拿到文件路径（ML Kit 需要 InputImage）
    try {
      // 用临时文件
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/scene_temp.jpg');
      await file.writeAsBytes(bytes);
      final inputImage = InputImage.fromFilePath(file.path);

      final labels = await _labeler!.processImage(inputImage)
          .timeout(const Duration(seconds: 8));

      // 2. 同时分析亮度和主色调
      String lightDesc = '';
      String colorDesc = '';
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          final pixels = byteData.buffer.asUint8List();
          int brightness = 0, rSum = 0, gSum = 0, bSum = 0, count = 0;
          for (int i = 0; i < pixels.length; i += 32) {
            final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
            brightness += ((r * 299 + g * 587 + b * 114) / 1000).toInt();
            rSum += r; gSum += g; bSum += b; count++;
          }
          final avgBright = brightness / count;
          if (avgBright < 50) lightDesc = '环境较暗';
          else if (avgBright < 120) lightDesc = '光线适中';
          else if (avgBright < 200) lightDesc = '光线明亮';
          else lightDesc = '光线很强';

          if (count > 0) {
            colorDesc = '整体色调偏${_colorNameOf(rSum ~/ count, gSum ~/ count, bSum ~/ count)}';
          }
        }
        image.dispose();
      } catch (_) {}

      // 3. 组装描述
      if (labels.isEmpty) {
        return '${lightDesc.isNotEmpty ? "$lightDesc，" : ""}未识别到明确的物体。${colorDesc.isNotEmpty ? colorDesc : ""}请换个角度再试。';
      }

      // 翻译常见英文标签到中文
      final zhLabels = labels.take(5).map((l) {
        final name = _translateLabel(l.label);
        final conf = (l.confidence * 100).toStringAsFixed(0);
        return '$name($conf%)';
      }).join('、');

      final parts = <String>[];
      if (lightDesc.isNotEmpty) parts.add(lightDesc);
      parts.add('识别到：$zhLabels');
      if (colorDesc.isNotEmpty) parts.add(colorDesc);

      return parts.join('。');
    } catch (e) {
      // ML Kit 失败，降级到纯像素分析
      return _fallbackSceneAnalysis(bytes);
    }
  }

  /// ML Kit 不可用时的降级场景分析
  Future<String> _fallbackSceneAnalysis(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) { image.dispose(); return '分析失败'; }
      final pixels = byteData.buffer.asUint8List();
      int brightness = 0, rSum = 0, gSum = 0, bSum = 0, count = 0;
      int edgeCount = 0;
      int prevBright = 0;
      for (int i = 0; i < pixels.length; i += 16) {
        final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
        final br = ((r * 299 + g * 587 + b * 114) / 1000).toInt();
        brightness += br;
        rSum += r; gSum += g; bSum += b; count++;
        if ((br - prevBright).abs() > 40) edgeCount++;
        prevBright = br;
      }
      image.dispose();
      if (count == 0) return '分析失败';

      final avgBright = brightness / count;
      final mainColor = _colorNameOf(rSum ~/ count, gSum ~/ count, bSum ~/ count);
      final complexity = edgeCount > count * 0.3 ? '复杂' : (edgeCount > count * 0.1 ? '中等' : '简单');

      String lightDesc;
      if (avgBright < 50) lightDesc = '环境较暗';
      else if (avgBright < 120) lightDesc = '光线适中';
      else if (avgBright < 200) lightDesc = '光线明亮';
      else lightDesc = '光线很强';

      return '$lightDesc，画面$complexity，整体色调偏$mainColor。';
    } catch (e) {
      return '场景分析出错：$e';
    }
  }

  /// 常见英文标签翻译
  String _translateLabel(String label) {
    const map = {
      'Person': '人', 'Man': '男性', 'Woman': '女性', 'Child': '儿童',
      'Car': '汽车', 'Vehicle': '车辆', 'Bicycle': '自行车', 'Motorcycle': '摩托车',
      'Bus': '公交车', 'Truck': '卡车', 'Train': '火车',
      'Dog': '狗', 'Cat': '猫', 'Bird': '鸟', 'Animal': '动物',
      'Tree': '树', 'Plant': '植物', 'Flower': '花', 'Grass': '草',
      'Building': '建筑物', 'House': '房子', 'Door': '门', 'Window': '窗户',
      'Road': '道路', 'Street': '街道', 'Sidewalk': '人行道',
      'Sky': '天空', 'Cloud': '云', 'Sun': '太阳', 'Moon': '月亮',
      'Water': '水', 'River': '河', 'Sea': '海',
      'Food': '食物', 'Fruit': '水果', 'Vegetable': '蔬菜',
      'Table': '桌子', 'Chair': '椅子', 'Desk': '书桌', 'Bed': '床',
      'Phone': '手机', 'Computer': '电脑', 'Book': '书', 'Pen': '笔',
      'Clothing': '衣服', 'Shoe': '鞋', 'Hat': '帽子', 'Bag': '包',
      'Light': '灯光', 'Sign': '标志', 'Text': '文字',
      'Stairs': '楼梯', 'Wall': '墙', 'Floor': '地板', 'Ceiling': '天花板',
      'Furniture': '家具', 'Shelf': '架子',
    };
    return map[label] ?? label;
  }

  String _colorNameOf(int r, int g, int b) {
    final hsv = _rgb2hsv(r, g, b);
    final h = hsv[0];
    final s = hsv[1];
    final v = hsv[2];
    if (v < 0.15) return '黑色';
    if (v > 0.92 && s < 0.1) return '白色';
    if (s < 0.12) {
      if (v < 0.4) return '深灰色';
      if (v < 0.7) return '灰色';
      return '浅灰色';
    }
    if (h < 15 || h >= 345) return '红色';
    if (h < 40) return '橙色';
    if (h < 65) return '黄色';
    if (h < 95) return '黄绿色';
    if (h < 150) return '绿色';
    if (h < 180) return '青绿色';
    if (h < 220) return '蓝色';
    if (h < 260) return '深蓝色';
    if (h < 290) return '紫色';
    if (h < 330) return '玫红色';
    return '红色';
  }

  List<double> _rgb2hsv(int r, int g, int b) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;
    final cMax = math.max(rf, math.max(gf, bf));
    final cMin = math.min(rf, math.min(gf, bf));
    final delta = cMax - cMin;
    double h;
    if (delta == 0) {
      h = 0;
    } else if (cMax == rf) {
      h = 60 * (((gf - bf) / delta) % 6);
    } else if (cMax == gf) {
      h = 60 * (((bf - rf) / delta) + 2);
    } else {
      h = 60 * (((rf - gf) / delta) + 4);
    }
    if (h < 0) h += 360;
    final s = cMax == 0 ? 0.0 : delta / cMax;
    return [h, s, cMax];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _labeler?.close();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.type;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t.title),
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
                    child: _buildPreviewArea(t),
                  ),
                ),
              ),
            ),
            // 识别结果卡片
            if (_ready && _result.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: t.themeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(t.icon, color: t.themeColor, size: 22),
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
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // 拍照按钮 - 仅在 ready 时显示
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
                      _busy ? '识别中…' : '点击识别',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.themeColor,
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

  /// 预览区根据状态显示不同内容
  Widget _buildPreviewArea(ChannelType t) {
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
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: t.themeColor.withOpacity(0.7),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      );
    }

    // 错误状态
    final result = _cameraResult;
    if (result == null) {
      return StatusCard.error(
        title: '初始化失败',
        description: '请点击右上角刷新按钮重试',
        onRetry: _init,
      );
    }
    return StatusCard.error(
      title: result.message,
      description: '请点重试，如反复失败请检查摄像头权限',
      detail: result.detail,
      onRetry: _init,
      onOpenSettings: () async => await openAppSettings(),
    );
  }
}
