import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import 'database/app_database.dart';
import 'local_music_state.dart';
import 'local_music_platform.dart';

final localMusicRepositoryProvider = Provider<LocalMusicRepository>((ref) {
  return LocalMusicRepository();
});

final localMusicControllerProvider =
    StateNotifierProvider<LocalMusicController, LocalMusicState>((ref) {
      return LocalMusicController(ref.watch(localMusicRepositoryProvider))
        ..load();
    });

class LocalMusicController extends StateNotifier<LocalMusicState> {
  LocalMusicController(this._repository) : super(const LocalMusicState());

  final LocalMusicRepository _repository;

  Future<void> load() async {
    final snapshot = await _repository.loadLibrary();
    state = state.copyWith(
      tracks: snapshot.tracks,
      scanDirectories: snapshot.scanDirectories,
      lastScannedAt: snapshot.lastScannedAt,
      clearError: true,
    );
  }

  Future<void> pickAndScanDirectory() async {
    final directory = await _repository.pickDirectory();
    if (directory == null) {
      return;
    }
    await scanDirectory(directory);
  }

  Future<void> rescan() async {
    final directories = state.scanDirectories;
    if (directories.isEmpty) {
      await pickAndScanDirectory();
      return;
    }

    state = state.copyWith(isScanning: true, clearError: true);
    try {
      final tracks = <Track>[];
      for (final directory in directories) {
        tracks.addAll(await _repository.scanDirectory(directory));
      }
      final snapshot = LocalMusicSnapshot(
        tracks: _mergeTracks(tracks),
        scanDirectories: directories,
        lastScannedAt: DateTime.now(),
      );
      await _repository.saveLibrary(snapshot);
      state = state.copyWith(
        tracks: snapshot.tracks,
        lastScannedAt: snapshot.lastScannedAt,
        isScanning: false,
      );
    } on Object catch (error) {
      state = state.copyWith(isScanning: false, errorMessage: '扫描失败：$error');
    }
  }

  Future<void> scanDirectory(String directory) async {
    state = state.copyWith(isScanning: true, clearError: true);
    try {
      final tracks = await _repository.scanDirectory(directory);
      final directories = {...state.scanDirectories, directory}.toList()
        ..sort();
      final snapshot = LocalMusicSnapshot(
        tracks: _mergeTracks([...state.tracks, ...tracks]),
        scanDirectories: directories,
        lastScannedAt: DateTime.now(),
      );
      await _repository.saveLibrary(snapshot);
      state = state.copyWith(
        tracks: snapshot.tracks,
        scanDirectories: snapshot.scanDirectories,
        lastScannedAt: snapshot.lastScannedAt,
        isScanning: false,
      );
    } on Object catch (error) {
      state = state.copyWith(isScanning: false, errorMessage: '扫描失败：$error');
    }
  }

  Future<void> removeScanDirectory(String directory) async {
    final normalizedDirectory = _normalizePath(directory);
    final tracks = state.tracks.where((track) {
      final filePath = track.filePath;
      if (filePath == null) {
        return true;
      }
      final normalizedFilePath = _normalizePath(filePath);
      return !normalizedFilePath.startsWith('$normalizedDirectory/');
    }).toList();
    final directories = state.scanDirectories
        .where((path) => _normalizePath(path) != normalizedDirectory)
        .toList();
    final snapshot = LocalMusicSnapshot(
      tracks: tracks,
      scanDirectories: directories,
      lastScannedAt: state.lastScannedAt,
    );
    await _repository.saveLibrary(snapshot);
    state = state.copyWith(tracks: tracks, scanDirectories: directories);
  }

  Future<void> toggleLiked(Track track) async {
    final tracks = [
      for (final item in state.tracks)
        if (item.id == track.id)
          item.copyWith(isLiked: !item.isLiked)
        else
          item,
    ];
    await _repository.saveLibrary(
      LocalMusicSnapshot(
        tracks: tracks,
        scanDirectories: state.scanDirectories,
        lastScannedAt: state.lastScannedAt,
      ),
    );
    final updated = tracks.firstWhere((t) => t.id == track.id);
    await AppDatabase.instance.setLiked(
      updated.id,
      updated.source ?? 'localTrack',
      updated.isLiked,
    );
    state = state.copyWith(tracks: tracks);
  }

  Future<void> markPlayed(Track track) async {
    final now = DateTime.now();
    final tracks = [
      for (final item in state.tracks)
        if (item.id == track.id)
          item.copyWith(playCount: item.playCount + 1, lastPlayedAt: now)
        else
          item,
    ];
    await _repository.saveLibrary(
      LocalMusicSnapshot(
        tracks: tracks,
        scanDirectories: state.scanDirectories,
        lastScannedAt: state.lastScannedAt,
      ),
    );
    await AppDatabase.instance.recordPlay(
      track.id,
      durationMs: track.durationMs,
      source: track.source,
    );
    state = state.copyWith(tracks: tracks);
  }

