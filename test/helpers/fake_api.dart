import 'package:anaqa_mobile/core/network/api_client.dart';

typedef Handler = Future<Map<String, Object?>> Function(Object? body, Map<String, Object?>? query);

/// ApiClient وهمي: كل مسار له دالة تحدد الرد، ويُسجل كل طلب.
class FakeApi extends ApiClient {
  FakeApi() : super(baseUrl: 'http://fake.test');

  final Map<String, Handler> routes = {};
  final List<(String, Object?)> calls = [];

  void on(String path, Handler handler) => routes[path] = handler;

  @override
  Future<Map<String, Object?>> get(
    String endpoint, {
    Map<String, Object> pathParams = const {},
    Map<String, Object?>? query,
  }) => _handle(ApiClient.resolvePath(endpoint, pathParams), null, query);

  @override
  Future<Map<String, Object?>> post(String endpoint, {Map<String, Object> pathParams = const {}, Object? body}) =>
      _handle(ApiClient.resolvePath(endpoint, pathParams), body, null);

  Future<Map<String, Object?>> _handle(String path, Object? body, Map<String, Object?>? query) {
    calls.add((path, body));
    final handler = routes[path];
    if (handler == null) return Future.value(const {});
    return handler(body, query);
  }

  List<Object?> bodiesFor(String path) => [
    for (final (p, b) in calls)
      if (p == path) b,
  ];
}
