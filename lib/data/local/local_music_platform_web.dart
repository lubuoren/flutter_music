import '../models/track.dart';
import 'local_music_platform_interface.dart';

LocalMusicPlatform createLocalMusicPlatform() {
  return LocalMusicPlatformWeb();
}

class LocalMusicPlatformWeb implements LocalMusicPlatform {
  @override
  Future<String?> pickDirectory() async {
    return null;
  }

  @override
  Future<List<Track>> scanDirectory(String directoryPath) {
    throw UnsupportedError('Web 客户端暂不支持扫描本地目录，请使用在线搜索播放云端歌曲');
  }
}
