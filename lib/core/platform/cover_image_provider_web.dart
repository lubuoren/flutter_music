import 'package:flutter/widgets.dart';

ImageProvider? coverImageProvider(String? value) {
  final trimmedValue = value?.trim();
  if (trimmedValue == null || trimmedValue.isEmpty) {
    return null;
  }
  final normalizedValue = _normalizedRemoteImageUrl(trimmedValue);
  final uri = Uri.tryParse(normalizedValue);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return NetworkImage(normalizedValue);
  }
  return null;
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
