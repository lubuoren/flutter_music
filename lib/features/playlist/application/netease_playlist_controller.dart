import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/playlist.dart';
import '../../../data/models/track.dart';
import '../../../data/remote/netease/netease_api_client.dart';
import '../../../data/remote/netease/netease_music_repository.dart';
import '../../../data/remote/netease/netease_playlist_repository.dart';
import '../../login/application/netease_auth_controller.dart';
import '../../player/application/lyric_offset_repository.dart';
import '../../player/application/player_controller.dart';
import '../../settings/application/app_settings_controller.dart';

final neteaseUserPlaylistsControllerProvider =
    StateNotifierProvider.autoDispose<
      NeteaseUserPlaylistsController,
      NeteaseUserPlaylistsState
    >((ref) {
      final controller = NeteaseUserPlaylistsController(ref);
      unawaited(controller.refresh());
      return controller;
    });

final neteasePlaylistDetailControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      NeteasePlaylistDetailController,
      NeteasePlaylistDetailState,
      String
    >((ref, playlistId) {
      final controller = NeteasePlaylistDetailController(ref, playlistId);
      unawaited(controller.refresh());
      return controller;
    });

class NeteaseUserPlaylistsState {
  const NeteaseUserPlaylistsState({
    this.playlists = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Playlist> playlists;
  final bool isLoading;
  final String? errorMessage;

  NeteaseUserPlaylistsState copyWith({
    List<Playlist>? playlists,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NeteaseUserPlaylistsState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class NeteasePlaylistDetailState {
  const NeteasePlaylistDetailState({
    this.playlist,
    this.isLoading = false,
    this.errorMessage,
    this.playbackErrorMessage,
    this.resolvingTrackId,
    this.isResolvingQueue = false,
  });

  final Playlist? playlist;
  final bool isLoading;
  final String? errorMessage;
  final String? playbackErrorMessage;
  final String? resolvingTrackId;
  final bool isResolvingQueue;

  NeteasePlaylistDetailState copyWith({
    Playlist? playlist,
    bool? isLoading,
    String? errorMessage,
    String? playbackErrorMessage,
    String? resolvingTrackId,
    bool? isResolvingQueue,
    bool clearError = false,
    bool clearPlaybackError = false,
    bool clearResolvingTrack = false,
  }) {
    return NeteasePlaylistDetailState(
      playlist: playlist ?? this.playlist,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      playbackErrorMessage: clearPlaybackError
          ? null
          : playbackErrorMessage ?? this.playbackErrorMessage,
      resolvingTrackId: clearResolvingTrack
          ? null
          : resolvingTrackId ?? this.resolvingTrackId,
      isResolvingQueue: isResolvingQueue ?? this.isResolvingQueue,
    );
  }
}

class NeteaseUserPlaylistsController
    extends StateNotifier<NeteaseUserPlaylistsState> {
  NeteaseUserPlaylistsController(this._ref)
    : super(const NeteaseUserPlaylistsState());

  final Ref _ref;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _ref.read(neteaseAuthControllerProvider.notifier).load();
    final auth = _ref.read(neteaseAuthControllerProvider);
    if (!auth.isLoggedIn || auth.profile == null) {
      state = state.copyWith(playlists: const [], isLoading: false);
      return;
    }

    try {
      final playlists = await _playlistRepository().fetchUserPlaylists(
        userId: auth.profile!.userId,
      );
      state = state.copyWith(playlists: playlists, isLoading: false);
    } on NeteaseApiException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.isUnauthorized ? '网易云登录态已失效' : error.message,
      );
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '歌单加载失败：$error');
    }
  }

  NeteasePlaylistRepository _playlistRepository() {
    final settings = _ref.read(appSettingsControllerProvider);
    final auth = _ref.read(neteaseAuthControllerProvider);
    return NeteasePlaylistRepository(
      client: NeteaseApiClient(
        config: NeteaseApiConfig(
          baseUrl: settings.neteaseApiBaseUrl,
          cookie: auth.cookie,
        ),
      ),
    );
  }
}

class NeteasePlaylistDetailController
    extends StateNotifier<NeteasePlaylistDetailState> {
  NeteasePlaylistDetailController(this._ref, this._playlistId)
    : super(const NeteasePlaylistDetailState());

  final Ref _ref;
  final String _playlistId;

  Future<void> refresh() async {
    final playlistId = _playlistId.trim();
    if (playlistId.isEmpty) {
      state = state.copyWith(errorMessage: '缺少歌单 ID');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearPlaybackError: true,
      clearResolvingTrack: true,
      isResolvingQueue: false,
    );

    await _ref.read(neteaseAuthControllerProvider.notifier).load();
    try {
      final playlist = await _playlistRepository().fetchPlaylistDetail(
        playlistId,
      );
      final tracks = await _ref
          .read(lyricOffsetRepositoryProvider)
          .applyOffsets(playlist.tracks);
      state = state.copyWith(
        playlist: playlist.copyWith(tracks: tracks),
        isLoading: false,
      );
    } on NeteaseApiException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.isUnauthorized ? '网易云登录态已失效' : error.message,
      );
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '歌单加载失败：$error');
    }
  }

  Future<void> playAll() {
    return playFromIndex(0);
  }

  Future<void> playFromIndex(int index) async {
    final playlist = state.playlist;
    if (playlist == null || playlist.tracks.isEmpty || state.isResolvingQueue) {
      return;
    }

    final startIndex = _clampIndex(index, playlist.tracks.length);
    final startTrackId = playlist.tracks[startIndex].id;
    state = state.copyWith(
      resolvingTrackId: startTrackId,
      isResolvingQueue: true,
      clearPlaybackError: true,
    );

    try {
      var tracks = await _musicRepository().tracksWithPlaybackUrls(
        playlist.tracks,
      );
      tracks = [...tracks];

      final startTrack = tracks[startIndex];
      if (!_hasPlayableUrl(startTrack)) {
        throw const NeteaseApiException(
          message: '未获取到歌曲播放地址，可能需要登录或歌曲受版权限制',
          path: '/song/url',
        );
      }

      try {
        tracks[startIndex] = await _musicRepository().trackWithRemoteLyrics(
          startTrack,
        );
      } on Object {
        // The track is still playable without lyrics.
      }

      tracks = await _ref
          .read(lyricOffsetRepositoryProvider)
          .applyOffsets(tracks);
      final playableQueue = tracks.where(_hasPlayableUrl).toList();
      final playableStartIndex = playableQueue.indexWhere(
        (track) => track.id == startTrackId,
      );
      if (playableQueue.isEmpty || playableStartIndex < 0) {
        throw const NeteaseApiException(
          message: '歌单中没有可播放的歌曲',
          path: '/song/url',
        );
      }

      state = state.copyWith(
        playlist: playlist.copyWith(tracks: tracks),
        isResolvingQueue: false,
        clearResolvingTrack: true,
      );
      await _ref
          .read(musicPlayerControllerProvider.notifier)
          .playQueue(playableQueue, startIndex: playableStartIndex);
      final playerError = _ref.read(
        musicPlayerControllerProvider.select((state) => state.errorMessage),
      );
      if (playerError != null) {
        state = state.copyWith(playbackErrorMessage: playerError);
      }
    } on NeteaseApiException catch (error) {
      state = state.copyWith(
        playbackErrorMessage: error.isUnauthorized
            ? '网易云登录态已失效'
            : error.message,
        isResolvingQueue: false,
        clearResolvingTrack: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        playbackErrorMessage: '播放失败：$error',
        isResolvingQueue: false,
        clearResolvingTrack: true,
      );
    }
  }

  int _clampIndex(int index, int length) {
    if (index < 0) {
      return 0;
    }
    if (index >= length) {
      return length - 1;
    }
    return index;
  }

  bool _hasPlayableUrl(Track track) {
    final url = track.url?.trim();
    return url != null && url.isNotEmpty;
  }

  NeteasePlaylistRepository _playlistRepository() {
    final settings = _ref.read(appSettingsControllerProvider);
    final auth = _ref.read(neteaseAuthControllerProvider);
    return NeteasePlaylistRepository(
      client: NeteaseApiClient(
        config: NeteaseApiConfig(
          baseUrl: settings.neteaseApiBaseUrl,
          cookie: auth.cookie,
        ),
      ),
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
}
