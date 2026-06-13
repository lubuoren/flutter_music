import '../models/track.dart';

class LocalMusicState {
  const LocalMusicState({
    this.tracks = const [],
    this.scanDirectories = const [],
    this.isScanning = false,
    this.lastScannedAt,
    this.errorMessage,
  });

  final List<Track> tracks;
  final List<String> scanDirectories;
  final bool isScanning;
  final DateTime? lastScannedAt;
  final String? errorMessage;

  bool get hasLibrary => tracks.isNotEmpty;

  LocalMusicState copyWith({
    List<Track>? tracks,
    List<String>? scanDirectories,
    bool? isScanning,
    DateTime? lastScannedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocalMusicState(
      tracks: tracks ?? this.tracks,
      scanDirectories: scanDirectories ?? this.scanDirectories,
      isScanning: isScanning ?? this.isScanning,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
