import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_music/features/login/application/secure_cookie_store.dart';

/// 内存实现，模拟可用的密钥环。
class _InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// 所有操作均抛错，模拟无可用密钥环（如未装 gnome-keyring 的 Linux）。
class _UnavailableSecureStore implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) async => throw Exception('no keyring');

  @override
  Future<void> write(String key, String value) async =>
      throw Exception('no keyring');

  @override
  Future<void> delete(String key) async => throw Exception('no keyring');
}

void main() {
  const key = 'netease.auth.cookie.v1';
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureCookieStore（密钥环可用）', () {
    test('write 存入安全存储并清除明文副本', () async {
      SharedPreferences.setMockInitialValues({key: 'legacy-plain'});
      final secure = _InMemorySecureStore();
      final store = SecureCookieStore(key: key, secureStore: secure);

      await store.write('fresh-cookie');

      expect(await secure.read(key), 'fresh-cookie');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull);
    });

    test('read 把历史明文迁移到安全存储后清除明文', () async {
      SharedPreferences.setMockInitialValues({key: 'legacy-plain'});
      final secure = _InMemorySecureStore();
      final store = SecureCookieStore(key: key, secureStore: secure);

      final value = await store.read();

      expect(value, 'legacy-plain');
      expect(await secure.read(key), 'legacy-plain');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull);
    });

    test('read 优先返回安全存储中的值', () async {
      SharedPreferences.setMockInitialValues({});
      final secure = _InMemorySecureStore();
      await secure.write(key, 'secure-cookie');
      final store = SecureCookieStore(key: key, secureStore: secure);

      expect(await store.read(), 'secure-cookie');
    });

    test('delete 同时清除安全存储与明文', () async {
      SharedPreferences.setMockInitialValues({key: 'plain'});
      final secure = _InMemorySecureStore();
      await secure.write(key, 'secure');
      final store = SecureCookieStore(key: key, secureStore: secure);

      await store.delete();

      expect(await secure.read(key), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull);
    });
  });

  group('SecureCookieStore（密钥环不可用，回退）', () {
    test('write 回退到 shared_preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SecureCookieStore(
        key: key,
        secureStore: _UnavailableSecureStore(),
      );

      await store.write('fallback-cookie');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), 'fallback-cookie');
    });

    test('read 回退读取 shared_preferences 明文且保留以备后续回退', () async {
      SharedPreferences.setMockInitialValues({key: 'plain-cookie'});
      final store = SecureCookieStore(
        key: key,
        secureStore: _UnavailableSecureStore(),
      );

      expect(await store.read(), 'plain-cookie');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), 'plain-cookie');
    });
  });
}
