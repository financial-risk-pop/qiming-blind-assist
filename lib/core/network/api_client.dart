import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// API客户端配置
/// 
/// 用于连接AI云端服务（OCR精细模式、AI解读增强等）
class ApiClient {
  late final Dio _dio;

  ApiClient({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
      connectTimeout: const Duration(
        seconds: AppConstants.aiVisionTimeout,
      ),
      receiveTimeout: const Duration(
        seconds: AppConstants.aiVisionTimeout,
      ),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 请求/响应拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // TODO: 添加鉴权token
        handler.next(options);
      },
      onError: (error, handler) {
        // 统一错误处理
        handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  /// GET请求
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  /// POST请求
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }

  /// 上传文件（图片识别等场景）
  Future<Response> uploadFile(
    String path, {
    required String filePath,
    String fieldName = 'file',
    Map<String, dynamic>? extraData,
  }) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
      ...?extraData,
    });
    return _dio.post(path, data: formData);
  }
}
