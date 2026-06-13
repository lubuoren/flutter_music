import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider? coverImageProvider(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return NetworkImage(value);
  }
  if (uri != null && uri.scheme == 'file') {
    return FileImage(File.fromUri(uri));
  }
  return FileImage(File(value));
}
