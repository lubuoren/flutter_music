import 'package:flutter/widgets.dart';

import 'cover_image_provider_stub.dart'
    if (dart.library.io) 'cover_image_provider_io.dart'
    if (dart.library.js_interop) 'cover_image_provider_web.dart'
    as impl;

ImageProvider? coverImageProvider(String? value) {
  return impl.coverImageProvider(value);
}
