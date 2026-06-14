import '../../models/playlist.dart';
import '../../models/track.dart';
import 'netease_api_client.dart';
import 'netease_json.dart';
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

  /// 每日推荐歌曲（`/recommend/songs`，需登录）。返回合成的「每日推荐」歌单。
  Future<Playlist> fetchDailyRecommendTracks() async {
    final json = await _client.getJson(
      '/recommend/songs',
      queryParameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
    final tracks = dailyTracksFromRecommendJson(json);
    return Playlist(
      id: 'daily-songs',
      name: '每日推荐',
      source: 'netease',
      trackCount: tracks.length,
      tracks: tracks,
    );
  }

  static List<Track> dailyTracksFromRecommendJson(Map<String, Object?> json) {
    final data = neteaseMap(json['data']);
    final rawSongs =
        data?['dailySongs'] ?? data?['songs'] ?? json['dailySongs'];
    return _tracksFromSongList(rawSongs);
  }

  /// 获取专辑详情（专辑信息 + 歌曲），映射为统一 [Playlist]（id 形如 `album:<id>`）。
  Future<Playlist> fetchAlbum(String albumId) async {
    final id = albumId.trim();
    if (id.isEmpty) {
      throw const NeteaseApiException(message: '缺少专辑 ID');
    }
    final json = await _client.getJson('/album', queryParameters: {'id': id});
    return albumFromJson(id, json);
  }

  /// 获取艺术家详情（信息 + 热门歌曲），映射为统一 [Playlist]（id 形如 `artist:<id>`）。
  Future<Playlist> fetchArtist(String artistId) async {
    final id = artistId.trim();
    if (id.isEmpty) {
      throw const NeteaseApiException(message: '缺少艺术家 ID');
    }
    final json = await _client.getJson('/artists', queryParameters: {'id': id});
    return artistFromJson(id, json);
  }

  static Playlist albumFromJson(String albumId, Map<String, Object?> json) {
    final album = neteaseMap(json['album']) ?? const {};
    final artist = neteaseMap(album['artist']);
    final tracks = _tracksFromSongList(json['songs']);
    return Playlist(
      id: 'album:$albumId',
      name: neteaseString(album['name']) ?? '未知专辑',
      description: neteaseString(album['description']),
      coverUrl: _normalizedImageUrl(
        neteaseString(album['picUrl'] ?? album['blurPicUrl']),
      ),
      creatorUserId: neteaseString(artist?['id']),
      creatorName: neteaseString(artist?['name']),
      source: 'netease',
      trackCount: tracks.length,
      tracks: tracks,
    );
  }

  static Playlist artistFromJson(String artistId, Map<String, Object?> json) {
    final artist = neteaseMap(json['artist']) ?? const {};
    final tracks = _tracksFromSongList(json['hotSongs']);
    return Playlist(
      id: 'artist:$artistId',
      name: neteaseString(artist['name']) ?? '未知艺术家',
      description: neteaseString(artist['briefDesc']),
      coverUrl: _normalizedImageUrl(
        neteaseString(
          artist['cover'] ?? artist['picUrl'] ?? artist['img1v1Url'],
        ),
      ),
      creatorUserId: artistId,
      creatorName: neteaseString(artist['name']),
      source: 'netease',
      trackCount: tracks.length,
      tracks: tracks,
    );
  }

  static List<Track> _tracksFromSongList(Object? rawSongs) {
    if (rawSongs is! List) {
      return const [];
    }
    return rawSongs
        .whereType<Map>()
        .map(
          (song) => NeteaseMusicRepository.trackFromSongJson(
            Map<String, Object?>.from(song),
          ),
        )
        .toList();
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
    return neteaseMap(json['playlist']);
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
    final creator = neteaseMap(playlist['creator']);
    final trackCount = neteaseInt(playlist['trackCount']) ?? tracks.length;
    return Playlist(
      id: neteaseString(playlist['id']) ?? '',
      name: neteaseString(playlist['name']) ?? '未命名歌单',
      description: neteaseString(playlist['description']),
      coverUrl: _coverUrlFromPlaylistJson(playlist),
      creatorUserId: neteaseString(creator?['userId']),
      creatorName: neteaseString(creator?['nickname']),
      source: 'netease',
      trackCount: trackCount,
      isLocal: false,
      subscribed: neteaseBool(playlist['subscribed']) ?? false,
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
            return neteaseString(item['id']);
          }
          return neteaseString(item);
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

  static String? _normalizedImageUrl(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }
    if (trimmedValue.startsWith('//')) {
      return 'https:$trimmedValue';
    }
    if (trimmedValue.startsWith('http://')) {
      return trimmedValue.replaceFirst('http://', 'https://');
    }
    return trimmedValue;
  }

  static String? _coverUrlFromPlaylistJson(Map<String, Object?> playlist) {
    for (final key in const [
      'coverImgUrl',
      'picUrl',
      'coverUrl',
      'coverImageUrl',
      'imageUrl',
      'cover',
      'iconImgUrl',
      'backgroundCoverUrl',
      'backgroundImageUrl',
      'titleImageUrl',
    ]) {
      final url = _normalizedImageUrl(neteaseString(playlist[key]));
      if (url != null) {
        return url;
      }
    }

    for (final key in const [
      'socialPlaylistCover',
      'recommendInfo',
      'coverInfo',
      'resource',
    ]) {
      final nested = neteaseMap(playlist[key]);
      if (nested == null) {
        continue;
      }
      final url = _coverUrlFromPlaylistJson(nested);
      if (url != null) {
        return url;
      }
    }

    return null;
  }

  static DateTime? _dateTimeFromMilliseconds(Object? value) {
    final milliseconds = neteaseInt(value);
    if (milliseconds == null || milliseconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