  Future<Track?> setLyricOffset(Track track, double offset) async {
    if (track.type != TrackType.local) {
      return null;
    }

    final updatedTrack = track.copyWith(offset: offset);
    final tracks = [
      for (final item in state.tracks)
        if (item.id == track.id) updatedTrack else item,
    ];
    await _repository.saveLibrary(
      LocalMusicSnapshot(
        tracks: tracks,
        scanDirectories: state.scanDirectories,
        lastScannedAt: state.lastScannedAt,
      ),
    );
    await AppDatabase.instance.updateTrack(updatedTrack);
    state = state.copyWith(tracks: tracks);
    return updatedTrack;
  }

  List<Track> _mergeTracks(List<Track> tracks) {
    final byPath = <String, Track>{};
    for (final track in tracks) {
      final key = track.filePath ?? track.id;
      final existing = byPath[key];
      byPath[key] = track.copyWith(
        isLiked: existing?.isLiked ?? track.isLiked,
        playCount: existing?.playCount ?? track.playCount,
        lastPlayedAt: existing?.lastPlayedAt ?? track.lastPlayedAt,
      );
    }

    final merged = byPath.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return merged;
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  }
}

class LocalMusicRepository {
  LocalMusicRepository({LocalMusicPlatform? platform})
    : _platform = platform ?? createLocalMusicPlatform();

  static const _tracksKey = 'local_music.tracks.v1';
  static const _directoriesKey = 'local_music.directories.v1';
  static const _lastScannedAtKey = 'local_music.last_scanned_at.v1';

  final LocalMusicPlatform _platform;

  Future<LocalMusicSnapshot> loadLibrary() async {
    // Try database first
    if (await AppDatabase.instance.needsSharedPreferencesMigration()) {
      final prefsSnapshot = await _loadFromSharedPreferences();
      if (prefsSnapshot != null && prefsSnapshot.tracks.isNotEmpty) {
        // Migrate to database
        await AppDatabase.instance.insertOrUpdateTracks(prefsSnapshot.tracks);
        await _saveDirectoriesToDatabase(prefsSnapshot.scanDirectories);
        if (prefsSnapshot.lastScannedAt != null) {
          await AppDatabase.instance.setAppData(
            'local_music.last_scanned_at.v1',
            prefsSnapshot.lastScannedAt!.toIso8601String(),
          );
        }
        await AppDatabase.instance.markMigrationDone();
        return prefsSnapshot;
      }
      await AppDatabase.instance.markMigrationDone();
    }

    final tracks = await AppDatabase.instance.loadAllTracks();
    final directories = await AppDatabase.instance.getAppData(
      'local_music.directories.v1',
    );
    final scannedAtStr = await AppDatabase.instance.getAppData(
      'local_music.last_scanned_at.v1',
    );

    return LocalMusicSnapshot(
      tracks: tracks,
      scanDirectories: directories?.isNotEmpty == true
          ? (jsonDecode(directories!) as List).cast<String>()
          : const [],
      lastScannedAt: scannedAtStr == null
          ? null
          : DateTime.tryParse(scannedAtStr),
    );
  }

  Future<LocalMusicSnapshot?> _loadFromSharedPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final trackPayload = preferences.getString(_tracksKey);
    final directories = preferences.getStringList(_directoriesKey) ?? const [];
    final scannedAt = preferences.getString(_lastScannedAtKey);

    final tracks = <Track>[];
    if (trackPayload != null && trackPayload.isNotEmpty) {
      final decoded = jsonDecode(trackPayload);
      if (decoded is List) {
        tracks.addAll(
          decoded.whereType<Map>().map(
            (item) => Track.fromJson(Map<String, Object?>.from(item)),
          ),
        );
      }
    }

    if (tracks.isEmpty && directories.isEmpty && scannedAt == null) {
      return null; // Nothing to migrate
    }

    return LocalMusicSnapshot(
      tracks: tracks,
      scanDirectories: directories,
      lastScannedAt: scannedAt == null ? null : DateTime.tryParse(scannedAt),
    );
  }

  Future<void> saveLibrary(LocalMusicSnapshot snapshot) async {
    // Save tracks to database
    await AppDatabase.instance.insertOrUpdateTracks(snapshot.tracks);

    // Save directories and timestamp via app_data
    await _saveDirectoriesToDatabase(snapshot.scanDirectories);
    if (snapshot.lastScannedAt != null) {
      await AppDatabase.instance.setAppData(
        'local_music.last_scanned_at.v1',
        snapshot.lastScannedAt!.toIso8601String(),
      );
    }

    // shared_preferences is now read only for one-time Phase 2 migration.
  }

  Future<void> _saveDirectoriesToDatabase(List<String> directories) async {
    await AppDatabase.instance.setAppData(
      'local_music.directories.v1',
      jsonEncode(directories),
    );
  }

  Future<String?> pickDirectory() async {
    return _platform.pickDirectory();
  }

  Future<List<Track>> scanDirectory(String directoryPath) async {
    return _platform.scanDirectory(directoryPath);
  }
}

class LocalMusicSnapshot {
  const LocalMusicSnapshot({
    required this.tracks,
    required this.scanDirectories,
    required this.lastScannedAt,
  });

  final List<Track> tracks;
  final List<String> scanDirectories;
  final DateTime? lastScannedAt;
}
