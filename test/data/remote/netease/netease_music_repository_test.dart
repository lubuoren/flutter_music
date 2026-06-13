import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/remote/netease/netease_music_repository.dart';

void main() {
  group('NeteaseMusicRepository', () {
    test('tracksFromSearchJson maps api-enhanced search songs', () {
      final tracks = NeteaseMusicRepository.tracksFromSearchJson({
        'code': 200,
        'result': {
          'songs': [
            {
              'id': 123,
              'name': 'Song',
              'dt': 245000,
              'ar': [
                {'id': 1, 'name': 'Artist A'},
                {'id': 2, 'name': 'Artist B'},
              ],
              'al': {'id': 9, 'name': 'Album', 'picUrl': 'https://cover'},
            },
          ],
        },
      });

      expect(tracks, hasLength(1));
      expect(tracks.single.id, '123');
      expect(tracks.single.title, 'Song');
      expect(tracks.single.artists, ['Artist A', 'Artist B']);
      expect(tracks.single.album, 'Album');
      expect(tracks.single.durationMs, 245000);
      expect(tracks.single.source, 'netease');
      expect(tracks.single.coverUrl, 'https://cover');
    });

    test('tracksFromSearchJson tolerates empty result', () {
      expect(NeteaseMusicRepository.tracksFromSearchJson({}), isEmpty);
      expect(
        NeteaseMusicRepository.tracksFromSearchJson({
          'result': {'songs': []},
        }),
        isEmpty,
      );
    });
  });
}
