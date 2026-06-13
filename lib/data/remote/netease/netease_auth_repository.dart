import 'netease_api_client.dart';

String? _stringValue(Object? value) {
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

int? _intValue(Object? value) {
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
      userId: _stringValue(json['userId']) ?? '',
      nickname: _stringValue(json['nickname']) ?? '网易云用户',
      avatarUrl: _stringValue(json['avatarUrl']),
      signature: _stringValue(json['signature']),
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

  static String? qrKeyFromJson(Map<String, Object?> json) {
    final data = json['data'];
    if (data is! Map) {
      return null;
    }
    return _stringValue(data['unikey']);
  }

  static String? qrImageFromJson(Map<String, Object?> json) {
    final data = json['data'];
    if (data is! Map) {
      return null;
    }
    return _stringValue(data['qrimg']) ?? _stringValue(data['qrurl']);
  }

  static NeteaseQrCheckResult qrCheckResultFromJson(Map<String, Object?> json) {
    final code = _intValue(json['code']) ?? 0;
    return NeteaseQrCheckResult(
      code: code,
      message: _stringValue(json['message']) ?? _messageForQrCode(code),
      cookie: normalizeCookie(_stringValue(json['cookie']) ?? ''),
    );
  }

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
