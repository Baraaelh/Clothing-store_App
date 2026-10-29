import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

/// حفظ الجلسة على الجهاز (التوكن في التخزين الآمن، لا في SQLite).
abstract interface class SessionStorage {
  Future<Session?> read();

  Future<void> write(Session session);

  /// يحذف الجلسة ويحتفظ بآخر فرع، لمعرفة إن تغيّر الفرع في الدخول القادم.
  Future<void> clear();

  Future<int?> lastBranchId();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'session';
  static const _lastBranchKey = 'last_branch_id';

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
    await _storage.write(key: _lastBranchKey, value: '${session.branchId}');
  }

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);

  @override
  Future<int?> lastBranchId() async => int.tryParse(await _storage.read(key: _lastBranchKey) ?? '');
}
