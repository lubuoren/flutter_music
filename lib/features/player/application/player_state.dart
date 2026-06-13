import 'package:just_audio/just_audio.dart';

import '../../../data/models/track.dart';

class MusicPlayerState {
  const MusicPlayerState({
    this.queue = const [],
    this.currentIndex,
    this.isPlaying = false,
    this.processingState = ProcessingState.idle,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration,
    this.shuffleEnabled = false,
    this.loopMode = LoopMode.off,
    this.errorMessage,
  });

  final List<Track> queue;
  final int? currentIndex;
  final bool isPlaying;
  final ProcessingState processingState;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  final bool shuffleEnabled;
  final LoopMode loopMode;
  final String? errorMessage;

  Track? get currentTrack {
    final index = currentIndex;
    if (index == null || index < 0 || index >= queue.length) {
      return null;
    }
    return queue[index];
  }

  bool get hasPrevious => queue.length > 1;
  bool get hasNext => queue.length > 1;
  bool get hasQueue => queue.isNotEmpty;

  MusicPlayerState copyWith({
    List<Track>? queue,
    int? currentIndex,
    bool clearCurrentIndex = false,
    bool? isPlaying,
    ProcessingState? processingState,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    bool clearDuration = false,
    bool? shuffleEnabled,
    LoopMode? loopMode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MusicPlayerState(
      queue: queue ?? this.queue,
      currentIndex: clearCurrentIndex
          ? null
          : currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      processingState: processingState ?? this.processingState,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: clearDuration ? null : duration ?? this.duration,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      loopMode: loopMode ?? this.loopMode,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
