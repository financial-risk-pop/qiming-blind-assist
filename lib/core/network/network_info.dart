import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络连接状态监测器
/// 
/// 盲人辅助App对网络状态敏感：
/// - 有网络：启用AI云端增强（OCR精细模式/AI解读）
/// - 无网络：自动降级到端侧模式
/// 
/// 基于 connectivity_plus v5 API（checkConnectivity 返回单个 ConnectivityResult）。
class NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfo({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// 当前是否有网络连接
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// 当前是否为WiFi连接
  Future<bool> get isWifi async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.wifi;
  }

  /// 监听网络变化流
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(
      (result) => result != ConnectivityResult.none,
    );
  }

  /// 获取当前网络类型描述（用于语音播报）
  Future<String> getNetworkTypeDescription() async {
    final result = await _connectivity.checkConnectivity();
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi网络';
      case ConnectivityResult.mobile:
        return '移动数据网络';
      case ConnectivityResult.ethernet:
        return '有线网络';
      case ConnectivityResult.none:
        return '无网络连接';
      default:
        return '未知网络';
    }
  }
}
