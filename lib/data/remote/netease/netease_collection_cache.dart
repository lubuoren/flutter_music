import 'dart:convert';

import '../../local/database/app_database.dart';
import '../../models/playlist.dart';

/// 缓存的歌单/专辑/艺术家合辑及其写入时间。
class CachedCollection {
  const CachedCollection({required this.playlist, required this.savedAtMs});

  final Playlist playlist;
  final int savedAtMs;
}

/// 序列化缓存信封：写入时间 + 歌单内容。
String encodeCachedCollection(Playlist playlist, int savedAtMs) {
  return jsonEncode({'savedAtMs': savedAtMs, 'playlist': playlist.toJson()});
}

/// 反序列化缓存信封；为空或损坏时返回 null。
CachedCollection? decodeCachedCollection(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final playlistJson = decoded['playlist'];
    if (playlistJson is! Map) {
      return null;
    }
    final savedAtMs = decoded['savedAtMs'];
    return CachedCollection(
      playlist: Playlist.fromJson(Map<String, Object?>.from(playlistJson)),
      savedAtMs: savedAtMs is int ? savedAtMs : 0,
    );
  } on Object {
    return null;
  }
}

/// 缓存是否仍在 [ttl] 内（同时排除写入时间晚于当前的时钟异常）。
bool isCacheFresh(int savedAtMs, int nowMs, Duration ttl) {
  return nowMs >= savedAtMs && nowMs - savedAtMs < ttl.inMilliseconds;
}

/// 用 `app_data` 缓存网易云合辑，支持「先出缓存、过期再刷新」。
class NeteaseCollectionCache {
  static String _keyFor(String id) => 'netease.collection.$id';

  Future<void> save(String id, Playlist playlist, {required int nowMs}) async {
    await AppDatabase.instance.setAppData(
      _keyFor(id),
      encodeCachedCollection(playlist, nowMs),
    );
  }

  Future<CachedCollection?> load(String id) async {
    final raw = await AppDatabase.instance.getAppData(_keyFor(id));
    return decodeCachedCollection(raw);
  }
}
