import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/speech/native_speech.dart';
import '../../../../core/tts/safe_tts.dart';

/// 诊断页面 V3 —— 加入原生 TTS 测试
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final List<String> _logs = [];
  bool _running = false;

  void _log(String msg) {
    final time = DateTime.now().toString().substring(11, 19);
    if (mounted) setState(() => _logs.add('[$time] $msg'));
  }

  Future<void> _runDiagnostics() async {
    if (_running) return;
    _running = true;
    setState(() => _logs.clear());

    _log('========== 诊断 V4 ==========');

    // ===== 1. 原生 TTS =====
    _log('1. 原生 TTS...');
    final tts = SafeTts();
    tts.init();

    // 等待 TTS 初始化
    _log('   等待 TTS 初始化...');
    await Future.delayed(const Duration(seconds: 2));

    // 获取详细状态
    try {
      final status = await tts.getStatus();
      _log('   状态: $status');
      final ready = status['ready'] == true;
      _log('   ready: $ready');
      _log('   引擎: ${status['engine']}');
      _log('   voice: ${status['voice']}');
      _log('   locale: ${status['locale']}');

      _log('   调用 speak("你好，我是启明")...');
      await tts.speak('你好，我是启明');
      _log('   speak 调用完成');
      await Future.delayed(const Duration(seconds: 4));
      _log('   再试 speak("一二三四五六七八九十")...');
      await tts.speak('一二三四五六七八九十');
      await Future.delayed(const Duration(seconds: 4));

      if (ready) {
        _log('   ✅ TTS 引擎已就绪（如没声音请检查手机音量）');
      } else {
        _log('   ⚠️ TTS 引擎未就绪');
        _log('   请到: 设置→系统→无障碍→文字转语音');
        _log('   确认有中文语音引擎且已下载语音数据');
      }
    } catch (e) {
      _log('   原生 TTS 异常 ❌: $e');
    }

    // ===== 2. 摄像头 =====
    _log('2. 摄像头测试...');
    try {
      final cameras = await availableCameras();
      _log('   ${cameras.length} 个摄像头 ✅');
    } catch (e) {
      _log('   摄像头失败 ❌: $e');
    }

    // ===== 3. 原生语音识别 =====
    _log('3. 原生语音识别...');
    try {
      final available = await NativeSpeech.isAvailable();
      _log('   isAvailable: $available ${available ? "✅" : "❌"}');
      if (!available) {
        _log('   手机无语音识别引擎，将使用文字输入替代');
      }
    } catch (e) {
      _log('   异常 ❌: $e');
    }

    // ===== 4. 高德 API =====
    _log('4. 高德 API (Web服务 Key)...');
    try {
      final client = HttpClient();
      final uri = Uri.parse(
          'https://restapi.amap.com/v3/geocode/geo?key=YOUR_AMAP_WEB_SERVICE_KEY&address=天安门&output=JSON');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 5));
      if (body.contains('"status":"1"')) {
        _log('   高德 API 正常 ✅');
      } else {
        _log('   高德返回: ${body.substring(0, body.length.clamp(0, 300))}');
        if (body.contains('USERKEY_PLAT_NOMATCH')) {
          _log('   ❌ Key 平台类型不匹配！');
          _log('   需要在高德开放平台申请「Web服务」类型的 Key');
          _log('   当前 Key 是 Android 平台的，不能用于 HTTP API');
        }
      }
      client.close();
    } catch (e) {
      _log('   高德 API 失败 ❌: $e');
    }

    // ===== 5. 网络连通性 =====
    _log('5. 网络测试...');
    try {
      final client = HttpClient();
      final uri = Uri.parse('https://www.baidu.com');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 3));
      final resp = await req.close().timeout(const Duration(seconds: 3));
      _log('   百度: HTTP ${resp.statusCode} ✅');
      client.close();
    } catch (e) {
      _log('   网络异常 ❌: $e');
    }

    _log('========== 诊断完成 ==========');
    _log('如果没听到声音，请检查：');
    _log('设置→系统→语言→文字转语音→确认有中文引擎');
    _running = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统诊断 V3'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _running ? null : _runDiagnostics,
                icon: Icon(_running ? Icons.hourglass_top : Icons.play_arrow, size: 28),
                label: Text(
                  _running ? '诊断中...' : '开始诊断',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        '点击上方按钮开始诊断\n\n测试：原生TTS · 摄像头 · 语音识别 · 高德API · 网络',
                        style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.8),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (_, i) {
                        final log = _logs[i];
                        Color color = Colors.white70;
                        if (log.contains('✅')) color = Colors.greenAccent;
                        if (log.contains('❌')) color = Colors.redAccent;
                        if (log.contains('===')) color = Colors.cyanAccent;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(log,
                              style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace', height: 1.4)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
