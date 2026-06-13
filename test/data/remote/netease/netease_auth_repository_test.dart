import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/data/remote/netease/netease_auth_repository.dart';

void main() {
  group('NeteaseAuthRepository', () {
    test('normalizeCookie keeps key value pairs and drops attributes', () {
      final cookie = NeteaseAuthRepository.normalizeCookie(
        'MUSIC_U=abc; Path=/; Max-Age=1296000;; '
        '__csrf=xyz%3D; HTTPOnly; Secure; SameSite=None',
      );

      expect(cookie, 'MUSIC_U=abc; __csrf=xyz%3D');
    });

    test('qrCheckResultFromJson maps success cookie', () {
      final result = NeteaseAuthRepository.qrCheckResultFromJson({
        'code': 803,
        'message': '授权登录成功',
        'cookie': 'MUSIC_U=abc; Path=/;; __csrf=xyz',
      });

      expect(result.isSuccess, isTrue);
      expect(result.message, '授权登录成功');
      expect(result.cookie, 'MUSIC_U=abc; __csrf=xyz');
    });

    test('loginStatusFromJson maps profile from data payload', () {
      final status = NeteaseAuthRepository.loginStatusFromJson({
        'code': 200,
        'data': {
          'profile': {
            'userId': 123,
            'nickname': 'User',
            'avatarUrl': 'https://avatar',
            'signature': 'hello',
          },
        },
      });

      expect(status.isLoggedIn, isTrue);
      expect(status.profile?.userId, '123');
      expect(status.profile?.nickname, 'User');
      expect(status.profile?.avatarUrl, 'https://avatar');
      expect(status.profile?.signature, 'hello');
    });
  });
}
