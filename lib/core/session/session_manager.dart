import 'session.dart';
import 'session_storage.dart';

/// يحمل الجلسة الحالية. الـ repositories تقرأ منه الفرع والمستخدم وقت التنفيذ،
/// و`ApiClient` يقرأ منه التوكن.
class SessionManager {
  SessionManager(this._storage);

  final SessionStorage _storage;
  Session? _current;

  Session? get current => _current;

  /// للعمليات التي لا تحدث إلا بعد تسجيل الدخول.
  Session get requireSession => _current ?? (throw StateError('No active session'));

  Future<Session?> restore() async => _current = await _storage.read();

  Future<void> start(Session session) async {
    await _storage.write(session);
    _current = session;
  }

  Future<void> end() async {
    _current = null;
    await _storage.clear();
  }

  Future<int?> lastBranchId() => _storage.lastBranchId();
}
