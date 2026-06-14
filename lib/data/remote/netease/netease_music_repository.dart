import '../../models/lyric_source_marker.dart';
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

  Future<Track> resolvePlaybackUrl(Track track, {int bitrate = 320000}) async {
    final existingUrl = track.url?.trim();
    if (existingUrl != null && existingUrl.isNotEmpty) {
      return track;
    }

    final json = await _client.getJson(
      '/song/url',
      queryParameters: {'id': track.id, 'br': bitrate},
    );
    final playableTrack = trackWithPlaybackUrlFromSongUrlJson(track, json);
    final playableUrl = playableTrack.url?.trim();
    if (playableUrl == null || playableUrl.isEmpty) {
      throw const NeteaseApiException(
        message: '未获取到歌曲播放地址，可能需要登录或歌曲受版权限制',
        path: '/song/url',
      );
    }
    return playableTrack;
  }

  Future<Track> resolvePlayableTrack(
    Track track, {
    int bitrate = 320000,
  }) async {
    var resolvedTrack = await resolvePlaybackUrl(track, bitrate: bitrate);

    try {
      resolvedTrack = await trackWithRemoteDetail(resolvedTrack);
    } on Object {
      // Playback URL is enough to continue; cover/detail enrichment is best-effort.
    }

    try {
      resolvedTrack = await trackWithRemoteLyrics(resolvedTrack);
    } on Object {
      // Lyrics should not prevent online playback.
    }

    return resolvedTrack;
  }

  Future<Track> trackWithRemoteDetail(Track track) async {
    final json = await _client.getJson(
      '/song/detail',
      queryParameters: {'ids': track.id},
    );
    return trackWithDetailFromSongDetailJson(track, json);
  }

  Future<List<Track>> tracksByIds(
    List<String> ids, {
    int chunkSize = 500,
  }) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (normalizedIds.isEmpty) {
      return const [];
    }

    final tracks = <Track>[];
    for (var start = 0; start < normalizedIds.length; start += chunkSize) {
      final end = start + chunkSize > normalizedIds.length
          ? normalizedIds.length
          : start + chunkSize;
      final chunk = normalizedIds.sublist(start, end);
      final json = await _client.getJson(
        '/song/detail',
        queryParameters: {'ids': chunk.join(',')},
      );
      final songsById = _songDetailItems(json);
      for (final id in chunk) {
        final song = songsById[id];
        tracks.add(
          song == null
              ? Track(
                  id: id,
                  title: '未知歌曲',
                  artists: const ['未知艺术家'],
                  type: TrackType.online,
                  source: 'netease',
                )
              : _trackFromSong(song),
        );
      }
    }
    return tracks;
  }

  Future<List<Track>> tracksWithRemoteDetails(List<Track> tracks) async {
    final ids = tracks
        .map((track) => track.id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      return tracks;
    }

    final json = await _client.getJson(
      '/song/detail',
      queryParameters: {'ids': ids.join(',')},
    );
    return tracksWithDetailFromSongDetailJson(tracks, json);
  }

  Future<List<Track>> tracksWithPlaybackUrls(
    List<Track> tracks, {
    int bitrate = 320000,
    int chunkSize = 200,
  }) async {
    final unresolvedTracks = tracks
        .where((track) => track.url == null || track.url!.trim().isEmpty)
        .toList();
    if (unresolvedTracks.isEmpty) {
      return tracks;
    }

    var resolvedTracks = tracks;
    for (var start = 0; start < unresolvedTracks.length; start += chunkSize) {
      final end = start + chunkSize > unresolvedTracks.length
          ? unresolvedTracks.length
          : start + chunkSize;
      final chunk = unresolvedTracks.sublist(start, end);
      final ids = chunk
          .map((track) => track.id.trim())
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isEmpty) {
        continue;
      }

      final json = await _client.getJson(
        '/song/url',
        queryParameters: {'id': ids.join(','), 'br': bitrate},
      );
      resolvedTracks = tracksWithPlaybackUrlsFromSongUrlJson(
        resolvedTracks,
        json,
      );
    }
    return resolvedTracks;
  }

  Future<Track> trackWithRemoteLyrics(Track track) async {
    final existingLyrics = track.lyrics?.trim();
    if (existingLyrics != null && existingLyrics.isNotEmpty) {
      return track;
    }

    final json = await _client.getJson(
      '/lyric/new',
      queryParameters: {'id': track.id},
    );
    final lyrics = lyricsFromLyricNewJson(json);
    if (lyrics == null || lyrics.trim().isEmpty) {
      return track;
    }
    return track.copyWith(lyrics: lyrics);
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

  static Track trackWithPlaybackUrlFromSongUrlJson(
    Track track,
    Map<String, Object?> json,
  ) {
    final item = _songUrlItem(json, track.id);
    if (item == null) {
      return track;
    }

    return _trackWithPlaybackUrlItem(track, item);
  }

  static List<Track> tracksWithPlaybackUrlsFromSongUrlJson(
    List<Track> tracks,
    Map<String, Object?> json,
  ) {
    final itemsById = _songUrlItems(json);
    if (itemsById.isEmpty) {
      return tracks;
    }

    return [
      for (final track in tracks)
        if (itemsById[track.id] case final item?)
          _trackWithPlaybackUrlItem(track, item)
        else
          track,
    ];
  }

  static Track _trackWithPlaybackUrlItem(
    Track track,
    Map<String, Object?> item,
  ) {
    final url = _stringValue(item['url']);
    final durationMs = _intValue(item['time']);
    return track.copyWith(
      url: url,
      durationMs: track.durationMs == 0 ? durationMs : null,
    );
  }

  static Track trackWithDetailFromSongDetailJson(
    Track track,
    Map<String, Object?> json,
  ) {
    final song = _songDetailItem(json, track.id);
    if (song == null) {
      return track;
    }

    return _trackWithDetailFromSong(track, song);
  }

  static List<Track> tracksWithDetailFromSongDetailJson(
    List<Track> tracks,
    Map<String, Object?> json,
  ) {
    final songsById = _songDetailItems(json);
    if (songsById.isEmpty) {
      return tracks;
    }

    return [
      for (final track in tracks)
        if (songsById[track.id] case final song?)
          _trackWithDetailFromSong(track, song)
        else
          track,
    ];
  }

  static String? lyricsFromLyricNewJson(Map<String, Object?> json) {
    final rawYrc = _lyricText(json['yrc']);
    if (rawYrc != null && rawYrc.isNotEmpty) {
      return _combineLyricSources(
        main: rawYrc,
        translation: _lyricText(json['ytlrc']),
        romanization: _lyricText(json['yromalrc']),
      );
    }

    final rawLrc = _lyricText(json['lrc']);
    if (rawLrc == null || rawLrc.isEmpty) {
      return null;
    }
    return _combineLyricSources(
      main: rawLrc,
      translation: _lyricText(json['tlyric']),
      romanization: _lyricText(json['romalrc']),
    );
  }

  static String _combineLyricSources({
    required String main,
    String? translation,
    String? romanization,
  }) {
    return [
      markLyricSource(lyricSourceMain),
      main,
      if (translation != null && translation.trim().isNotEmpty) ...[
        markLyricSource(lyricSourceTranslation),
        translation,
      ],
      if (romanization != null && romanization.trim().isNotEmpty) ...[
        markLyricSource(lyricSourceRomanization),
        romanization,
      ],
    ].join('\n');
  }

  static Track trackFromSongJson(Map<String, Object?> song) {
    return _trackFromSong(song);
  }

  static Track _trackFromSong(Map<String, Object?> song) {
    final album = _albumFromSong(song);
    final coverUrl = _normalizedImageUrl(
      _stringValue(album?['picUrl'] ?? album?['blurPicUrl']),
    );

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

  static Track _trackWithDetailFromSong(
    Track track,
    Map<String, Object?> song,
  ) {
    final detailedTrack = _trackFromSong(song);
    return track.copyWith(
      title: detailedTrack.title,
      artists: detailedTrack.artists,
      album: detailedTrack.album,
      durationMs: track.durationMs == 0
          ? detailedTrack.durationMs
          : track.durationMs,
      coverUrl: detailedTrack.coverUrl ?? track.coverUrl,
    );
  }

  static Map<String, Object?>? _songUrlItem(
    Map<String, Object?> json,
    String trackId,
  ) {
    final itemsById = _songUrlItems(json);
    if (itemsById.containsKey(trackId)) {
      return itemsById[trackId];
    }

    final data = json['data'];
    if (data is Map) {
      return Map<String, Object?>.from(data);
    }
    return data is List && data.whereType<Map>().isNotEmpty
        ? Map<String, Object?>.from(data.whereType<Map>().first)
        : null;
  }

  static Map<String, Map<String, Object?>> _songUrlItems(
    Map<String, Object?> json,
  ) {
    final data = json['data'];
    final items = switch (data) {
      Map() => [data],
      List() => data.whereType<Map>().toList(),
      _ => const <Map>[],
    };

    final itemsById = <String, Map<String, Object?>>{};
    for (final item in items) {
      final mapped = Map<String, Object?>.from(item);
      final id = _stringValue(mapped['id']);
      if (id != null && id.isNotEmpty) {
        itemsById[id] = mapped;
      }
    }
    return itemsById;
  }

  static Map<String, Object?>? _songDetailItem(
    Map<String, Object?> json,
    String trackId,
  ) {
    final songsById = _songDetailItems(json);
    if (songsById.containsKey(trackId)) {
      return songsById[trackId];
    }
    final songs = json['songs'];
    Map<String, Object?>? firstItem;
    if (songs is! List) {
      return null;
    }
    for (final item in songs.whereType<Map>()) {
      final mapped = Map<String, Object?>.from(item);
      firstItem ??= mapped;
    }
    return firstItem;
  }

  static Map<String, Map<String, Object?>> _songDetailItems(
    Map<String, Object?> json,
  ) {
    final songs = json['songs'];
    if (songs is! List) {
      return const {};
    }

    final songsById = <String, Map<String, Object?>>{};
    for (final item in songs.whereType<Map>()) {
      final mapped = Map<String, Object?>.from(item);
      final id = _stringValue(mapped['id']);
      if (id != null && id.isNotEmpty) {
        songsById[id] = mapped;
      }
    }
    return songsById;
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

  static String? _lyricText(Object? value) {
    if (value is! Map) {
      return null;
    }
    return _stringValue(value['lyric']);
  }

  static String? _normalizedImageUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    if (trimmed.startsWith('http://')) {
      return trimmed.replaceFirst('http://', 'https://');
    }
    return trimmed;
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
