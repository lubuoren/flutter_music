import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/features/player/application/player_controller.dart';

void main() {
  group('MusicPlayerController.reachedPlayThreshold', () {
    test('时长未知时使用 30 秒下限', () {
      expect(
        MusicPlayerController.reachedPlayThreshold(
          const Duration(seconds: 29),
          null,
        ),
        isFalse,
      );
      expect(
        MusicPlayerController.reachedPlayThreshold(
          const Duration(seconds: 30),
          null,
        ),
        isTrue,
      );
    });

    test('长曲目在 30 秒处计入（时长一半 > 30 秒）', () {
      const duration = Duration(minutes: 4); // 一半 = 2 分钟
      expect(
        MusicPlayerController.reachedPlayThreshold(
          const Duration(seconds: 29),
          duration,
        ),
        isFalse,
      );
      expect(
        MusicPlayerController.reachedPlayThreshold(
          const Duration(seconds: 30),
          duration,
        ),
        isTrue,
      );
    });

    test('短曲目在时长一半处计入（一半 < 30 秒下限）', () {
      const duration = Duration(seconds: 20); // 一半 = 10 秒
      expect(
        MusicPlayerController.reachedPlayThreshold(
          const Duration(seconds: 9),
          duration,
        ),
        isFalse,
      );
      expect(
        MusicPlayerController.reachedPlayThreshold(
          const Duration(seconds: 10),
          duration,
        ),
        isTrue,
      );
    });
  });
}
