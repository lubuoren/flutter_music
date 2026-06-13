import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/netease_comment.dart';
import '../../../data/remote/netease/netease_api_client.dart';
import '../../../data/remote/netease/netease_comment_repository.dart';
import '../../login/application/netease_auth_controller.dart';
import '../../settings/application/app_settings_controller.dart';

final neteaseCommentsControllerProvider = StateNotifierProvider.autoDispose
    .family<
      NeteaseCommentsController,
      NeteaseCommentsState,
      NeteaseCommentsTarget
    >((ref, target) {
      return NeteaseCommentsController(ref, target);
    });

class NeteaseCommentsTarget {
  const NeteaseCommentsTarget({
    required this.resourceType,
    required this.resourceId,
  });

  final String resourceType;
  final String resourceId;

  NeteaseCommentResourceType? get apiResourceType =>
      NeteaseCommentRepository.resourceTypeFromRoute(resourceType);

  @override
  bool operator ==(Object other) {
    return other is NeteaseCommentsTarget &&
        other.resourceType == resourceType &&
        other.resourceId == resourceId;
  }

  @override
  int get hashCode => Object.hash(resourceType, resourceId);
}

class NeteaseCommentsState {
  const NeteaseCommentsState({
    this.comments = const [],
    this.sort = NeteaseCommentSort.recommended,
    this.totalCount = 0,
    this.pageNo = 1,
    this.cursor,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final List<NeteaseComment> comments;
  final NeteaseCommentSort sort;
  final int totalCount;
  final int pageNo;
  final int? cursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  NeteaseCommentsState copyWith({
    List<NeteaseComment>? comments,
    NeteaseCommentSort? sort,
    int? totalCount,
    int? pageNo,
    int? cursor,
    bool clearCursor = false,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NeteaseCommentsState(
      comments: comments ?? this.comments,
      sort: sort ?? this.sort,
      totalCount: totalCount ?? this.totalCount,
      pageNo: pageNo ?? this.pageNo,
      cursor: clearCursor ? null : cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class NeteaseCommentsController extends StateNotifier<NeteaseCommentsState> {
  NeteaseCommentsController(this._ref, this._target)
    : super(const NeteaseCommentsState()) {
    unawaited(refresh());
  }

  static const _pageSize = 30;

  final Ref _ref;
  final NeteaseCommentsTarget _target;

  Future<void> refresh() async {
    state = state.copyWith(
      comments: const [],
      totalCount: 0,
      pageNo: 1,
      clearCursor: true,
      hasMore: true,
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );
    await _loadPage(refreshing: true);
  }

  Future<void> changeSort(NeteaseCommentSort sort) async {
    if (sort == state.sort && state.comments.isNotEmpty) {
      return;
    }
    state = state.copyWith(sort: sort);
    await refresh();
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);
    await _loadPage(refreshing: false);
  }

  Future<void> _loadPage({required bool refreshing}) async {
    final resourceType = _target.apiResourceType;
    if (resourceType == null) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasMore: false,
        errorMessage: '暂不支持 ${_target.resourceType} 类型评论',
      );
      return;
    }
    if (_target.resourceId.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasMore: false,
        errorMessage: '缺少评论资源 ID',
      );
      return;
    }

    try {
      final page = await _repository().fetchComments(
        resourceId: _target.resourceId,
        resourceType: resourceType,
        sort: state.sort,
        pageNo: state.pageNo,
        pageSize: _pageSize,
        cursor: state.cursor,
      );
      final comments = refreshing
          ? page.comments
          : _appendUniqueComments(state.comments, page.comments);
      state = state.copyWith(
        comments: comments,
        totalCount: page.totalCount,
        pageNo: state.pageNo + 1,
        cursor: page.cursor,
        hasMore: page.hasMore && page.comments.isNotEmpty,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } on NeteaseApiException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasMore: false,
        errorMessage: error.isUnauthorized ? '网易云登录态已失效' : error.message,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasMore: false,
        errorMessage: '评论加载失败：$error',
      );
    }
  }

  List<NeteaseComment> _appendUniqueComments(
    List<NeteaseComment> existing,
    List<NeteaseComment> incoming,
  ) {
    final seenIds = existing.map((comment) => comment.id).toSet();
    return [
      ...existing,
      for (final comment in incoming)
        if (seenIds.add(comment.id)) comment,
    ];
  }

  NeteaseCommentRepository _repository() {
    final settings = _ref.read(appSettingsControllerProvider);
    final auth = _ref.read(neteaseAuthControllerProvider);
    return NeteaseCommentRepository(
      client: NeteaseApiClient(
        config: NeteaseApiConfig(
          baseUrl: settings.neteaseApiBaseUrl,
          cookie: auth.cookie,
        ),
      ),
    );
  }
}
