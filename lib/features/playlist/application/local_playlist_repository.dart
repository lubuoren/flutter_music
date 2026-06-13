import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/models/playlist.dart';
import '../../../data/models/track.dart';

final localPlaylistRepositoryProvider = Provider<LocalPlaylistRepository>((ref) {
  return LocalPlaylistRepository();
});

class LocalPlaylistRepository {
  static const _playlistsKey = 'local_playlists.v1';

  Future<List<Playlist>> loadPlaylists() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('playlists', where: 'is_local = ?', whereArgs: [1], orderBy: 'created_at DESC');

    if (rows.isNotEmpty) {
      return _playlistsFromRows(rows);
    }

    // Fallback: try shared_preferences migration
    return _loadFromSharedPreferences();
  }

  List<Playlist> _playlistsFromRows(List<Map<String, Object?>> rows) {
    return rows.map((row) {
      final json = Map<String, Object?>.from(
        jsonDecode(row['json'] as String) as Map,
      );
      return Playlist.fromJson(json);
    }).toList();
  }

  Future<List<Playlist>> _loadFromSharedPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = preferences.getString(_playlistsKey);
    if (payload == null || payload.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(payload);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Playlist.fromJson(Map<String, Object?>.from(item)))
        .toList();
  }

  Future<void> _savePlaylist(Playlist playlist) async {
    final db = AppDatabase.instance;
    final trackIds = playlist.tracks.map((t) => t.id).toList();

    await db.insertOrUpdatePlaylist({
      'id': playlist.id,
      'name': playlist.name,
      'is_local': 1,
      'source': playlist.source ?? 'local',
      'json': jsonEncode(playlist.toJson()),
      'created_at': (playlist.createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': (playlist.updatedAt ?? DateTime.now()).toIso8601String(),
    });

    // Sync playlist_tracks
    final existingTracks = await db.loadPlaylistTracks(playlist.id);
    final existingIds = existingTracks.map((r) => r['track_id'] as String).toSet();

    // Remove tracks no longer in playlist
    for (final et in existingTracks) {
      final etId = et['track_id'] as String;
      if (!trackIds.contains(etId)) {
        await db.deletePlaylistTrack(playlist.id, etId);
      }
    }

    // Insert new tracks
    for (var i = 0; i < trackIds.length; i++) {
      if (!existingIds.contains(trackIds[i])) {
        await db.insertPlaylistTrack(playlist.id, trackIds[i], i);
      }
    }
  }

  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final id = 'local-${sha1.convert(utf8.encode('$name-${DateTime.now().toIso8601String()}')).toString()}';
    final now = DateTime.now();
    final playlist = Playlist(
      id: id,
      name: name,
      description: description,
      source: 'local',
      isLocal: true,
      createdAt: now,
      updatedAt: now,
    );
    await _savePlaylist(playlist);
    return playlist;
  }

  Future<void> deletePlaylist(String id) async {
    await AppDatabase.instance.deletePlaylist(id);
  }

  Future<Playlist?> renamePlaylist(String id, String newName) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == id);
    if (index < 0) {
      return null;
    }

    final updated = playlists[index].copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    await _savePlaylist(updated);
    return updated;
  }

  Future<Playlist?> getPlaylist(String id) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == id);
    return index < 0 ? null : playlists[index];
  }

  Future<Playlist?> addTracks(String playlistId, List<Track> tracks) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) {
      return null;
    }

    final existingIds = playlists[index].tracks.map((t) => t.id).toSet();
    final newTracks = tracks.where((t) => !existingIds.contains(t.id)).toList();
    if (newTracks.isEmpty) {
      return playlists[index];
    }

    final updatedTracks = [...playlists[index].tracks, ...newTracks];
    final updated = playlists[index].copyWith(
      tracks: updatedTracks,
      trackCount: updatedTracks.length,
      updatedAt: DateTime.now(),
    );
    await _savePlaylist(updated);
    return updated;
  }

  Future<Playlist?> removeTrack(String playlistId, String trackId) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) {
      return null;
    }

    final updatedTracks =
        playlists[index].tracks.where((t) => t.id != trackId).toList();
    final updated = playlists[index].copyWith(
      tracks: updatedTracks,
      trackCount: updatedTracks.length,
      updatedAt: DateTime.now(),
    );
    await _savePlaylist(updated);
    return updated;
  }
}
