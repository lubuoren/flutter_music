import 'dart:async';
import 'dart:io';

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

  Future<void> setTracks(List<Track> tracks, {required int startIndex}) async {
    final mediaItems = tracks.map(_toMediaItem).toList();
    queue.add(mediaItems);
    mediaItem.add(
      startIndex >= 0 && startIndex < mediaItems.length
          ? mediaItems[startIndex]
          : null,
    );
    await player.setAudioSource(
      ConcatenatingAudioSource(
        children: [
          for (final track in tracks)
            AudioSource.uri(_trackUri(track), tag: track.id),
        ],
      ),
      initialIndex: startIndex,
    );
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
      artUri: track.coverUrl == null ? null : Uri.file(track.coverUrl!),
      extras: {
        'source': track.source,
        'type': track.type.name,
        'filePath': track.filePath,
      },
    );
  }

  Uri _trackUri(Track track) {
    final filePath = track.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      return Uri.file(File(filePath).absolute.path);
    }
    return Uri.parse(track.url!);
  }
}
