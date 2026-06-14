import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'netease_api_client.dart';
import 'netease_json.dart';

class NeteaseProfile {
  const NeteaseProfile({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    this.signature,
  });

  final String userId;
  final String nickname;
  final String? avatarUrl;
  final String? signature;

  Map<String, Object?> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'signature': signature,
    };
  }

  factory NeteaseProfile.fromJson(Map<String, Object?> json) {
    return NeteaseProfile(
      userId: neteaseString(json['userId']) ?? '',
      nickname: neteaseString(json['nickname']) ?? '网易云用户',
      avatarUrl: neteaseString(json['avatarUrl']),
      signature: neteaseString(json['signature']),
    );
  }
}

class NeteaseQrSession {
  const NeteaseQrSession({required this.key, required this.imageData});

  final String key;
  final String imageData;
}

class NeteaseQrCheckResult {
  const NeteaseQrCheckResult({
    required this.code,
    required this.message,
    this.cookie,
  });

  final int code;
  final String message;
  final String? cookie;

  bool get isExpired => code == 800;
  bool get isWaiting => code == 801;
  bool get isScanned => code == 802;
  bool get isSuccess => code == 803;
}

class NeteaseLoginStatus {
  const NeteaseLoginStatus({required this.isLoggedIn, this.profile});

  final bool isLoggedIn;
  final NeteaseProfile? profile;
}

class NeteaseAuthRepository {
  const NeteaseAuthRepository({required NeteaseApiClient client})
    : _client = client;

  final NeteaseApiClient _client;

  Future<NeteaseQrSession> createQrSession() async {
    final keyJson = await _client.getJson(
      '/login/qr/key',
      queryParameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
    final key = qrKeyFromJson(keyJson);
    if (key == null || key.isEmpty) {
      throw const NeteaseApiException(message: '获取二维码 key 失败');
    }

    final imageJson = await _client.getJson(
      '/login/qr/create',
      queryParameters: {
        'key': key,
        'qrimg': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    final imageData = qrImageFromJson(imageJson);
    if (imageData == null || imageData.isEmpty) {
      throw const NeteaseApiException(message: '获取二维码图片失败');
    }

    return NeteaseQrSession(key: key, imageData: imageData);
  }

  Future<NeteaseQrCheckResult> checkQrLogin(String key) async {
    final json = await _client.getJson(
      '/login/qr/check',
      queryParameters: {
        'key': key,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    return qrCheckResultFromJson(json);
  }

  Future<NeteaseLoginStatus> loginStatus({String? cookie}) async {
    final json = await _client.postJson(
      '/login/status',
      queryParameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      data: {if (cookie != null && cookie.isNotEmpty) 'cookie': cookie},
    );
    return loginStatusFromJson(json);
  }

  Future<NeteaseLoginStatus> userAccount() async {
    final json = await _client.getJson(
      '/user/account',
      queryParameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
    return loginStatusFromJson(json);
  }

  Future<void> refreshCookie() async {
    await _client.postJson('/login/refresh');
  }

  Future<void> logout() async {
    await _client.postJson('/logout');
  }

  /// 手机号 + 密码登录，返回规范化后的 cookie。
  Future<String> loginWithPhone({
    required String phone,
    required String password,
    String? countryCode,
  }) async {
    final json = await _client.postJson(
      '/login/cellphone',
      queryParameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      data: {
        'phone': phone,
        'md5_password': _md5Password(password),
        if (countryCode != null && countryCode.isNotEmpty)
          'countrycode': countryCode,
      },
    );
    return cookieFromLoginJson(json);
  }

  /// 邮箱 + 密码登录，返回规范化后的 cookie。
  Future<String> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final json = await _client.postJson(
      '/login',
      queryParameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      data: {'email': email, 'md5_password': _md5Password(password)},
    );
    return cookieFromLoginJson(json);
  }

  static String? qrKeyFromJson(Map<String, Object?> json) {
    final data = json['data'];
    if (data is! Map) {
      return null;
    }
    return neteaseString(data['unikey']);
  }

  static String? qrImageFromJson(Map<String, Object?> json) {
    final data = json['data'];
    if (data is! Map) {
      return null;
    }
    return neteaseString(data['qrimg']) ?? neteaseString(data['qrurl']);
  }

  static NeteaseQrCheckResult qrCheckResultFromJson(Map<String, Object?> json) {
    final code = neteaseInt(json['code']) ?? 0;
    return NeteaseQrCheckResult(
      code: code,
      message: neteaseString(json['message']) ?? _messageForQrCode(code),
      cookie: normalizeCookie(neteaseString(json['cookie']) ?? ''),
    );
  }

  /// 从密码登录响应中提取 cookie；失败时抛出带网易云提示信息的异常。
  static String cookieFromLoginJson(Map<String, Object?> json) {
    final code = neteaseInt(json['code']) ?? 0;
    final cookie = normalizeCookie(neteaseString(json['cookie']) ?? '');
    if (code != 200 || cookie.isEmpty) {
      throw NeteaseApiException(
        message:
            neteaseString(json['message']) ??
            neteaseString(json['msg']) ??
            '登录失败（code $code）',
        responseCode: code,
      );
    }
    return cookie;
  }

  static String _md5Password(String password) =>
      md5.convert(utf8.encode(password)).toString();

  static NeteaseLoginStatus loginStatusFromJson(Map<String, Object?> json) {
    final data = json['data'];
    final container = data is Map ? data : json;
    final profileJson = container['profile'];
    final profile = profileJson is Map
        ? NeteaseProfile.fromJson(Map<String, Object?>.from(profileJson))
        : null;
    return NeteaseLoginStatus(isLoggedIn: profile != null, profile: profile);
  }

  static String normalizeCookie(String raw) {
    final cleaned = raw
        .replaceAll(' HTTPOnly', '')
        .replaceAll(' HttpOnly', '')
        .replaceAll('\n', ';')
        .trim();
    if (cleaned.isEmpty) {
      return '';
    }

    final pairs = <String, String>{};
    for (final segment in cleaned.split(RegExp(r';;|;'))) {
      final trimmed = segment.trim();
      final equalsIndex = trimmed.indexOf('=');
      if (equalsIndex <= 0) {
        continue;
      }
      final key = trimmed.substring(0, equalsIndex).trim();
      final value = trimmed.substring(equalsIndex + 1).trim();
      if (key.isEmpty || value.isEmpty || _isCookieAttribute(key)) {
        continue;
      }
      pairs[key] = value;
    }

    return pairs.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  static bool _isCookieAttribute(String key) {
    return switch (key.toLowerCase()) {
      'path' ||
      'expires' ||
      'max-age' ||
      'domain' ||
      'samesite' ||
      'secure' ||
      'httponly' => true,
      _ => false,
    };
  }

  static String _messageForQrCode(int code) {
    return switch (code) {
      800 => '二维码已失效，请重新获取',
      801 => '打开网易云音乐 App 扫码登录',
      802 => '扫描成功，请在手机上确认登录',
      803 => '登录成功，请稍等...',
      _ => '等待扫码',
    };
  }
}
