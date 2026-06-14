import 'dart:convert';

import '../../../data/local/database/app_database.dart';
import '../../../data/models/track.dart';

/// 「正在播放」队列的持久化快照。
class NowPlayingSnapshot {
  const NowPlayingSnapshot({
    required this.tracks,
    this.currentIndex,
    this.position = Duration.zero,
  });

  final List<Track> tracks;
  final int? currentIndex;
  final Duration position;
}

const String _nowPlayingKey = 'now_playing.v1';

/// 序列化「正在播放」队列。
///
/// 在线曲会清空 `url`（播放地址会过期），恢复后由播放器懒解析。
String encodeNowPlaying(
  List<Track> tracks,
  int? currentIndex,
  Duration position,
) {
  return jsonEncode({
    'tracks': [
      for (final track in tracks)
        (track.type == TrackType.online ? track.copyWith(url: '') : track)
            .toJson(),
    ],
    'currentIndex': currentIndex,
    'positionMs': position.inMilliseconds,
  });
}

/// 反序列化「正在播放」快照；为空、损坏或无歌曲时返回 null。
NowPlayingSnapshot? decodeNowPlaying(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on Object {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final tracksJson = decoded['tracks'];
  final tracks = tracksJson is List
      ? tracksJson
            .whereType<Map>()
            .map((item) => Track.fromJson(Map<String, Object?>.from(item)))
            .toList()
      : <Track>[];
  if (tracks.isEmpty) {
    return null;
  }
  final index = decoded['currentIndex'];
  final positionMs = decoded['positionMs'];
  return NowPlayingSnapshot(
    tracks: tracks,
    currentIndex: index is int ? index : null,
    position: Duration(milliseconds: positionMs is int ? positionMs : 0),
  );
}

/// 用 `app_data` 持久化与恢复「正在播放」队列。
class NowPlayingRepository {
  Future<void> save(
    List<Track> tracks,
    int? currentIndex,
    Duration position,
  ) async {
    final value = tracks.isEmpty
        ? ''
        : encodeNowPlaying(tracks, currentIndex, position);
    await AppDatabase.instance.setAppData(_nowPlayingKey, value);
  }

  Future<NowPlayingSnapshot?> load() async {
    final raw = await AppDatabase.instance.getAppData(_nowPlayingKey);
    return decodeNowPlaying(raw);
  }
}
