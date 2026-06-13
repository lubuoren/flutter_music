import 'track.dart';

/// 统一歌单模型，覆盖网易云歌单、本地歌单与流媒体歌单。
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.creatorUserId,
    this.creatorName,
    this.source,
    this.trackCount = 0,
    this.isLocal = false,
    this.subscribed = false,
    this.tracks = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String? creatorUserId;
  final String? creatorName;

  /// 来源：netease / local / navidrome / jellyfin / emby。
  final String? source;

  final int trackCount;
  final bool isLocal;
  final bool subscribed;
  final List<Track> tracks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    String? creatorUserId,
    String? creatorName,
    String? source,
    int? trackCount,
    bool? isLocal,
    bool? subscribed,
    List<Track>? tracks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      creatorUserId: creatorUserId ?? this.creatorUserId,
      creatorName: creatorName ?? this.creatorName,
      source: source ?? this.source,
      trackCount: trackCount ?? this.trackCount,
      isLocal: isLocal ?? this.isLocal,
      subscribed: subscribed ?? this.subscribed,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverUrl': coverUrl,
      'creatorUserId': creatorUserId,
      'creatorName': creatorName,
      'source': source,
      'trackCount': trackCount,
      'isLocal': isLocal,
      'subscribed': subscribed,
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Playlist.fromJson(Map<String, Object?> json) {
    final tracksJson = json['tracks'];
    final tracks = tracksJson is List
        ? tracksJson
              .whereType<Map>()
              .map((item) => Track.fromJson(Map<String, Object?>.from(item)))
              .toList()
        : <Track>[];

    return Playlist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名歌单',
      description: json['description'] as String?,
      coverUrl: json['coverUrl'] as String?,
      creatorUserId: json['creatorUserId'] as String?,
      creatorName: json['creatorName'] as String?,
      source: json['source'] as String?,
      trackCount: json['trackCount'] as int? ?? tracks.length,
      isLocal: json['isLocal'] as bool? ?? false,
      subscribed: json['subscribed'] as bool? ?? false,
      tracks: tracks,
      createdAt: _dateTimeFromJson(json['createdAt']),
      updatedAt: _dateTimeFromJson(json['updatedAt']),
    );
  }
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
