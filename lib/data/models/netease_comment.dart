class NeteaseCommentPage {
  const NeteaseCommentPage({
    required this.comments,
    required this.totalCount,
    required this.hasMore,
    this.cursor,
  });

  final List<NeteaseComment> comments;
  final int totalCount;
  final bool hasMore;
  final int? cursor;
}

class NeteaseComment {
  const NeteaseComment({
    required this.id,
    required this.content,
    required this.user,
    required this.time,
    this.likedCount = 0,
    this.liked = false,
    this.replyCount = 0,
    this.ipLocation,
    this.replied,
  });

  final String id;
  final String content;
  final NeteaseCommentUser user;
  final DateTime time;
  final int likedCount;
  final bool liked;
  final int replyCount;
  final String? ipLocation;
  final NeteaseCommentReply? replied;
}

class NeteaseCommentUser {
  const NeteaseCommentUser({
    required this.id,
    required this.nickname,
    this.avatarUrl,
  });

  final String id;
  final String nickname;
  final String? avatarUrl;
}

class NeteaseCommentReply {
  const NeteaseCommentReply({
    required this.commentId,
    required this.nickname,
    required this.content,
  });

  final String commentId;
  final String nickname;
  final String content;
}
