/// 歌曲来源类型，对应 VutronMusic 的 TrackSourceType / source 字段。
enum TrackType { local, online, stream }

TrackType trackTypeFromName(String? value) {
  return TrackType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => TrackType.online,
  );
}

/// 统一歌曲模型。
///
/// 同时覆盖 VutronMusic 的本地歌曲、网易云在线歌曲与流媒体歌曲，
/// 对应原项目 `Track` 类型以及数据库 `Track` 表中的 json 字段。
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artists,
    this.album,
    this.durationMs = 0,
    this.type = TrackType.online,
    this.source,
    this.filePath,
    this.coverUrl,
    this.url,
    this.lyrics,
    this.fileSizeBytes,
    this.matched = false,
    this.cache = false,
    this.offset = 0,
    this.md5,
    this.playCount = 0,
    this.isLiked = false,
    this.lastPlayedAt,
    this.addedAt,
  });

  final String id;
  final String title;
  final List<String> artists;
  final String? album;

  /// 时长，毫秒。对应原项目 dt / duration 字段。
  final int durationMs;

  final TrackType type;

  /// 具体音源，例如 localTrack / netease / navidrome / emby / qq 等。
  final String? source;

  final String? filePath;
  final String? coverUrl;
  final String? url;
  final String? lyrics;
  final int? fileSizeBytes;

  /// 是否已完成在线信息匹配。
  final bool matched;

  /// 是否命中本地缓存。
  final bool cache;

  /// 歌词偏移（秒）。
  final double offset;

  final String? md5;
  final int playCount;
  final bool isLiked;
  final DateTime? lastPlayedAt;
  final DateTime? addedAt;

  Duration get duration => Duration(milliseconds: durationMs);

  Track copyWith({
    String? id,
    String? title,
    List<String>? artists,
    String? album,
    int? durationMs,
    TrackType? type,
    String? source,
    String? filePath,
    String? coverUrl,
    String? url,
    String? lyrics,
    int? fileSizeBytes,
    bool? matched,
    bool? cache,
    double? offset,
    String? md5,
    int? playCount,
    bool? isLiked,
    DateTime? lastPlayedAt,
    DateTime? addedAt,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      type: type ?? this.type,
      source: source ?? this.source,
      filePath: filePath ?? this.filePath,
      coverUrl: coverUrl ?? this.coverUrl,
      url: url ?? this.url,
      lyrics: lyrics ?? this.lyrics,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      matched: matched ?? this.matched,
      cache: cache ?? this.cache,
      offset: offset ?? this.offset,
      md5: md5 ?? this.md5,
      playCount: playCount ?? this.playCount,
      isLiked: isLiked ?? this.isLiked,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'artists': artists,
      'album': album,
      'durationMs': durationMs,
      'type': type.name,
      'source': source,
      'filePath': filePath,
      'coverUrl': coverUrl,
      'url': url,
      'lyrics': lyrics,
      'fileSizeBytes': fileSizeBytes,
      'matched': matched,
      'cache': cache,
      'offset': offset,
      'md5': md5,
      'playCount': playCount,
      'isLiked': isLiked,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'addedAt': addedAt?.toIso8601String(),
    };
  }

  factory Track.fromJson(Map<String, Object?> json) {
    final artists = json['artists'];

    return Track(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '未知歌曲',
      artists: artists is List
          ? artists.whereType<String>().toList()
          : const ['未知艺术家'],
      album: json['album'] as String?,
      durationMs: json['durationMs'] as int? ?? 0,
      type: trackTypeFromName(json['type'] as String?),
      source: json['source'] as String?,
      filePath: json['filePath'] as String?,
      coverUrl: json['coverUrl'] as String?,
      url: json['url'] as String?,
      lyrics: json['lyrics'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int?,
      matched: json['matched'] as bool? ?? false,
      cache: json['cache'] as bool? ?? false,
      offset: (json['offset'] as num?)?.toDouble() ?? 0,
      md5: json['md5'] as String?,
      playCount: json['playCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      lastPlayedAt: _dateTimeFromJson(json['lastPlayedAt']),
      addedAt: _dateTimeFromJson(json['addedAt']),
    );
  }
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
