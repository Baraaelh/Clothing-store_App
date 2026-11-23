import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

/// عنوان سيرفر الـ API الحالي.
///
/// إن بُني التطبيق مع `--dart-define=API_BASE_URL=...` فهو ثابت. وإلا يكتبه المستخدم
/// في شاشة الدخول (مفيد للتجربة على سيرفر محلي في نفس شبكة الواي فاي) ويُحفظ على الجهاز.
class ServerConfig {
  ServerConfig({FlutterSecureStorage? storage, String? initial})
    : _storage = storage ?? const FlutterSecureStorage(),
      _url = initial ?? ApiConfig.baseUrl;

  static const _key = 'server_url';

  final FlutterSecureStorage? _storage;
  String _url;

  /// للاختبارات: عنوان ثابت بلا تخزين.
  ServerConfig.fixed(String url) : _storage = null, _url = url;

  String get url => _url;

  bool get isConfigured => _url.isNotEmpty;

  /// العنوان ثابت في النسخة (لا يُعدّل من شاشة الدخول).
  bool get isBuiltIn => ApiConfig.isConfigured;

  Future<void> load() async {
    if (isBuiltIn || _storage == null) return;
    _url = await _storage.read(key: _key) ?? '';
  }

  Future<void> save(String input) async {
    if (isBuiltIn) return;
    _url = normalize(input);
    await _storage?.write(key: _key, value: _url);
  }

  /// `192.168.1.5:8000` ← `http://192.168.1.5:8000/api/v1`
  static String normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'http://$url';
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/api/v1')) url = '$url/api/v1';
    return url;
  }
}
