import 'dart:typed_data';

import 'package:dio/dio.dart';

Future<Uint8List?> coverImageBytes(String? value) async {
  final trimmedValue = value?.trim();
  if (trimmedValue == null || trimmedValue.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(_normalizedRemoteImageUrl(trimmedValue));
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }

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

String _normalizedRemoteImageUrl(String value) {
  if (value.startsWith('//')) {
    return 'https:$value';
  }
  final uri = Uri.tryParse(value);
  if (uri != null &&
      uri.scheme == 'http' &&
      uri.host.endsWith('music.126.net')) {
    return uri.replace(scheme: 'https').toString();
  }
  return value;
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
