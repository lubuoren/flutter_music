import 'package:dio/dio.dart';

class NeteaseApiConfig {
  const NeteaseApiConfig({
    required this.baseUrl,
    this.cookie,
    this.proxy,
    this.realIp,
  });

  static const defaultBaseUrl = 'http://127.0.0.1:3000';

  final String baseUrl;
  final String? cookie;
  final String? proxy;
  final String? realIp;

  Uri get normalizedBaseUri {
    final uri = Uri.parse(baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl);
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/$'), ''));
  }
}

class NeteaseApiException implements Exception {
  const NeteaseApiException({
    required this.message,
    this.statusCode,
    this.responseCode,
    this.path,
  });

  final String message;
  final int? statusCode;
  final int? responseCode;
  final String? path;

  bool get isUnauthorized => responseCode == 301;

  @override
  String toString() {
    final location = path == null ? '' : ' ($path)';
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    return 'NeteaseApiException$status$location: $message';
  }
}

class NeteaseApiClient {
  NeteaseApiClient({required this.config, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.normalizedBaseUri.toString(),
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final NeteaseApiConfig config;
  final Dio _dio;

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) {
    return _request(path, method: 'GET', queryParameters: queryParameters);
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> queryParameters = const {},
    Object? data,
  }) {
    return _request(
      path,
      method: 'POST',
      queryParameters: queryParameters,
      data: data,
    );
  }

  Future<Map<String, Object?>> _request(
    String path, {
    required String method,
    Map<String, Object?> queryParameters = const {},
    Object? data,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: _withCommonParameters(queryParameters),
        options: Options(method: method, headers: _headers),
      );
      return _decodeResponse(path, response);
    } on DioException catch (error) {
      final data = error.response?.data;
      throw NeteaseApiException(
        message: _messageFromData(data) ?? error.message ?? '网易云 API 请求失败',
        statusCode: error.response?.statusCode,
        responseCode: _codeFromData(data),
        path: path,
      );
    }
  }

  Map<String, Object?> _withCommonParameters(Map<String, Object?> parameters) {
    return {
      ...parameters,
      if (config.proxy != null && config.proxy!.isNotEmpty)
        'proxy': config.proxy,
      if (config.realIp != null && config.realIp!.isNotEmpty)
        'realIP': config.realIp,
    };
  }

  Map<String, String>? get _headers {
    final cookie = config.cookie;
    if (cookie == null || cookie.isEmpty) {
      return null;
    }
    return {'Cookie': cookie};
  }

  Map<String, Object?> _decodeResponse(
    String path,
    Response<Object?> response,
  ) {
    final data = response.data;
    if (data is! Map) {
      throw NeteaseApiException(
        message: '网易云 API 返回了非 JSON 对象',
        statusCode: response.statusCode,
        path: path,
      );
    }

    final json = Map<String, Object?>.from(data);
    final code = _codeFromData(json);
    if (code == 301) {
      throw NeteaseApiException(
        message: _messageFromData(json) ?? '登录态已失效',
        statusCode: response.statusCode,
        responseCode: code,
        path: path,
      );
    }
    return json;
  }

  int? _codeFromData(Object? data) {
    if (data is! Map) {
      return null;
    }
    final code = data['code'];
    if (code is int) {
      return code;
    }
    if (code is String) {
      return int.tryParse(code);
    }
    return null;
  }

  String? _messageFromData(Object? data) {
    if (data is! Map) {
      return null;
    }
    final message = data['message'] ?? data['msg'];
    return message is String ? message : null;
  }
}
