import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

/// حفظ الجلسة على الجهاز (التوكن في التخزين الآمن، لا في SQLite).
abstract interface class SessionStorage {
  Future<Session?> read();

  Future<void> write(Session session);

  Future<void> clear();

  /// مفتاح نطاق البيانات المحلية لآخر جلسة (مستخدم + فرع)، لمعرفة إن تغيّر في الدخول القادم.
  Future<String?> lastScope();

  /// UUID الجهاز المحفوظ لهذا الحساب، إن سبق تسجيله.
  Future<String?> deviceIdFor(String username);

  Future<void> saveDeviceId(String username, String deviceId);
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'session_v2';
  static const _scopeKey = 'last_scope';
  static const _devicePrefix = 'device_id:';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      await _storage.delete(key: _sessionKey); // بيانات تالفة: اطلب تسجيل دخول جديد
      return null;
    }
  }

  @override
  Future<void> write(Session session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    await _storage.write(key: _scopeKey, value: scopeOf(session));
  }

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);

  @override
  Future<String?> lastScope() => _storage.read(key: _scopeKey);

  @override
  Future<String?> deviceIdFor(String username) => _storage.read(key: '$_devicePrefix${username.toLowerCase()}');

  @override
  Future<void> saveDeviceId(String username, String deviceId) =>
      _storage.write(key: '$_devicePrefix${username.toLowerCase()}', value: deviceId);
}

/// البيانات المحلية (الكاش) تخص مستخدمًا وفرعًا معينين.
String scopeOf(Session session) => '${session.userId}@${session.branchId}';
