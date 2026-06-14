import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/lrc_parser.dart';
import '../../../data/models/lyric_line.dart';
import 'player_controller.dart';

class LyricState {
  const LyricState({
    this.lines = const [],
    this.currentIndex,
    this.trackId,
    this.secondaryTextMode = LyricSecondaryTextMode.translation,
  });

  final List<LyricLine> lines;
  final int? currentIndex;
  final String? trackId;
  final LyricSecondaryTextMode secondaryTextMode;

  bool get hasLyrics => lines.isNotEmpty;
  bool get hasSecondaryTextAlternatives {
    return lines.any((line) => line.hasSecondaryAlternatives);
  }

  LyricState copyWith({
    List<LyricLine>? lines,
    int? currentIndex,
    bool clearCurrentIndex = false,
    String? trackId,
    bool clearTrackId = false,
    LyricSecondaryTextMode? secondaryTextMode,
  }) {
    return LyricState(
      lines: lines ?? this.lines,
      currentIndex: clearCurrentIndex
          ? null
          : currentIndex ?? this.currentIndex,
      trackId: clearTrackId ? null : trackId ?? this.trackId,
      secondaryTextMode: secondaryTextMode ?? this.secondaryTextMode,
    );
  }
}

final lyricControllerProvider =
    StateNotifierProvider<LyricController, LyricState>((ref) {
      return LyricController(ref);
    });

class LyricController extends StateNotifier<LyricState> {
  LyricController(this._ref) : super(const LyricState()) {
    final player = _ref.read(musicPlayerControllerProvider);
    _onTrackChanged(player.currentTrack?.lyrics, player.currentTrack?.id);
    _onPositionChanged(player.position);

    _ref.listen(
      musicPlayerControllerProvider.select((state) => state.currentTrack),
      (previous, next) {
        _onTrackChanged(next?.lyrics, next?.id);
      },
    );
    _ref.listen(
      musicPlayerControllerProvider.select((state) => state.position),
      (previous, next) {
        _onPositionChanged(next);
      },
    );
  }

  final Ref _ref;
  var _trackRequestId = 0;

  void _onTrackChanged(String? lyricsRaw, String? trackId) {
    final requestId = ++_trackRequestId;
    if (lyricsRaw == null || lyricsRaw.trim().isEmpty) {
      state = state.copyWith(
        lines: const [],
        clearCurrentIndex: true,
        trackId: trackId,
      );
      return;
    }

    state = state.copyWith(
      lines: const [],
      clearCurrentIndex: true,
      trackId: trackId,
    );
    unawaited(
      compute(parseLrc, lyricsRaw)
          .then((lines) {
            if (!mounted || requestId != _trackRequestId) {
              return;
            }
            state = state.copyWith(
              lines: lines,
              clearCurrentIndex: true,
              trackId: trackId,
              secondaryTextMode:
                  lines.any((line) => line.hasSecondaryAlternatives)
                  ? state.secondaryTextMode
                  : LyricSecondaryTextMode.translation,
            );
            _onPositionChanged(
              _ref.read(musicPlayerControllerProvider).position,
            );
          })
          .catchError((Object _) {}),
    );
  }

  void setSecondaryTextMode(LyricSecondaryTextMode mode) {
    if (mode == state.secondaryTextMode ||
        !state.hasSecondaryTextAlternatives) {
      return;
    }
    state = state.copyWith(secondaryTextMode: mode);
  }

  void _onPositionChanged(Duration position) {
    final lines = state.lines;
    if (lines.isEmpty) {
      return;
    }

    final offsetMs =
        ((_ref.read(musicPlayerControllerProvider).currentTrack?.offset ?? 0) *
                1000)
            .round();
    final positionMs = position.inMilliseconds + offsetMs;
    // 用二分查找找到当前行
    final newIndex = _binarySearch(lines, positionMs);
    if (newIndex != state.currentIndex) {
      state = state.copyWith(currentIndex: newIndex);
    }
  }

  /// 二分查找返回 `positionMs` 所在的歌词行索引。
  /// 返回 `start <= positionMs < end` 的第一行；如果没有匹配，返回 -1。
  int? _binarySearch(List<LyricLine> lines, int positionMs) {
    // 优化：如果当前行仍然有效，直接返回
    final currentIndex = state.currentIndex;
    if (currentIndex != null &&
        currentIndex >= 0 &&
        currentIndex < lines.length) {
      final currentLine = lines[currentIndex];
      if (positionMs >= currentLine.start && positionMs < currentLine.end) {
        return currentIndex;
      }
    }

    // 二分查找
    var lo = 0;
    var hi = lines.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final line = lines[mid];
      if (positionMs >= line.start && positionMs < line.end) {
        return mid;
      }
      if (positionMs < line.start) {
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }

    // 如果 positionMs 在所有行之前，返回 null
    // 如果 positionMs 在所有行之后，返回最后一行
    if (lo >= lines.length) {
      return lines.length - 1;
    }
    return null;
  }
}
