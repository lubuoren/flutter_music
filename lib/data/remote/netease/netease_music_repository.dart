import '../../models/track.dart';
import 'netease_api_client.dart';

class NeteaseMusicRepository {
  const NeteaseMusicRepository({required NeteaseApiClient client})
    : _client = client;

  final NeteaseApiClient _client;

  Future<List<Track>> searchTracks(
    String keyword, {
    int limit = 30,
    int offset = 0,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return const [];
    }

    final json = await _client.getJson(
      '/search',
      queryParameters: {
        'keywords': normalizedKeyword,
        'type': 1,
        'limit': limit,
        'offset': offset,
      },
    );
    return tracksFromSearchJson(json);
  }

  static List<Track> tracksFromSearchJson(Map<String, Object?> json) {
    final result = json['result'];
    if (result is! Map) {
      return const [];
    }

    final songs = result['songs'];
    if (songs is! List) {
      return const [];
    }

    return songs
        .whereType<Map>()
        .map((song) => _trackFromSong(Map<String, Object?>.from(song)))
        .toList();
  }

  static Track _trackFromSong(Map<String, Object?> song) {
    final album = _albumFromSong(song);
    final coverUrl = _stringValue(album?['picUrl'] ?? album?['blurPicUrl']);

    return Track(
      id: _stringValue(song['id']) ?? '',
      title: _stringValue(song['name']) ?? '未知歌曲',
      artists: _artistsFromSong(song),
      album: _stringValue(album?['name']),
      durationMs: _intValue(song['dt'] ?? song['duration']) ?? 0,
      type: TrackType.online,
      source: 'netease',
      coverUrl: coverUrl,
    );
  }

  static Map<String, Object?>? _albumFromSong(Map<String, Object?> song) {
    final album = song['al'] ?? song['album'];
    if (album is! Map) {
      return null;
    }
    return Map<String, Object?>.from(album);
  }

  static List<String> _artistsFromSong(Map<String, Object?> song) {
    final artists = song['ar'] ?? song['artists'];
    if (artists is! List) {
      return const ['未知艺术家'];
    }

    final names = artists
        .whereType<Map>()
        .map((artist) => _stringValue(artist['name']))
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList();
    return names.isEmpty ? const ['未知艺术家'] : names;
  }

  static String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
