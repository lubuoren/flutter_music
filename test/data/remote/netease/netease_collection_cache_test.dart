import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/models/playlist.dart';
import 'package:flutter_music/data/models/track.dart';
import 'package:flutter_music/data/remote/netease/netease_collection_cache.dart';

void main() {
  group('encode/decodeCachedCollection', () {
    test('往返保留歌单与写入时间', () {
      const playlist = Playlist(
        id: 'album:1',
        name: 'Album',
        source: 'netease',
        trackCount: 1,
        tracks: [
          Track(id: '9', title: 'Song', artists: ['A'], type: TrackType.online),
        ],
      );

      final cached = decodeCachedCollection(
        encodeCachedCollection(playlist, 1700000000000),
      )!;

      expect(cached.savedAtMs, 1700000000000);
      expect(cached.playlist.id, 'album:1');
      expect(cached.playlist.name, 'Album');
      expect(cached.playlist.tracks.single.id, '9');
    });

    test('空或损坏返回 null', () {
      expect(decodeCachedCollection(null), isNull);
      expect(decodeCachedCollection(''), isNull);
      expect(decodeCachedCollection('oops'), isNull);
    });
  });

  group('isCacheFresh', () {
    test('TTL 内为新鲜', () {
      expect(
        isCacheFresh(1000, 1000 + 60 * 1000, const Duration(hours: 1)),
        isTrue,
      );
    });

    test('超过 TTL 为过期', () {
      expect(
        isCacheFresh(1000, 1000 + 2 * 3600 * 1000, const Duration(hours: 1)),
        isFalse,
      );
    });

    test('写入时间晚于当前视为过期（时钟异常）', () {
      expect(isCacheFresh(5000, 1000, const Duration(hours: 1)), isFalse);
    });
  });
}
