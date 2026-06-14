import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/models/track.dart';

void main() {
  group('Track', () {
    test('toJson/fromJson 往返保留 albumId 与 artistIds', () {
      const track = Track(
        id: '1',
        title: 'T',
        artists: ['A', 'B'],
        albumId: '55',
        artistIds: ['11', '22'],
      );

      final restored = Track.fromJson(track.toJson());

      expect(restored.albumId, '55');
      expect(restored.artistIds, ['11', '22']);
    });

    test('fromJson 缺少 albumId/artistIds 时使用安全默认值', () {
      final restored = Track.fromJson({'id': '1', 'title': 'T'});

      expect(restored.albumId, isNull);
      expect(restored.artistIds, isEmpty);
    });
  });
}
