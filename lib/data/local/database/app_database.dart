import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/track.dart';

/// 应用数据库，管理所有持久化数据。
///
/// 使用 raw sqflite（而非 drift），与原始 VutronMusic 的 better-sqlite3 方式
/// 保持一致——歌曲以 `id + json` 方式存储，灵活适配不同来源。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final appDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(appDir.path, 'vutronmusic'));
    await dbDir.create(recursive: true);
    final dbPath = p.join(dbDir.path, 'vutronmusic.db');

    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    const migration = '''
CREATE TABLE tracks (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  source TEXT,
  file_path TEXT,
  json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_tracks_type ON tracks(type);
CREATE INDEX idx_tracks_file_path ON tracks(file_path);

CREATE TABLE playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  is_local INTEGER NOT NULL DEFAULT 0,
  source TEXT,
  json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE playlist_tracks (
  playlist_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  added_at TEXT NOT NULL,
  PRIMARY KEY (playlist_id, track_id),
  FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

CREATE TABLE liked_tracks (
  track_id TEXT NOT NULL,
  source TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (track_id, source)
);

CREATE TABLE play_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  track_id TEXT NOT NULL,
  played_at TEXT NOT NULL,
  duration_ms INTEGER,
  source TEXT
);

CREATE INDEX idx_play_history_track_id ON play_history(track_id);
CREATE INDEX idx_play_history_played_at ON play_history(played_at);

CREATE TABLE app_data (
  id TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''';
    for (final statement in migration.split(';')) {
      final trimmed = statement.trim();
      if (trimmed.isNotEmpty) {
        await db.execute(trimmed);
      }
    }
  }

  // ━━━ Tracks ━━━

  Future<List<Track>> loadAllTracks() async {
    final db = await database;
    final rows = await db.query('tracks', orderBy: 'id');
    return rows.map((row) {
      final json = Map<String, Object?>.from(
        jsonDecode(row['json'] as String) as Map,
      );
      return Track.fromJson(json);
    }).toList();
  }

  Future<void> insertOrUpdateTrack(Track track) async {
    final db = await database;
    await db.insert(
      'tracks',
      {
        'id': track.id,
        'type': track.type.name,
        'source': track.source,
        'file_path': track.filePath,
        'json': jsonEncode(track.toJson()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrUpdateTracks(List<Track> tracks) async {
    final db = await database;
    final batch = db.batch();
    for (final track in tracks) {
      batch.insert(
        'tracks',
        {
          'id': track.id,
          'type': track.type.name,
          'source': track.source,
          'file_path': track.filePath,
          'json': jsonEncode(track.toJson()),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTracksByDirectory(String directory) async {
    final db = await database;
    final normalized = directory.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    await db.delete(
      'tracks',
      where: "file_path LIKE ?",
      whereArgs: ['$normalized/%'],
    );
  }

  // ━━━ Liked Tracks ━━━

  Future<void> setLiked(String trackId, String source, bool liked) async {
    final db = await database;
    if (liked) {
      await db.insert(
        'liked_tracks',
        {
          'track_id': trackId,
          'source': source,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.delete(
        'liked_tracks',
        where: 'track_id = ? AND source = ?',
        whereArgs: [trackId, source],
      );
    }
    // Also update the track JSON in tracks table
    final tracks = await db.query(
      'tracks',
      where: 'id = ?',
      whereArgs: [trackId],
    );
    if (tracks.isNotEmpty) {
      final row = tracks.first;
      final json = Map<String, Object?>.from(
        jsonDecode(row['json'] as String) as Map,
      );
      json['isLiked'] = liked;
      await db.update(
        'tracks',
        {'json': jsonEncode(json), 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [trackId],
      );
    }
  }

  // ━━━ Play History ━━━

  Future<void> recordPlay(String trackId, {int? durationMs, String? source}) async {
    final db = await database;
    await db.insert('play_history', {
      'track_id': trackId,
      'played_at': DateTime.now().toIso8601String(),
      'duration_ms': durationMs,
      'source': source,
    });
  }

  // ━━━ Playlists ━━━

  Future<void> insertOrUpdatePlaylist(Map<String, Object?> playlistData) async {
    final db = await database;
    await db.insert(
      'playlists',
      playlistData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> loadAllPlaylists() async {
    final db = await database;
    return db.query('playlists', orderBy: 'created_at DESC');
  }

  Future<void> deletePlaylist(String playlistId) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
    await db.delete(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> insertPlaylistTrack(
    String playlistId,
    String trackId,
    int position,
  ) async {
    final db = await database;
    await db.insert(
      'playlist_tracks',
      {
        'playlist_id': playlistId,
        'track_id': trackId,
        'position': position,
        'added_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> loadPlaylistTracks(
    String playlistId,
  ) async {
    final db = await database;
    return db.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );
  }

  Future<void> deletePlaylistTrack(
    String playlistId,
    String trackId,
  ) async {
    final db = await database;
    await db.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
  }

  // ━━━ App Data (settings) ━━━

  Future<void> setAppData(String id, String value) async {
    final db = await database;
    await db.insert(
      'app_data',
      {'id': id, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getAppData(String id) async {
    final db = await database;
    final rows = await db.query('app_data', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  // ━━━ Migration from shared_preferences ━━━

  Future<bool> needsSharedPreferencesMigration() async {
    final flag = await getAppData('migration.shared_prefs_done.v1');
    return flag != 'true';
  }

  Future<void> markMigrationDone() async {
    await setAppData('migration.shared_prefs_done.v1', 'true');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
