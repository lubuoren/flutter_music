import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/track.dart';
import '../../../data/remote/netease/netease_api_client.dart';
import '../../../data/remote/netease/netease_music_repository.dart';
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
  });

  final String keyword;
  final List<Track> results;
  final bool isLoading;
  final String? errorMessage;

  bool get hasSearched => keyword.trim().isNotEmpty;

  NeteaseSearchState copyWith({
    String? keyword,
    List<Track>? results,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NeteaseSearchState(
      keyword: keyword ?? this.keyword,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
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
    );

    try {
      final settings = _ref.read(appSettingsControllerProvider);
      final repository = NeteaseMusicRepository(
        client: NeteaseApiClient(
          config: NeteaseApiConfig(baseUrl: settings.neteaseApiBaseUrl),
        ),
      );
      final results = await repository.searchTracks(normalizedKeyword);
      state = state.copyWith(results: results, isLoading: false);
    } on NeteaseApiException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.isUnauthorized ? '网易云登录态已失效' : error.message,
      );
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '搜索失败：$error');
    }
  }
}
