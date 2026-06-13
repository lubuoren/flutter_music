import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/remote/netease/netease_comment_repository.dart';

void main() {
  group('NeteaseCommentRepository', () {
    test('commentsFromCommentNewJson maps comments response', () {
      final page = NeteaseCommentRepository.commentsFromCommentNewJson({
        'code': 200,
        'data': {
          'totalCount': 42,
          'hasMore': true,
          'cursor': 1710000000000,
          'comments': [
            {
              'commentId': 123,
              'content': '好听',
              'time': 1700000000000,
              'likedCount': 99,
              'liked': true,
              'replyCount': 3,
              'user': {
                'userId': 456,
                'nickname': '听众',
                'avatarUrl': 'http://avatar',
              },
              'ipLocation': {'location': '上海'},
              'beReplied': [
                {
                  'beRepliedCommentId': 789,
                  'content': '确实',
                  'user': {'nickname': '另一个听众'},
                },
              ],
            },
          ],
        },
      });

      expect(page.totalCount, 42);
      expect(page.hasMore, isTrue);
      expect(page.cursor, 1710000000000);
      expect(page.comments, hasLength(1));

      final comment = page.comments.single;
      expect(comment.id, '123');
      expect(comment.content, '好听');
      expect(comment.user.id, '456');
      expect(comment.user.nickname, '听众');
      expect(comment.user.avatarUrl, 'http://avatar');
      expect(comment.likedCount, 99);
      expect(comment.liked, isTrue);
      expect(comment.replyCount, 3);
      expect(comment.ipLocation, '上海');
      expect(comment.replied?.commentId, '789');
      expect(comment.replied?.nickname, '另一个听众');
      expect(comment.replied?.content, '确实');
    });

    test('commentsFromCommentNewJson tolerates empty response', () {
      final page = NeteaseCommentRepository.commentsFromCommentNewJson({
        'code': 200,
        'data': {},
      });

      expect(page.comments, isEmpty);
      expect(page.totalCount, 0);
      expect(page.hasMore, isFalse);
    });

    test('resourceTypeFromRoute follows original VutronMusic type map', () {
      expect(
        NeteaseCommentRepository.resourceTypeFromRoute('track')?.apiValue,
        0,
      );
      expect(NeteaseCommentRepository.resourceTypeFromRoute('mv')?.apiValue, 1);
      expect(
        NeteaseCommentRepository.resourceTypeFromRoute('playlist')?.apiValue,
        2,
      );
      expect(
        NeteaseCommentRepository.resourceTypeFromRoute('album')?.apiValue,
        3,
      );
      expect(
        NeteaseCommentRepository.resourceTypeFromRoute('video')?.apiValue,
        5,
      );
      expect(NeteaseCommentRepository.resourceTypeFromRoute('unknown'), isNull);
    });
  });
}
