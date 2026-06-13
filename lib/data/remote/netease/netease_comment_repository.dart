import '../../models/netease_comment.dart';
import 'netease_api_client.dart';

enum NeteaseCommentSort {
  recommended(1, '推荐'),
  hot(2, '最热'),
  latest(3, '最新');

  const NeteaseCommentSort(this.apiValue, this.label);

  final int apiValue;
  final String label;
}

enum NeteaseCommentResourceType {
  music(0),
  mv(1),
  playlist(2),
  album(3),
  djRadio(4),
  video(5);

  const NeteaseCommentResourceType(this.apiValue);

  final int apiValue;
}

class NeteaseCommentRepository {
  const NeteaseCommentRepository({required NeteaseApiClient client})
    : _client = client;

  final NeteaseApiClient _client;

  Future<NeteaseCommentPage> fetchComments({
    required String resourceId,
    required NeteaseCommentResourceType resourceType,
    required NeteaseCommentSort sort,
    int pageNo = 1,
    int pageSize = 30,
    int? cursor,
  }) async {
    final queryParameters = <String, Object?>{
      'id': resourceId,
      'type': resourceType.apiValue,
      'sortType': sort.apiValue,
      'pageNo': pageNo,
      'pageSize': pageSize,
    };
    if (sort == NeteaseCommentSort.latest && pageNo > 1 && cursor != null) {
      queryParameters['cursor'] = cursor;
    }

    final json = await _client.getJson(
      '/comment/new',
      queryParameters: queryParameters,
    );
    return commentsFromCommentNewJson(json);
  }

  static NeteaseCommentPage commentsFromCommentNewJson(
    Map<String, Object?> json,
  ) {
    final data = json['data'];
    final source = data is Map ? Map<String, Object?>.from(data) : json;
    final rawComments = source['comments'];
    final comments = rawComments is List
        ? rawComments
              .whereType<Map>()
              .map(
                (comment) =>
                    _commentFromJson(Map<String, Object?>.from(comment)),
              )
              .toList()
        : const <NeteaseComment>[];

    return NeteaseCommentPage(
      comments: comments,
      totalCount:
          _intValue(source['totalCount'] ?? source['total']) ?? comments.length,
      hasMore: _boolValue(source['hasMore'] ?? source['more']) ?? false,
      cursor: _intValue(source['cursor']),
    );
  }

  static NeteaseCommentResourceType? resourceTypeFromRoute(String value) {
    return switch (value.trim()) {
      'track' || 'song' || 'music' => NeteaseCommentResourceType.music,
      'mv' => NeteaseCommentResourceType.mv,
      'playlist' => NeteaseCommentResourceType.playlist,
      'album' => NeteaseCommentResourceType.album,
      'djRadio' || 'radio' => NeteaseCommentResourceType.djRadio,
      'video' => NeteaseCommentResourceType.video,
      _ => null,
    };
  }

  static NeteaseComment _commentFromJson(Map<String, Object?> json) {
    final timeMs = _intValue(json['time']) ?? 0;
    return NeteaseComment(
      id: _stringValue(json['commentId']) ?? '',
      content: _stringValue(json['content']) ?? '该评论已删除',
      user: _userFromJson(json['user']),
      time: DateTime.fromMillisecondsSinceEpoch(timeMs),
      likedCount: _intValue(json['likedCount']) ?? 0,
      liked: _boolValue(json['liked']) ?? false,
      replyCount: _intValue(json['replyCount']) ?? 0,
      ipLocation: _ipLocationFromJson(json['ipLocation']),
      replied: _replyFromJson(json['beReplied'], json['parentCommentId']),
    );
  }

  static NeteaseCommentUser _userFromJson(Object? value) {
    if (value is! Map) {
      return const NeteaseCommentUser(id: '', nickname: '未知用户');
    }
    final json = Map<String, Object?>.from(value);
    return NeteaseCommentUser(
      id: _stringValue(json['userId']) ?? '',
      nickname: _stringValue(json['nickname']) ?? '未知用户',
      avatarUrl: _stringValue(json['avatarUrl']),
    );
  }

  static NeteaseCommentReply? _replyFromJson(
    Object? value,
    Object? parentCommentId,
  ) {
    if (value is! List || value.isEmpty) {
      return null;
    }

    Map<String, Object?>? json;
    for (final item in value.whereType<Map>()) {
      json = Map<String, Object?>.from(item);
      break;
    }
    if (json == null) {
      return null;
    }
    final commentId = _stringValue(json['beRepliedCommentId']) ?? '';
    if (commentId.isNotEmpty && commentId == _stringValue(parentCommentId)) {
      return null;
    }
    final user = _userFromJson(json['user']);
    return NeteaseCommentReply(
      commentId: commentId,
      nickname: user.nickname,
      content: _stringValue(json['content']) ?? '该评论已删除',
    );
  }

  static String? _ipLocationFromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    return _stringValue(value['location']);
  }

  static String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool? _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == 'true' || value == '1';
    }
    return null;
  }
}
