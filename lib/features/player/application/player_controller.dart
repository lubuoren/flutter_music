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
import 'now_playing_repository.dart';
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
        _maybePersistPosition(position);
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
        unawaited(_ensureCurrentResolved());
        _scheduleSave();
      }),
      _player.shuffleModeEnabledStream.listen((enabled) {
        state = state.copyWith(shuffleEnabled: enabled);
      }),
      _player.loopModeStream.listen((mode) {
        state = state.copyWith(loopMode: mode);
      }),
    ]);
    unawaited(_restoreNowPlaying());
  }

  final Ref _ref;
  late final MusicAudioHandler _handler;
  late final AudioPlayer _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Set<String> _loadingLyricsTrackIds = {};

  /// 当前曲目是否已计入播放次数；曲目切换或重新播放队列时重置。
  bool _playCounted = false;

  /// 队列「代」号；每次设置新队列自增，用于让旧队列的后台解析任务尽早退出。
  int _queueGeneration = 0;

  /// 「正在播放」队列的持久化；用于重开恢复上次队列与进度。
  final NowPlayingRepository _nowPlaying = NowPlayingRepository();
  Timer? _saveTimer;
  int _lastSavedPositionSec = -1;

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
      _queueGeneration++;
      await _setQueue(playableTracks, startIndex: index);
      _loadLyricsForCurrentTrack();
      await _handler.play();
    } on Object catch (error) {
      state = state.copyWith(errorMessage: '播放失败：$error');
    }
  }

  /// 在线队列「秒播 + 后台解析」：先只解析起始曲并立即播放，其余曲目以静音
  /// 占位入队，随后在后台逐个解析并替换为真实音源（不走 `_canPlay` 过滤）。
  Future<void> playQueueLazy(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) {
      state = state.copyWith(errorMessage: '歌单中没有歌曲');
      return;
    }
    final index = _clampIndex(startIndex, tracks.length);
    final generation = ++_queueGeneration;
    _playCounted = false;
    try {
      final resolvedStart = await _resolvePlayable(tracks[index]);
      final queue = [...tracks];
      queue[index] = resolvedStart;
      state = state.copyWith(
        queue: queue,
        currentIndex: index,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        clearError: true,
      );
      await _setQueue(queue, startIndex: index);
      _loadLyricsForCurrentTrack();
      await _handler.play();
      unawaited(_resolveQueueInBackground(generation, index));
    } on Object catch (error) {
      state = state.copyWith(errorMessage: _playbackErrorText(error));
    }
  }

  /// 解析在线曲的播放地址（已解析或非在线曲原样返回），并应用歌词 offset。
  /// 仅解析 URL（封面来自歌单数据、歌词随播放单独加载），保持后台批量解析轻量。
  Future<Track> _resolvePlayable(Track track) async {
    if (track.type != TrackType.online) {
      return track;
    }
    final url = track.url?.trim();
    if (url != null && url.isNotEmpty) {
      return track;
    }
    final resolved = await _musicRepository().resolvePlaybackUrl(track);
    return _ref.read(lyricOffsetRepositoryProvider).applyOffset(resolved);
  }

  /// 确保 [index] 处的在线曲已解析；若是当前曲则替换后重新定位到它。
  Future<void> _ensureResolvedAt(int index) async {
    if (index < 0 || index >= state.queue.length) {
      return;
    }
    final track = state.queue[index];
    if (track.type != TrackType.online) {
      return;
    }
    final existing = track.url?.trim();
    if (existing != null && existing.isNotEmpty) {
      return;
    }
    final Track resolved;
    try {
      resolved = await _resolvePlayable(track);
    } on Object catch (error) {
      state = state.copyWith(errorMessage: _playbackErrorText(error));
      return;
    }
    if (index >= state.queue.length || state.queue[index].id != track.id) {
      return;
    }
    updateTrackInQueue(resolved);
    await _handler.replaceTrackAt(index, resolved);
    if (index == (state.currentIndex ?? -1)) {
      await _player.seek(Duration.zero, index: index);
    }
  }

  /// 当前曲若是未解析占位，解析并恢复播放态（跳到未解析曲、恢复后按播放时兜底）。
  Future<void> _ensureCurrentResolved() async {
    final index = state.currentIndex;
    if (index == null || index < 0 || index >= state.queue.length) {
      return;
    }
    final track = state.queue[index];
    if (track.type != TrackType.online) {
      return;
    }
    final url = track.url?.trim();
    if (url != null && url.isNotEmpty) {
      return;
    }
    final wasPlaying = _player.playing;
    await _ensureResolvedAt(index);
    if (wasPlaying) {
      await _handler.play();
    }
  }

  /// 后台按「当前→之后→之前」顺序解析其余未解析的在线曲，逐个原地替换。
  /// 当前曲交由 [_ensureCurrentResolved] 处理，这里跳过以免打断播放。
  Future<void> _resolveQueueInBackground(int generation, int startIndex) async {
    final order = <int>[
      for (var i = startIndex; i < state.queue.length; i++) i,
      for (var i = 0; i < startIndex; i++) i,
    ];
    for (final position in order) {
      if (generation != _queueGeneration) {
        return;
      }
      if (position >= state.queue.length) {
        continue;
      }
      final track = state.queue[position];
      if (track.type != TrackType.online) {
        continue;
      }
      final url = track.url?.trim();
      if (url != null && url.isNotEmpty) {
        continue;
      }
      try {
        final resolved = await _resolvePlayable(track);
        if (generation != _queueGeneration) {
          return;
        }
        final idx = state.queue.indexWhere(
          (item) => item.id == track.id && (item.url?.trim().isEmpty ?? true),
        );
        if (idx < 0 || idx == state.currentIndex) {
          continue;
        }
        updateTrackInQueue(resolved);
        await _handler.replaceTrackAt(idx, resolved);
      } on Object {
        // 单曲解析失败不影响其他曲。
      }
    }
  }

  String _playbackErrorText(Object error) {
    if (error is NeteaseApiException) {
      return error.isUnauthorized ? '网易云登录态已失效' : error.message;
    }
    return '播放失败：$error';
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
      await _ensureResolvedAt(state.currentIndex ?? 0);
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

    if (state.queue.length == 1) {
      await _handler.stop();
      state = state.copyWith(
        queue: const [],
        clearCurrentIndex: true,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        clearDuration: true,
      );
      unawaited(_persistNowPlaying());
      return;
    }

    final queue = [...state.queue]..removeAt(index);
    final currentIndex = state.currentIndex ?? 0;
    final newIndex = index < currentIndex
        ? currentIndex - 1
        : _clampIndex(currentIndex, queue.length);
    state = state.copyWith(queue: queue, currentIndex: newIndex);
    // 原地移除：just_audio 自动衔接——移除当前曲会无缝进入下一首，
    // 移除其他曲不打断当前播放，避免整轮重建造成的卡顿。
    await _handler.removeTrackAt(index);
    _scheduleSave();
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
    await _insertAfterCurrent(track);
  }

  /// 把 [track] 插入到当前曲之后并立即跳转播放；无队列时直接播放。
  ///
  /// 用于搜索点歌等「不清空队列、插播一首」的场景。
  Future<void> insertAndPlay(Track track) async {
    if (!state.hasQueue) {
      await playQueue([track]);
      return;
    }
    final target = await _insertAfterCurrent(track);
    await _player.seek(Duration.zero, index: target);
    await _handler.play();
  }

  /// 把 [track] 原地插入到当前曲之后（不重建音源）。返回插入后的索引。
  Future<int> _insertAfterCurrent(Track track) async {
    final queue = [...state.queue];
    final currentIndex = _clampIndex(state.currentIndex ?? 0, queue.length);
    final target = _clampInsertIndex(currentIndex + 1, queue.length);
    queue.insert(target, track);
    state = state.copyWith(queue: queue);
    await _handler.insertTrack(target, track);
    _scheduleSave();
    return target;
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
    if (!playerState.playing) {
      _scheduleSave();
    }
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

  Future<void> _restoreNowPlaying() async {
    if (state.hasQueue) {
      return;
    }
    final snapshot = await _nowPlaying.load();
    if (snapshot == null ||
        snapshot.tracks.isEmpty ||
        !mounted ||
        state.hasQueue) {
      return;
    }
    final index = snapshot.currentIndex == null
        ? 0
        : _clampIndex(snapshot.currentIndex!, snapshot.tracks.length);
    _queueGeneration++;
    state = state.copyWith(
      queue: snapshot.tracks,
      currentIndex: index,
      position: snapshot.position,
    );
    try {
      await _setQueue(
        snapshot.tracks,
        startIndex: index,
        initialPosition: snapshot.position,
      );
    } on Object {
      // 恢复失败不影响启动。
    }
    // 不自动播放：当前在线曲为未解析占位，首次播放时由 _ensureResolvedAt 懒解析。
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_persistNowPlaying());
    });
  }

  Future<void> _persistNowPlaying() async {
    await _nowPlaying.save(state.queue, state.currentIndex, state.position);
  }

  /// 播放中每跨越 10 秒整就持久化一次进度，避免频繁写库又能较好恢复位置。
  void _maybePersistPosition(Duration position) {
    if (!state.hasQueue) {
      return;
    }
    final seconds = position.inSeconds;
    if (seconds != _lastSavedPositionSec && seconds > 0 && seconds % 10 == 0) {
      _lastSavedPositionSec = seconds;
      unawaited(_persistNowPlaying());
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_persistNowPlaying());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
