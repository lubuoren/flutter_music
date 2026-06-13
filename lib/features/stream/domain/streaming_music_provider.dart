import '../../../data/models/lyric_line.dart';
import '../../../data/models/playlist.dart';
import '../../../data/models/track.dart';

/// 流媒体登录凭据。
class StreamingCredentials {
  const StreamingCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String username;
  final String password;
}

/// 可播放音频地址及其元信息。
class AudioUrl {
  const AudioUrl({required this.url, this.bitRate, this.format});

  final String url;
  final int? bitRate;
  final String? format;
}

/// 统一流媒体服务抽象。
///
/// 对应 VutronMusic `src/main/streaming/{navidrome,jellyfin,emby}.ts`，
/// Navidrome、Jellyfin、Emby 各实现一份。
abstract class StreamingMusicProvider {
  String get name;

  Future<bool> login(StreamingCredentials credentials);

  Future<void> logout();

  Future<bool> get isLoggedIn;

  Future<List<Track>> search(String query);

  Future<List<Playlist>> getPlaylists();

  Future<Playlist> getPlaylistDetail(String playlistId);

  Future<List<Track>> getLikedTracks();

  Future<void> setLike(String trackId, {required bool like});

  Future<AudioUrl> getTrackUrl(String trackId);

  Future<List<LyricLine>> getLyric(Track track);

  Future<String?> getCoverUrl(String trackId);

  /// 听歌记录上报。
  Future<void> scrobble(Track track);
}
