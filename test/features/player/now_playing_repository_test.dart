import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/models/track.dart';
import 'package:flutter_music/features/player/application/now_playing_repository.dart';

void main() {
  group('encode/decodeNowPlaying', () {
    test('往返保留 index 与 position；在线曲清空 url、本地曲保留 filePath', () {
      const tracks = [
        Track(
          id: '1',
          title: 'Online',
          artists: ['A'],
          type: TrackType.online,
          source: 'netease',
          url: 'https://music/stream.mp3',
        ),
        Track(
          id: '2',
          title: 'Local',
          artists: ['B'],
          type: TrackType.local,
          filePath: '/music/b.flac',
        ),
      ];

      final snapshot = decodeNowPlaying(
        encodeNowPlaying(tracks, 1, const Duration(seconds: 42)),
      )!;

      expect(snapshot.tracks, hasLength(2));
      expect(snapshot.currentIndex, 1);
      expect(snapshot.position, const Duration(seconds: 42));
      // 在线曲播放地址会过期，应清空以便恢复后懒解析。
      expect(snapshot.tracks[0].url, '');
      expect(snapshot.tracks[0].id, '1');
      expect(snapshot.tracks[1].filePath, '/music/b.flac');
    });

    test('空、损坏或无歌曲均返回 null', () {
      expect(decodeNowPlaying(null), isNull);
      expect(decodeNowPlaying(''), isNull);
      expect(decodeNowPlaying('not json'), isNull);
      expect(decodeNowPlaying('{"tracks":[]}'), isNull);
    });
  });
}
