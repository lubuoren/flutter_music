import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/audio/music_audio_handler.dart';
import '../../../data/local/local_music_repository.dart';
import '../../../data/models/track.dart';
import 'player_state.dart';

final musicAudioHandlerProvider = Provider<MusicAudioHandler>((ref) {
  throw UnimplementedError(
    'MusicAudioHandler must be provided by ProviderScope.',
  );
});

final musicPlayerControllerProvider =
    StateNotifierProvider<MusicPlayerController, MusicPlayerState>((ref) {
      return MusicPlayerController(ref);
    });

class MusicPlayerController extends StateNotifier<MusicPlayerState> {
  MusicPlayerController(this._ref) : super(const MusicPlayerState()) {
    _handler = _ref.read(musicAudioHandlerProvider);
    _player = _handler.player;
    _subscriptions.addAll([
      _player.playerStateStream.listen(_onPlayerStateChanged),
      _player.positionStream.listen((position) {
        state = state.copyWith(position: position);
      }),
      _player.bufferedPositionStream.listen((position) {
        state = state.copyWith(bufferedPosition: position);
      }),
      _player.durationStream.listen((duration) {
        state = state.copyWith(
          duration: duration,
          clearDuration: duration == null,
        );
      }),
      _player.currentIndexStream.listen((index) {
        state = state.copyWith(
          currentIndex: index,
          clearCurrentIndex: index == null,
        );
      }),
      _player.shuffleModeEnabledStream.listen((enabled) {
        state = state.copyWith(shuffleEnabled: enabled);
      }),
      _player.loopModeStream.listen((mode) {
        state = state.copyWith(loopMode: mode);
      }),
    ]);
  }

  final Ref _ref;
  late final MusicAudioHandler _handler;
  late final AudioPlayer _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    final playableTracks = tracks.where(_canPlay).toList();
    if (playableTracks.isEmpty) {
      state = state.copyWith(errorMessage: '队列中没有可播放的本地歌曲');
      return;
    }

    final index = startIndex.clamp(0, playableTracks.length - 1);
    try {
      state = state.copyWith(
        queue: playableTracks,
        currentIndex: index,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        clearError: true,
      );
      await _setQueue(playableTracks, startIndex: index);
      await _handler.play();
      _markCurrentTrackPlayed();
    } on Object catch (error) {
      state = state.copyWith(errorMessage: '播放失败：$error');
    }
  }

  Future<void> togglePlayPause() async {
    if (!state.hasQueue) {
      final localTracks = _ref.read(localMusicControllerProvider).tracks;
      if (localTracks.isNotEmpty) {
        await playQueue(localTracks);
      }
      return;
    }

    if (_player.playing) {
      await _handler.pause();
    } else {
      await _handler.play();
      _markCurrentTrackPlayed();
    }
  }

  Future<void> seek(Duration position) {
    return _handler.seek(position);
  }

  Future<void> playNext() async {
    if (!state.hasQueue) {
      return;
    }
    if (_player.hasNext) {
      await _handler.skipToNext();
    } else {
      await _player.seek(Duration.zero, index: 0);
    }
    await _handler.play();
    _markCurrentTrackPlayed();
  }

  Future<void> playPrevious() async {
    if (!state.hasQueue) {
      return;
    }
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) {
      await _handler.skipToPrevious();
    } else {
      await _player.seek(Duration.zero, index: state.queue.length - 1);
    }
    await _handler.play();
    _markCurrentTrackPlayed();
  }

  Future<void> toggleShuffle() async {
    final enabled = !_player.shuffleModeEnabled;
    await _player.setShuffleModeEnabled(enabled);
    if (enabled) {
      await _player.shuffle();
    }
  }

  Future<void> cycleLoopMode() async {
    final next = switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(next);
  }

  Future<void> removeFromQueue(Track track) async {
    final index = state.queue.indexWhere((item) => item.id == track.id);
    if (index < 0) {
      return;
    }

    final queue = [...state.queue]..removeAt(index);
    if (queue.isEmpty) {
      await _handler.stop();
      state = state.copyWith(
        queue: const [],
        clearCurrentIndex: true,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        clearDuration: true,
      );
      return;
    }

    final currentIndex = state.currentIndex ?? 0;
    final nextIndex = index < currentIndex
        ? currentIndex - 1
        : currentIndex.clamp(0, queue.length - 1);
    final wasPlaying = _player.playing;
    state = state.copyWith(queue: queue, currentIndex: nextIndex);
    await _setQueue(queue, startIndex: nextIndex);
    if (wasPlaying) {
      await _handler.play();
    }
  }

  Future<void> insertNext(Track track) async {
    if (!_canPlay(track)) {
      state = state.copyWith(errorMessage: '歌曲文件不存在或不可播放');
      return;
    }

    if (!state.hasQueue) {
      await playQueue([track]);
      return;
    }

    final currentIndex = state.currentIndex ?? 0;
    final queue = [...state.queue]
      ..removeWhere((item) => item.id == track.id)
      ..insert((currentIndex + 1).clamp(0, state.queue.length), track);
    final wasPlaying = _player.playing;
    state = state.copyWith(queue: queue);
    await _setQueue(queue, startIndex: currentIndex.clamp(0, queue.length - 1));
    if (wasPlaying) {
      await _handler.play();
    }
  }

  void updateTrackInQueue(Track track) {
    final index = state.queue.indexWhere((item) => item.id == track.id);
    if (index < 0) {
      return;
    }
    final queue = [...state.queue];
    queue[index] = track;
    state = state.copyWith(queue: queue);
  }

  void _onPlayerStateChanged(PlayerState playerState) {
    state = state.copyWith(
      isPlaying: playerState.playing,
      processingState: playerState.processingState,
    );
  }

  bool _canPlay(Track track) {
    final filePath = track.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      return File(filePath).existsSync();
    }
    return track.url != null;
  }

  Future<void> _setQueue(List<Track> tracks, {required int startIndex}) {
    return _handler.setTracks(tracks, startIndex: startIndex);
  }

  void _markCurrentTrackPlayed() {
    final track = state.currentTrack;
    if (track != null && track.type == TrackType.local) {
      unawaited(
        _ref.read(localMusicControllerProvider.notifier).markPlayed(track),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
