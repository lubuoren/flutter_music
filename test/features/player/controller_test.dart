import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:flutter_music/data/models/track.dart';
import 'package:flutter_music/features/player/application/player_state.dart';

void main() {
  group('MusicPlayerState', () {
    test('初始状态默认值', () {
      const state = MusicPlayerState();
      expect(state.queue, isEmpty);
      expect(state.currentIndex, isNull);
      expect(state.isPlaying, isFalse);
      expect(state.processingState, ProcessingState.idle);
      expect(state.position, Duration.zero);
      expect(state.bufferedPosition, Duration.zero);
      expect(state.duration, isNull);
      expect(state.shuffleEnabled, isFalse);
      expect(state.loopMode, LoopMode.off);
      expect(state.errorMessage, isNull);
      expect(state.hasQueue, isFalse);
      expect(state.hasPrevious, isFalse);
      expect(state.hasNext, isFalse);
    });

    test('currentTrack 队列为空返回 null', () {
      const state = MusicPlayerState();
      expect(state.currentTrack, isNull);
    });

    test('currentTrack 有效索引返回对应 track', () {
      final track = Track(id: 'test', title: 'Test', artists: ['A']);
      final state = MusicPlayerState(queue: [track], currentIndex: 0);
      expect(state.currentTrack, track);
    });

    test('currentTrack 索引越界返回 null', () {
      final track = Track(id: 'test', title: 'Test', artists: ['A']);
      final state = MusicPlayerState(queue: [track], currentIndex: 5);
      expect(state.currentTrack, isNull);
    });

    test('hasQueue 非空队列为 true', () {
      final track = Track(id: 'test', title: 'Test', artists: ['A']);
      final state = MusicPlayerState(queue: [track]);
      expect(state.hasQueue, isTrue);
    });

    test('hasPrevious / hasNext 单个 track 为 false', () {
      final track = Track(id: 'test', title: 'Test', artists: ['A']);
      final state = MusicPlayerState(queue: [track], currentIndex: 0);
      expect(state.hasPrevious, isFalse);
      expect(state.hasNext, isFalse);
    });

    test('hasPrevious / hasNext 多个 track', () {
      final t1 = Track(id: '1', title: 'One', artists: ['A']);
      final t2 = Track(id: '2', title: 'Two', artists: ['A']);
      final t3 = Track(id: '3', title: 'Three', artists: ['A']);
      final state = MusicPlayerState(queue: [t1, t2, t3], currentIndex: 1);
      expect(state.hasPrevious, isTrue);
      expect(state.hasNext, isTrue);
    });

    test('copyWith 部分更新保留原有字段', () {
      const state = MusicPlayerState(isPlaying: false, loopMode: LoopMode.off);
      final updated = state.copyWith(isPlaying: true);
      expect(updated.isPlaying, isTrue);
      expect(updated.loopMode, LoopMode.off);
    });

    test('copyWith 清除值 (clear*)', () {
      final state = MusicPlayerState(
        duration: const Duration(seconds: 10),
        errorMessage: 'error',
        currentIndex: 3,
      );
      final cleared = state.copyWith(
        clearDuration: true,
        clearCurrentIndex: true,
        clearError: true,
      );
      expect(cleared.duration, isNull);
      expect(cleared.currentIndex, isNull);
      expect(cleared.errorMessage, isNull);
    });

    test('copyWith 队列更新', () {
      final t1 = Track(id: '1', title: 'A', artists: ['X']);
      final t2 = Track(id: '2', title: 'B', artists: ['Y']);
      const state = MusicPlayerState();
      final updated = state.copyWith(queue: [t1, t2], currentIndex: 0);
      expect(updated.queue.length, 2);
      expect(updated.currentIndex, 0);
    });

    test('currentTrack reflects updated queue metadata', () {
      final track = Track(id: '1', title: 'A', artists: ['X']);
      final state = MusicPlayerState(queue: [track], currentIndex: 0);
      final updatedTrack = track.copyWith(offset: 0.5);
      final updated = state.copyWith(queue: [updatedTrack]);

      expect(updated.currentTrack?.offset, 0.5);
    });
  });
}
