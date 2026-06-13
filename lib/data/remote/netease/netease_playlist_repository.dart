import '../../models/playlist.dart';
import '../../models/track.dart';
import 'netease_api_client.dart';
import 'netease_music_repository.dart';

class NeteasePlaylistRepository {
  const NeteasePlaylistRepository({required NeteaseApiClient client})
    : _client = client;

  final NeteaseApiClient _client;

  Future<List<Playlist>> fetchUserPlaylists({
    required String userId,
    int limit = 2000,
    int offset = 0,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const [];
    }

    final json = await _client.getJson(
      '/user/playlist',
      queryParameters: {
        'uid': normalizedUserId,
        'limit': limit,
        'offset': offset,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    return playlistsFromUserPlaylistJson(json);
  }

  Future<Playlist> fetchPlaylistDetail(
    String playlistId, {
    bool noCache = true,
  }) async {
    final normalizedPlaylistId = playlistId.trim();
    if (normalizedPlaylistId.isEmpty) {
      throw const NeteaseApiException(message: '缺少歌单 ID');
    }

    final json = await _client.getJson(
      '/playlist/detail',
      queryParameters: {
        'id': normalizedPlaylistId,
        if (noCache) 'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    final payload = playlistPayloadFromDetailJson(json);
    if (payload == null) {
      throw const NeteaseApiException(message: '未获取到歌单详情');
    }

    final trackIds = trackIdsFromPlaylistJson(payload);
    var tracks = tracksFromPlaylistJson(payload);
    if (trackIds.isNotEmpty) {
      if (_tracksCoverAllIds(tracks, trackIds)) {
        tracks = _sortTracksByIds(tracks, trackIds);
      } else {
        tracks = await NeteaseMusicRepository(
          client: _client,
        ).tracksByIds(trackIds);
      }
    }

    return playlistFromPlaylistJson(payload, tracks: tracks);
  }

  static List<Playlist> playlistsFromUserPlaylistJson(
    Map<String, Object?> json,
  ) {
    final playlists = json['playlist'];
    if (playlists is! List) {
      return const [];
    }

    return playlists
        .whereType<Map>()
        .map(
          (playlist) =>
              playlistFromPlaylistJson(Map<String, Object?>.from(playlist)),
        )
        .toList();
  }

  static Map<String, Object?>? playlistPayloadFromDetailJson(
    Map<String, Object?> json,
  ) {
    return _mapValue(json['playlist']);
  }

  static Playlist playlistFromDetailJson(
    Map<String, Object?> json, {
    List<Track> tracks = const [],
  }) {
    final payload = playlistPayloadFromDetailJson(json);
    if (payload == null) {
      return const Playlist(id: '', name: '未命名歌单', source: 'netease');
    }
    return playlistFromPlaylistJson(payload, tracks: tracks);
  }

  static Playlist playlistFromPlaylistJson(
    Map<String, Object?> playlist, {
    List<Track> tracks = const [],
  }) {
    final creator = _mapValue(playlist['creator']);
    final trackCount = _intValue(playlist['trackCount']) ?? tracks.length;
    return Playlist(
      id: _stringValue(playlist['id']) ?? '',
      name: _stringValue(playlist['name']) ?? '未命名歌单',
      description: _stringValue(playlist['description']),
      coverUrl: _stringValue(
        playlist['coverImgUrl'] ?? playlist['picUrl'] ?? playlist['coverUrl'],
      ),
      creatorUserId: _stringValue(creator?['userId']),
      creatorName: _stringValue(creator?['nickname']),
      source: 'netease',
      trackCount: trackCount,
      isLocal: false,
      subscribed: _boolValue(playlist['subscribed']),
      tracks: tracks,
      createdAt: _dateTimeFromMilliseconds(playlist['createTime']),
      updatedAt: _dateTimeFromMilliseconds(playlist['updateTime']),
    );
  }

  static List<Track> tracksFromPlaylistJson(Map<String, Object?> playlist) {
    final tracks = playlist['tracks'];
    if (tracks is! List) {
      return const [];
    }

    return tracks
        .whereType<Map>()
        .map(
          (track) => NeteaseMusicRepository.trackFromSongJson(
            Map<String, Object?>.from(track),
          ),
        )
        .toList();
  }

  static List<String> trackIdsFromPlaylistJson(Map<String, Object?> playlist) {
    final trackIds = playlist['trackIds'];
    if (trackIds is! List) {
      return const [];
    }

    return trackIds
        .map((item) {
          if (item is Map) {
            return _stringValue(item['id']);
          }
          return _stringValue(item);
        })
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
  }

  bool _tracksCoverAllIds(List<Track> tracks, List<String> trackIds) {
    if (tracks.length < trackIds.length) {
      return false;
    }
    final ids = tracks.map((track) => track.id).toSet();
    return trackIds.every(ids.contains);
  }

  List<Track> _sortTracksByIds(List<Track> tracks, List<String> trackIds) {
    final tracksById = {for (final track in tracks) track.id: track};
    final sortedTracks = <Track>[];
    for (final id in trackIds) {
      final track = tracksById[id];
      if (track != null) {
        sortedTracks.add(track);
      }
    }
    return sortedTracks;
  }

  static Map<String, Object?>? _mapValue(Object? value) {
    if (value is! Map) {
      return null;
    }
    return Map<String, Object?>.from(value);
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

  static bool _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == 'true' || value == '1';
    }
    return false;
  }

  static DateTime? _dateTimeFromMilliseconds(Object? value) {
    final milliseconds = _intValue(value);
    if (milliseconds == null || milliseconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
