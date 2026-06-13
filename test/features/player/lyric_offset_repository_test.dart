import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_music/data/models/track.dart';
import 'package:flutter_music/features/player/application/lyric_offset_repository.dart';

void main() {
  group('LyricOffsetRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('保存并应用云端歌曲歌词偏移', () async {
      final repository = LyricOffsetRepository();
      const track = Track(
        id: '123',
        title: 'Cloud Song',
        artists: ['Artist'],
        source: 'netease',
      );

      await repository.saveOffset(track, 0.5);
      final updated = await repository.applyOffset(track);

      expect(updated.offset, 0.5);
    });

    test('重置为 0 时覆盖旧偏移', () async {
      final repository = LyricOffsetRepository();
      const track = Track(
        id: '123',
        title: 'Cloud Song',
        artists: ['Artist'],
        source: 'netease',
      );

      await repository.saveOffset(track, 1.5);
      final staleTrack = track.copyWith(offset: 1.5);
      await repository.saveOffset(staleTrack, 0);
      final updated = await repository.applyOffset(staleTrack);

      expect(updated.offset, 0);
    });
  });
}
