import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/track.dart';
import '../../../data/remote/netease/netease_api_client.dart';
import '../../../data/remote/netease/netease_music_repository.dart';
import '../../login/application/netease_auth_controller.dart';
import '../../player/application/lyric_offset_repository.dart';
import '../../player/application/player_controller.dart';
import '../../settings/application/app_settings_controller.dart';

final neteaseSearchControllerProvider =
    StateNotifierProvider<NeteaseSearchController, NeteaseSearchState>((ref) {
      return NeteaseSearchController(ref);
    });

class NeteaseSearchState {
  const NeteaseSearchState({
    this.keyword = '',
    this.results = const [],
    this.isLoading = false,
    this.errorMessage,
    this.playbackErrorMessage,
    this.resolvingTrackId,
  });

  final String keyword;
  final List<Track> results;
  final bool isLoading;
  final String? errorMessage;
  final String? playbackErrorMessage;
  final String? resolvingTrackId;

  bool get hasSearched => keyword.trim().isNotEmpty;

  NeteaseSearchState copyWith({
    String? keyword,
    List<Track>? results,
    bool? isLoading,
    String? errorMessage,
    String? playbackErrorMessage,
    String? resolvingTrackId,
    bool clearError = false,
    bool clearPlaybackError = false,
    bool clearResolvingTrack = false,
  }) {
    return NeteaseSearchState(
      keyword: keyword ?? this.keyword,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      playbackErrorMessage: clearPlaybackError
          ? null
          : playbackErrorMessage ?? this.playbackErrorMessage,
      resolvingTrackId: clearResolvingTrack
          ? null
          : resolvingTrackId ?? this.resolvingTrackId,
    );
  }
}

class NeteaseSearchController extends StateNotifier<NeteaseSearchState> {
  NeteaseSearchController(this._ref) : super(const NeteaseSearchState());

  final Ref _ref;

  Future<void> search(String keyword) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      state = const NeteaseSearchState();
      return;
    }

    state = state.copyWith(
      keyword: normalizedKeyword,
      isLoading: true,
      clearError: true,
      clearPlaybackError: true,
    );

    try {
      final repository = _repository();
      var results = await repository.searchTracks(normalizedKeyword);
      try {
        results = await repository.tracksWithRemoteDetails(results);
      } on Object {
        // Search results remain usable even if cover/detail enrichment fails.
      }
      final tracksWithOffsets = await _ref
          .read(lyricOffsetRepositoryProvider)
          .applyOffsets(results);
      state = state.copyWith(results: tracksWithOffsets, isLoading: false);
    } on NeteaseApiException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.isUnauthorized ? '网易云登录态已失效' : error.message,
      );
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '搜索失败：$error');
    }
  }

  Future<void> playTrack(Track track) async {
    state = state.copyWith(
      resolvingTrackId: track.id,
      clearPlaybackError: true,
    );

    try {
      final playableTrack = await _ref
          .read(lyricOffsetRepositoryProvider)
          .applyOffset(await _repository().resolvePlayableTrack(track));
      state = state.copyWith(
        results: [
          for (final item in state.results)
            if (item.id == playableTrack.id) playableTrack else item,
        ],
        clearResolvingTrack: true,
      );
      await _ref.read(musicPlayerControllerProvider.notifier).playQueue([
        playableTrack,
      ]);
    } on NeteaseApiException catch (error) {
      state = state.copyWith(
        playbackErrorMessage: error.isUnauthorized
            ? '网易云登录态已失效'
            : error.message,
        clearResolvingTrack: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        playbackErrorMessage: '播放失败：$error',
        clearResolvingTrack: true,
      );
    }
  }

  NeteaseMusicRepository _repository() {
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
