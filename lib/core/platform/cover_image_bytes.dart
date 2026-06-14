import 'dart:typed_data';

import 'cover_image_bytes_stub.dart'
    if (dart.library.io) 'cover_image_bytes_io.dart'
    if (dart.library.js_interop) 'cover_image_bytes_web.dart'
    as impl;

Future<Uint8List?> coverImageBytes(String? value) {
  return impl.coverImageBytes(value);
}
