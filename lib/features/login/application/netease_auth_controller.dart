import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/remote/netease/netease_api_client.dart';
import '../../../data/remote/netease/netease_auth_repository.dart';
import '../../settings/application/app_settings_controller.dart';
import 'secure_cookie_store.dart';

final neteaseAuthControllerProvider =
    StateNotifierProvider<NeteaseAuthController, NeteaseAuthState>((ref) {
      return NeteaseAuthController(ref)..load();
    });

class NeteaseAuthState {
  const NeteaseAuthState({
    this.cookie = '',
    this.profile,
    this.isLoading = false,
    this.errorMessage,
    this.qrKey,
    this.qrImageData,
    this.qrStatusMessage = '打开网易云音乐 App 扫码登录',
    this.isPollingQr = false,
  });

  final String cookie;
  final NeteaseProfile? profile;
  final bool isLoading;
  final String? errorMessage;
  final String? qrKey;
  final String? qrImageData;
  final String qrStatusMessage;
  final bool isPollingQr;

  bool get isLoggedIn => cookie.isNotEmpty && profile != null;
  bool get hasCookie => cookie.isNotEmpty;

  NeteaseAuthState copyWith({
    String? cookie,
    NeteaseProfile? profile,
    bool clearProfile = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? qrKey,
    bool clearQrKey = false,
    String? qrImageData,
    bool clearQrImage = false,
    String? qrStatusMessage,
    bool? isPollingQr,
  }) {
    return NeteaseAuthState(
      cookie: cookie ?? this.cookie,
      profile: clearProfile ? null : profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      qrKey: clearQrKey ? null : qrKey ?? this.qrKey,
      qrImageData: clearQrImage ? null : qrImageData ?? this.qrImageData,
      qrStatusMessage: qrStatusMessage ?? this.qrStatusMessage,
      isPollingQr: isPollingQr ?? this.isPollingQr,
    );
  }
}

class NeteaseAuthController extends StateNotifier<NeteaseAuthState> {
  NeteaseAuthController(this._ref) : super(const NeteaseAuthState());

  final Ref _ref;
  Timer? _qrTimer;
  bool _hasLoaded = false;

  static const _cookieKey = 'netease.auth.cookie.v1';
  static const _profileKey = 'netease.auth.profile.v1';

  /// 优先加密存储、密钥环不可用时回退 `shared_preferences` 的 cookie 存储。
  final SecureCookieStore _cookieStore = SecureCookieStore(key: _cookieKey);

  Future<void> load({bool startQrIfLoggedOut = false}) async {
    if (_hasLoaded) {
      if (startQrIfLoggedOut && !state.hasCookie && state.qrImageData == null) {
        await startQrLogin();
      }
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final cookie = await _cookieStore.read();
    final profile = _profileFromPayload(preferences.getString(_profileKey));
    _hasLoaded = true;
    state = state.copyWith(
      cookie: cookie,
      profile: profile,
      clearProfile: profile == null,
      clearError: true,
    );

    if (cookie.isNotEmpty) {
      await refreshLoginStatus();
    } else if (startQrIfLoggedOut) {
      await startQrLogin();
    }
  }

  Future<void> startQrLogin() async {
    _cancelQrTimer();
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearQrKey: true,
      clearQrImage: true,
      qrStatusMessage: '正在生成二维码...',
      isPollingQr: false,
    );

    try {
      final session = await _repository().createQrSession();
      state = state.copyWith(
        isLoading: false,
        qrKey: session.key,
        qrImageData: session.imageData,
        qrStatusMessage: '打开网易云音乐 App 扫码登录',
        isPollingQr: true,
      );
      _qrTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(_checkQrLogin(session.key)),
      );
      await _checkQrLogin(session.key);
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        isPollingQr: false,
        errorMessage: '生成二维码失败：$error',
      );
    }
  }

  Future<void> importCookie(String rawCookie) async {
    final cookie = NeteaseAuthRepository.normalizeCookie(rawCookie);
    if (cookie.isEmpty) {
      state = state.copyWith(errorMessage: 'Cookie 为空或格式不正确');
      return;
    }

    _cancelQrTimer();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _applyCookie(cookie);
      state = state.copyWith(isLoading: false);
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Cookie 登录失败：$error',
      );
    }
  }

  Future<void> refreshLoginStatus() async {
    final cookie = state.cookie;
    if (cookie.isEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final status = await _repository(
        cookie: cookie,
      ).loginStatus(cookie: cookie);
      if (status.profile == null) {
        await _clearPersistedAuth();
        state = state.copyWith(
          cookie: '',
          clearProfile: true,
          isLoading: false,
          errorMessage: '网易云登录态已失效',
        );
        return;
      }
      await _persistAuth(cookie, status.profile!);
      state = state.copyWith(
        cookie: cookie,
        profile: status.profile,
        isLoading: false,
      );
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '校验登录态失败：$error');
    }
  }

  Future<void> logout() async {
    final cookie = state.cookie;
    _cancelQrTimer();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (cookie.isNotEmpty) {
        await _repository(cookie: cookie).logout();
      }
    } on Object {
      // Local auth state should still be cleared when server logout fails.
    }
    await _clearPersistedAuth();
    state = const NeteaseAuthState();
  }

  Future<void> _checkQrLogin(String key) async {
    if (state.qrKey != key) {
      return;
    }

    try {
      final result = await _repository().checkQrLogin(key);
      if (result.isExpired) {
        _cancelQrTimer();
        state = state.copyWith(
          qrStatusMessage: result.message,
          isPollingQr: false,
        );
        return;
      }
      if (result.isSuccess) {
        _cancelQrTimer();
        state = state.copyWith(qrStatusMessage: result.message);
        await _applyCookie(result.cookie ?? '');
        return;
      }
      state = state.copyWith(qrStatusMessage: result.message);
    } on Object catch (error) {
      _cancelQrTimer();
      state = state.copyWith(
        errorMessage: '二维码登录检查失败：$error',
        isPollingQr: false,
      );
    }
  }

  Future<void> _applyCookie(String cookie) async {
    if (cookie.isEmpty) {
      throw const NeteaseApiException(message: '登录成功但未返回 Cookie');
    }

    final status = await _repository(
      cookie: cookie,
    ).loginStatus(cookie: cookie);
    if (status.profile == null) {
      throw const NeteaseApiException(message: 'Cookie 校验失败');
    }

    await _persistAuth(cookie, status.profile!);
    state = state.copyWith(
      cookie: cookie,
      profile: status.profile,
      isLoading: false,
      clearError: true,
      isPollingQr: false,
      qrStatusMessage: '登录成功',
    );
  }

  NeteaseAuthRepository _repository({String? cookie}) {
    final settings = _ref.read(appSettingsControllerProvider);
    return NeteaseAuthRepository(
      client: NeteaseApiClient(
        config: NeteaseApiConfig(
          baseUrl: settings.neteaseApiBaseUrl,
          cookie: cookie,
        ),
      ),
    );
  }

  Future<void> _persistAuth(String cookie, NeteaseProfile profile) async {
    await _cookieStore.write(cookie);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<void> _clearPersistedAuth() async {
    await _cookieStore.delete();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_profileKey);
  }

  NeteaseProfile? _profileFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      return null;
    }
    return NeteaseProfile.fromJson(Map<String, Object?>.from(decoded));
  }

  void _cancelQrTimer() {
    _qrTimer?.cancel();
    _qrTimer = null;
    state = state.copyWith(isPollingQr: false);
  }

  @override
  void dispose() {
    _cancelQrTimer();
    super.dispose();
  }
}
