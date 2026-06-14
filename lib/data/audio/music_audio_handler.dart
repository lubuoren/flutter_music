import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';

class MusicAudioHandler extends BaseAudioHandler {
  MusicAudioHandler() {
    _subscriptions.addAll([
      player.playbackEventStream.listen(_broadcastState),
      player.currentIndexStream.listen(_broadcastCurrentItem),
    ]);
  }

  final AudioPlayer player = AudioPlayer();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// 当前音源；持有引用以便对队列做原地增删改而不整轮重建。
  ConcatenatingAudioSource? _source;

  Future<void> setTracks(
    List<Track> tracks, {
    required int startIndex,
    Duration? initialPosition,
  }) async {
    final mediaItems = tracks.map(_toMediaItem).toList();
    queue.add(mediaItems);
    mediaItem.add(
      startIndex >= 0 && startIndex < mediaItems.length
          ? mediaItems[startIndex]
          : null,
    );
    final source = ConcatenatingAudioSource(
      children: [for (final track in tracks) _audioSourceForTrack(track)],
    );
    _source = source;
    await player.setAudioSource(
      source,
      initialIndex: startIndex,
      initialPosition: initialPosition,
    );
  }

  /// 在 [index] 处插入一首（原地，不重建其他项）。无音源时退化为 setTracks。
  Future<void> insertTrack(int index, Track track) async {
    final source = _source;
    if (source == null) {
      await setTracks([track], startIndex: 0);
      return;
    }
    final items = [...queue.value];
    final clamped = index < 0
        ? 0
        : (index > items.length ? items.length : index);
    items.insert(clamped, _toMediaItem(track));
    queue.add(items);
    await source.insert(clamped, _audioSourceForTrack(track));
  }

  /// 移除 [index] 处的一首（原地）。
  Future<void> removeTrackAt(int index) async {
    final source = _source;
    if (source == null || index < 0 || index >= source.length) {
      return;
    }
    final items = [...queue.value];
    if (index < items.length) {
      items.removeAt(index);
      queue.add(items);
    }
    await source.removeAt(index);
  }

  /// 用 [track] 替换 [index] 处的音源（把静音占位换成已解析曲）。
  ///
  /// 仅应在 [index] 不是当前播放项时调用，避免打断当前曲。
  Future<void> replaceTrackAt(int index, Track track) async {
    final source = _source;
    if (source == null || index < 0 || index >= source.length) {
      return;
    }
    final items = [...queue.value];
    if (index < items.length) {
      items[index] = _toMediaItem(track);
      queue.add(items);
    }
    await source.removeAt(index);
    await source.insert(index, _audioSourceForTrack(track));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => player.seekToNext();

  @override
  Future<void> skipToPrevious() => player.seekToPrevious();

  @override
  Future<void> stop() async {
    await player.stop();
    playbackState.add(
      playbackState.value.copyWith(processingState: AudioProcessingState.idle),
    );
  }

  void destroy() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(player.dispose());
    unawaited(playbackState.close());
    unawaited(queue.close());
    unawaited(queueTitle.close());
    unawaited(mediaItem.close());
    unawaited(androidPlaybackInfo.close());
    unawaited(ratingStyle.close());
    unawaited(customEvent.close());
    unawaited(customState.close());
  }

  void _broadcastCurrentItem(int? index) {
    final items = queue.value;
    if (index == null || index < 0 || index >= items.length) {
      mediaItem.add(null);
      return;
    }
    mediaItem.add(items[index]);
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _audioProcessingState(player.processingState),
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: player.currentIndex,
      ),
    );
  }

  AudioProcessingState _audioProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  MediaItem _toMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artists.join(' / '),
      album: track.album,
      duration: track.durationMs == 0 ? null : track.duration,
      artUri: _artUri(track.coverUrl),
      extras: {
        'source': track.source,
        'type': track.type.name,
        'filePath': track.filePath,
      },
    );
  }

  /// 为歌曲构建音源：已有播放地址用真实音源；未解析的在线曲用静音占位，
  /// 保持音源与队列索引对齐，解析完再用 [replaceTrackAt] 换回真实音源。
  AudioSource _audioSourceForTrack(Track track) {
    final uri = _playableUri(track);
    if (uri != null) {
      return AudioSource.uri(uri, tag: track.id);
    }
    return SilenceAudioSource(
      tag: track.id,
      duration: track.durationMs == 0
          ? const Duration(seconds: 1)
          : track.duration,
    );
  }

  Uri? _playableUri(Track track) {
    final url = track.url?.trim();
    if (url != null && url.isNotEmpty) {
      return Uri.parse(url);
    }
    final filePath = track.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      return Uri.file(filePath);
    }
    return null;
  }

  Uri? _artUri(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'file')) {
      return uri;
    }
    return Uri.file(value);
  }
}
