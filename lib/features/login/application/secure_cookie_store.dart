import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 安全键值存储抽象，便于在测试或无密钥环环境中替换底层实现。
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// 基于 `flutter_secure_storage` 的默认实现（系统密钥环 / Keychain / KeyStore）。
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 网易云登录 cookie 的存储。
///
/// 优先使用系统密钥环（[SecureKeyValueStore]）做 at-rest 加密；当平台没有可用
/// 密钥环时（例如未安装 gnome-keyring/kwallet 的 Linux），自动回退到
/// `shared_preferences`，确保登录功能不会因密钥环缺失而中断。
///
/// 同时负责把历史上以明文存于 `shared_preferences` 的 cookie 迁移到安全存储：
/// 一旦迁移成功即清除明文副本。
class SecureCookieStore {
  SecureCookieStore({
    required String key,
    SecureKeyValueStore secureStore = const FlutterSecureKeyValueStore(),
  }) : _key = key,
       _secureStore = secureStore;

  final String _key;
  final SecureKeyValueStore _secureStore;

  /// 读取 cookie：优先安全存储；否则回退到 `shared_preferences` 中的明文值，
  /// 并在密钥环可用时把该明文迁移进安全存储。
  Future<String> read() async {
    try {
      final secure = await _secureStore.read(_key);
      if (secure != null && secure.isNotEmpty) {
        return secure;
      }
    } on Object {
      // 密钥环不可用，回退到 shared_preferences。
    }

    final preferences = await SharedPreferences.getInstance();
    final legacy = preferences.getString(_key) ?? '';
    if (legacy.isNotEmpty) {
      try {
        await _secureStore.write(_key, legacy);
        await preferences.remove(_key);
      } on Object {
        // 迁移失败（无密钥环），保留明文以便回退读取。
      }
    }
    return legacy;
  }

  /// 写入 cookie：优先安全存储并清除明文副本；密钥环不可用时回退到
  /// `shared_preferences`。
  Future<void> write(String cookie) async {
    try {
      await _secureStore.write(_key, cookie);
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_key);
      return;
    } on Object {
      // 回退到 shared_preferences。
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, cookie);
  }

  /// 清除 cookie：安全存储与 `shared_preferences` 中的副本都会被移除。
  Future<void> delete() async {
    try {
      await _secureStore.delete(_key);
    } on Object {
      // 忽略密钥环错误，仍要清除明文副本。
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
