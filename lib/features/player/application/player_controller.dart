import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/platform/track_playability.dart';
import '../../../data/audio/music_audio_handler.dart';
import '../../../data/local/local_music_repository.dart';
import '../../../data/models/track.dart';
import '../../../data/remote/netease/netease_api_client.dart';
import '../../../data/remote/netease/netease_music_repository.dart';
import '../../login/application/netease_auth_controller.dart';
import '../../settings/application/app_settings_controller.dart';
import 'lyric_offset_repository.dart';
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
        _maybeCountPlay(position);
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
        _playCounted = false;
        state = state.copyWith(
          currentIndex: index,
          clearCurrentIndex: index == null,
        );
        _loadLyricsForCurrentTrack();
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
  final Set<String> _loadingLyricsTrackIds = {};

  /// 当前曲目是否已计入播放次数；曲目切换或重新播放队列时重置。
  bool _playCounted = false;

  /// 计入一次播放所需的最短收听时长（与「曲目时长一半」取较小值）。
  static const Duration _minPlayThreshold = Duration(seconds: 30);

  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    final playableTracks = tracks.where(_canPlay).toList();
    if (playableTracks.isEmpty) {
      state = state.copyWith(errorMessage: '队列中没有可播放的本地歌曲');
      return;
    }

    final index = _clampIndex(startIndex, playableTracks.length);
    try {
      state = state.copyWith(
        queue: playableTracks,
        currentIndex: index,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        clearError: true,
      );
      _playCounted = false;
      await _setQueue(playableTracks, startIndex: index);
      _loadLyricsForCurrentTrack();
      await _handler.play();
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
    var index = state.queue.indexWhere((item) => identical(item, track));
    if (index < 0) {
      index = state.queue.indexWhere((item) => item.id == track.id);
    }
    if (index < 0) {
      return;
    }

    final currentTrack = state.currentTrack;
    final currentPosition = _player.position;
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

    final currentIndex = _clampIndex(
      state.currentIndex ?? 0,
      state.queue.length,
    );
    final nextIndex = index < currentIndex
        ? currentIndex - 1
        : _clampIndex(currentIndex, queue.length);
    final shouldPreservePosition =
        currentTrack != null && identical(queue[nextIndex], currentTrack);
    final initialPosition = shouldPreservePosition ? currentPosition : null;
    final wasPlaying = _player.playing;
    state = state.copyWith(
      queue: queue,
      currentIndex: nextIndex,
      position: initialPosition ?? Duration.zero,
      bufferedPosition: shouldPreservePosition
          ? state.bufferedPosition
          : Duration.zero,
    );
    await _setQueue(
      queue,
      startIndex: nextIndex,
      initialPosition: initialPosition,
    );
    if (shouldPreservePosition) {
      state = state.copyWith(position: currentPosition);
    }
    _loadLyricsForCurrentTrack();
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

    final currentIndex = _clampIndex(
      state.currentIndex ?? 0,
      state.queue.length,
    );
    final currentTrack = state.currentTrack;
    final currentPosition = _player.position;
    var nextIndex = currentIndex;
    final queue = <Track>[];
    for (var index = 0; index < state.queue.length; index++) {
      final item = state.queue[index];
      if (index == currentIndex) {
        nextIndex = queue.length;
        queue.add(item);
      } else if (item.id != track.id) {
        queue.add(item);
      }
    }
    queue.insert(_clampInsertIndex(nextIndex + 1, queue.length), track);
    final shouldPreservePosition =
        currentTrack != null && identical(queue[nextIndex], currentTrack);
    final initialPosition = shouldPreservePosition ? currentPosition : null;
    final wasPlaying = _player.playing;
    state = state.copyWith(
      queue: queue,
      currentIndex: nextIndex,
      position: initialPosition ?? Duration.zero,
      bufferedPosition: shouldPreservePosition
          ? state.bufferedPosition
          : Duration.zero,
    );
    await _setQueue(
      queue,
      startIndex: nextIndex,
      initialPosition: initialPosition,
    );
    if (shouldPreservePosition) {
      state = state.copyWith(position: currentPosition);
    }
    _loadLyricsForCurrentTrack();
    if (wasPlaying) {
      await _handler.play();
    }
  }

  Future<Track> setLyricOffset(Track track, double offset) async {
    await _ref.read(lyricOffsetRepositoryProvider).saveOffset(track, offset);

    var updatedTrack = track.copyWith(offset: offset);
    if (track.type == TrackType.local) {
      updatedTrack =
          await _ref
              .read(localMusicControllerProvider.notifier)
              .setLyricOffset(track, offset) ??
          updatedTrack;
    }

    updateTrackInQueue(updatedTrack);
    return updatedTrack;
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
    return canPlayTrack(track);
  }

  Future<void> _setQueue(
    List<Track> tracks, {
    required int startIndex,
    Duration? initialPosition,
  }) {
    return _handler.setTracks(
      tracks,
      startIndex: startIndex,
      initialPosition: initialPosition,
    );
  }

  NeteaseMusicRepository _musicRepository() {
    final settings = _ref.read(appSettingsControllerProvider);
    final auth = _ref.read(neteaseAuthControllerProvider);
    return NeteaseMusicRepository(
      client: NeteaseApiClient(
        config: NeteaseApiConfig(
          baseUrl: settings.neteaseApiBaseUrl,
          cookie: auth.cookie,
        ),
      ),
    );
  }

  /// 在收听足够时长后，把当前曲目计入一次播放。
  ///
  /// 每个曲目实例最多计一次，由 [_playCounted] 在曲目切换时重置，避免暂停/恢复
  /// 或快速切歌造成重复计数，同时让自然播完自动进入下一首也能被正确计入。
  void _maybeCountPlay(Duration position) {
    if (_playCounted) {
      return;
    }
    final track = state.currentTrack;
    if (track == null) {
      return;
    }
    if (!reachedPlayThreshold(position, state.duration)) {
      return;
    }
    _playCounted = true;
    _recordPlayed(track);
  }

  /// 当前 [position] 是否已达到将曲目计入一次播放的阈值。
  ///
  /// 阈值取 [_minPlayThreshold] 与「[duration] 一半」中的较小值；时长未知时
  /// 退回 [_minPlayThreshold]。提取为静态纯函数以便单测。
  static bool reachedPlayThreshold(Duration position, Duration? duration) {
    final halfDuration = duration == null
        ? null
        : Duration(milliseconds: duration.inMilliseconds ~/ 2);
    final threshold = halfDuration == null || halfDuration > _minPlayThreshold
        ? _minPlayThreshold
        : halfDuration;
    return position >= threshold;
  }

  void _recordPlayed(Track track) {
    if (track.type == TrackType.local) {
      unawaited(
        _ref.read(localMusicControllerProvider.notifier).markPlayed(track),
      );
    }
  }

  void _loadLyricsForCurrentTrack() {
    final track = state.currentTrack;
    if (!_shouldLoadRemoteLyrics(track)) {
      return;
    }

    final trackId = track!.id;
    if (!_loadingLyricsTrackIds.add(trackId)) {
      return;
    }

    unawaited(
      _loadRemoteLyrics(track).whenComplete(() {
        _loadingLyricsTrackIds.remove(trackId);
      }),
    );
  }

  Future<void> _loadRemoteLyrics(Track track) async {
    try {
      await _ref.read(neteaseAuthControllerProvider.notifier).load();
      final updatedTrack = await _musicRepository().trackWithRemoteLyrics(
        track,
      );
      final lyrics = updatedTrack.lyrics;
      if (!mounted || lyrics == null || lyrics.trim().isEmpty) {
        return;
      }
      _mergeLyricsInQueue(track.id, lyrics);
    } on NeteaseApiException {
      // Lyrics should not interrupt playback.
    } on Object {
      // Lyrics should not interrupt playback.
    }
  }

  void _mergeLyricsInQueue(String trackId, String lyrics) {
    var changed = false;
    final queue = <Track>[];
    for (final item in state.queue) {
      final existingLyrics = item.lyrics?.trim();
      if (item.id == trackId &&
          (existingLyrics == null || existingLyrics.isEmpty)) {
        queue.add(item.copyWith(lyrics: lyrics));
        changed = true;
      } else {
        queue.add(item);
      }
    }
    if (changed) {
      state = state.copyWith(queue: queue);
    }
  }

  bool _shouldLoadRemoteLyrics(Track? track) {
    if (track == null || track.type != TrackType.online) {
      return false;
    }
    if (track.source != null && track.source != 'netease') {
      return false;
    }
    if (track.id.trim().isEmpty) {
      return false;
    }
    final lyrics = track.lyrics?.trim();
    return lyrics == null || lyrics.isEmpty;
  }

  int _clampIndex(int index, int length) {
    if (length <= 0 || index < 0) {
      return 0;
    }
    if (index >= length) {
      return length - 1;
    }
    return index;
  }

  int _clampInsertIndex(int index, int length) {
    if (index < 0) {
      return 0;
    }
    if (index > length) {
      return length;
    }
    return index;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
