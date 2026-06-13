import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/playlist.dart';
import '../../../data/models/track.dart';
import 'local_playlist_repository.dart';

class LocalPlaylistState {
  const LocalPlaylistState({
    this.playlists = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Playlist> playlists;
  final bool isLoading;
  final String? errorMessage;

  LocalPlaylistState copyWith({
    List<Playlist>? playlists,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocalPlaylistState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final localPlaylistControllerProvider =
    StateNotifierProvider<LocalPlaylistController, LocalPlaylistState>((ref) {
      return LocalPlaylistController(ref.watch(localPlaylistRepositoryProvider))
        ..load();
    });

class LocalPlaylistController extends StateNotifier<LocalPlaylistState> {
  LocalPlaylistController(this._repository) : super(const LocalPlaylistState());

  final LocalPlaylistRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final playlists = await _repository.loadPlaylists();
      state = state.copyWith(playlists: playlists, isLoading: false);
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '加载歌单失败：$error');
    }
  }

  Future<Playlist?> createPlaylist(String name, {String? description}) async {
    try {
      final playlist = await _repository.createPlaylist(
        name,
        description: description,
      );
      final playlists = [...state.playlists, playlist];
      state = state.copyWith(playlists: playlists, clearError: true);
      return playlist;
    } on Object catch (error) {
      state = state.copyWith(errorMessage: '创建歌单失败：$error');
      return null;
    }
  }

  Future<void> deletePlaylist(String id) async {
    try {
      await _repository.deletePlaylist(id);
      final playlists = state.playlists.where((p) => p.id != id).toList();
      state = state.copyWith(playlists: playlists, clearError: true);
    } on Object catch (error) {
      state = state.copyWith(errorMessage: '删除歌单失败：$error');
    }
  }

  Future<void> renamePlaylist(String id, String newName) async {
    try {
      final updated = await _repository.renamePlaylist(id, newName);
      if (updated != null) {
        final playlists = state.playlists.map((p) {
          return p.id == id ? updated : p;
        }).toList();
        state = state.copyWith(playlists: playlists, clearError: true);
      }
    } on Object catch (error) {
      state = state.copyWith(errorMessage: '重命名歌单失败：$error');
    }
  }

  Future<void> addTracks(String playlistId, List<Track> tracks) async {
    try {
      final updated = await _repository.addTracks(playlistId, tracks);
      if (updated != null) {
        final playlists = state.playlists.map((p) {
          return p.id == playlistId ? updated : p;
        }).toList();
        state = state.copyWith(playlists: playlists, clearError: true);
      }
    } on Object catch (error) {
      state = state.copyWith(errorMessage: '添加歌曲失败：$error');
    }
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    try {
      final updated = await _repository.removeTrack(playlistId, trackId);
      if (updated != null) {
        final playlists = state.playlists.map((p) {
          return p.id == playlistId ? updated : p;
        }).toList();
        state = state.copyWith(playlists: playlists, clearError: true);
      }
    } on Object catch (error) {
      state = state.copyWith(errorMessage: '移除歌曲失败：$error');
    }
  }
}
