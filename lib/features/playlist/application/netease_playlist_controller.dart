import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/playlist.dart';
import '../../../data/remote/netease/netease_api_client.dart';
import '../../../data/remote/netease/netease_collection_cache.dart';
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
  final NeteaseCollectionCache _collectionCache = NeteaseCollectionCache();

  Future<void> refresh() async {
    final playlistId = _playlistId.trim();
    if (playlistId.isEmpty) {
      state = state.copyWith(errorMessage: '缺少歌单 ID');
      return;
    }

    final isDailyRecommend = playlistId == 'daily-songs';
    final cacheable = !isDailyRecommend;

    // 先出缓存：命中则立即展示；若仍新鲜则跳过网络刷新。
    CachedCollection? cached;
    if (cacheable) {
      cached = await _collectionCache.load(playlistId);
      if (cached != null) {
        await _applyPlaylist(cached.playlist, isLoading: false);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (isCacheFresh(cached.savedAtMs, now, _cacheTtlFor(playlistId))) {
          return;
        }
      }
    }

    state = state.copyWith(
      isLoading: true,
      clearError: cached == null,
      clearPlaybackError: true,
      clearResolvingTrack: true,
      isResolvingQueue: false,
    );

    await _ref.read(neteaseAuthControllerProvider.notifier).load();
    if (isDailyRecommend &&
        !_ref.read(neteaseAuthControllerProvider).isLoggedIn) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '请先登录网易云后查看每日推荐',
      );
      return;
    }
    try {
      final repository = _playlistRepository();
      final Playlist playlist;
      if (isDailyRecommend) {
        playlist = await repository.fetchDailyRecommendTracks();
      } else if (playlistId.startsWith('album:')) {
        playlist = await repository.fetchAlbum(playlistId.substring(6));
      } else if (playlistId.startsWith('artist:')) {
        playlist = await repository.fetchArtist(playlistId.substring(7));
      } else {
        playlist = await repository.fetchPlaylistDetail(playlistId);
      }
      final resolved = await _applyPlaylist(playlist, isLoading: false);
      if (cacheable) {
        unawaited(
          _collectionCache.save(
            playlistId,
            resolved,
            nowMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    } on NeteaseApiException catch (error) {
      // 有缓存则保留缓存内容，仅在无缓存时报错。
      state = state.copyWith(
        isLoading: false,
        errorMessage: cached != null
            ? null
            : (error.isUnauthorized ? '网易云登录态已失效' : error.message),
      );
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: cached != null ? null : '歌单加载失败：$error',
      );
    }
  }

  /// 应用歌词 offset 后写入 state，并返回处理后的歌单（供缓存写入）。
  Future<Playlist> _applyPlaylist(
    Playlist playlist, {
    required bool isLoading,
  }) async {
    final tracks = await _ref
        .read(lyricOffsetRepositoryProvider)
        .applyOffsets(playlist.tracks);
    final resolved = playlist.copyWith(tracks: tracks);
    state = state.copyWith(
      playlist: resolved,
      isLoading: isLoading,
      clearError: true,
    );
    return resolved;
  }

  Duration _cacheTtlFor(String playlistId) {
    if (playlistId.startsWith('album:') || playlistId.startsWith('artist:')) {
      return const Duration(hours: 24);
    }
    return const Duration(hours: 1);
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
    state = state.copyWith(
      resolvingTrackId: playlist.tracks[startIndex].id,
      isResolvingQueue: true,
      clearPlaybackError: true,
    );
    // 秒播 + 后台解析：只解析起始曲并立即播放，其余曲目由播放器在后台解析。
    await _ref
        .read(musicPlayerControllerProvider.notifier)
        .playQueueLazy(playlist.tracks, startIndex: startIndex);
    state = state.copyWith(isResolvingQueue: false, clearResolvingTrack: true);
    final playerError = _ref.read(
      musicPlayerControllerProvider.select((state) => state.errorMessage),
    );
    if (playerError != null) {
      state = state.copyWith(playbackErrorMessage: playerError);
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
