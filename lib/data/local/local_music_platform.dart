import 'local_music_platform_interface.dart';
import 'local_music_platform_stub.dart'
    if (dart.library.io) 'local_music_platform_io.dart'
    if (dart.library.js_interop) 'local_music_platform_web.dart'
    as impl;

export 'local_music_platform_interface.dart';

LocalMusicPlatform createLocalMusicPlatform() {
  return impl.createLocalMusicPlatform();
}
