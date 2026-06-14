import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

Future<Uint8List?> coverImageBytes(String? value) async {
  final trimmedValue = value?.trim();
  if (trimmedValue == null || trimmedValue.isEmpty) {
    return null;
  }

  final normalizedValue = _normalizedRemoteImageUrl(trimmedValue);
  final uri = Uri.tryParse(normalizedValue);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return _remoteImageBytes(uri);
  }
  if (uri != null && uri.scheme == 'file') {
    return File.fromUri(uri).readAsBytes();
  }
  return File(normalizedValue).readAsBytes();
}

String _normalizedRemoteImageUrl(String value) {
  if (value.startsWith('//')) {
    return 'https:$value';
  }
  return value;
}

Future<Uint8List?> _remoteImageBytes(Uri uri) async {
  try {
    final response = await Dio().get<List<int>>(
      uri.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        headers: _headersForRemoteImage(uri),
        sendTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ),
    );
    final data = response.data;
    return data == null ? null : Uint8List.fromList(data);
  } on Object {
    return null;
  }
}

Map<String, String>? _headersForRemoteImage(Uri uri) {
  if (!uri.host.endsWith('music.126.net')) {
    return null;
  }
  return const {
    'Referer': 'https://music.163.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/125.0 Safari/537.36',
  };
}
