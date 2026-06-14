/// 网易云 JSON 解析的共享值提取助手。
///
/// 网易云接口返回的字段类型并不稳定：数字可能以字符串返回、布尔可能是
/// `0/1` 或 `"true"`、对象有时缺失。下列函数集中容错逻辑，供
/// `netease_*_repository.dart` 复用，避免各 Repository 重复实现。
library;

/// 将任意值转换为 `Map<String, Object?>`，非 Map 返回 null。
Map<String, Object?>? neteaseMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return Map<String, Object?>.from(value);
}

/// 将字符串或数字统一转换为字符串，其余返回 null。
String? neteaseString(Object? value) {
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

/// 将数字或可解析的数字字符串转换为 int，其余返回 null。
int? neteaseInt(Object? value) {
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

/// 将 bool、`0/1` 数字或 `"true"/"1"` 字符串转换为 bool，无法判定返回 null。
///
/// 需要非空结果的调用方使用 `neteaseBool(x) ?? false`。
bool? neteaseBool(Object? value) {
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
