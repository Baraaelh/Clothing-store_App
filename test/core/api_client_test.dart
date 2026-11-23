import 'package:anaqa_mobile/core/config/server_config.dart';
import 'package:anaqa_mobile/core/error/exceptions.dart';
import 'package:anaqa_mobile/core/network/api_client.dart';
import 'package:anaqa_mobile/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolvePath fills and encodes path params', () {
    expect(ApiClient.resolvePath('/sync/operations/{uuid}', {'uuid': 'a b'}), '/sync/operations/a%20b');
    expect(() => ApiClient.resolvePath('/branches/{branchId}', {}), throwsArgumentError);
  });

  test('requests throw ApiNotConfiguredException until the API is configured', () async {
    expect(() => ApiClient(baseUrl: '').get('/auth/me'), throwsA(isA<ApiNotConfiguredException>()));
  });

  test('ServerException.displayMessage prefers the first validation error', () {
    const e = ServerException(
      'راجع البيانات.',
      statusCode: 422,
      body: {
        'errors': {
          'username': ['اسم المستخدم مطلوب'],
        },
      },
    );
    expect(e.displayMessage, 'اسم المستخدم مطلوب');
    expect(const ServerException('x').displayMessage, 'x');
  });

  test('server address typed on the login screen is normalized to the v1 base url', () {
    expect(ServerConfig.normalize('192.168.1.5:8000'), 'http://192.168.1.5:8000/api/v1');
    expect(ServerConfig.normalize(' https://store.example.com/ '), 'https://store.example.com/api/v1');
    expect(ServerConfig.normalize('http://10.0.0.2:8000/api/v1'), 'http://10.0.0.2:8000/api/v1');
    expect(ServerConfig.normalize(''), '');
  });

  test('ServerException.isPermanent', () {
    expect(const ServerException('', statusCode: 422).isPermanent, isTrue);
    expect(const ServerException('', statusCode: 429).isPermanent, isFalse);
    expect(const ServerException('', statusCode: 500).isPermanent, isFalse);
  });

  test('Money converts decimals to minor units without float drift', () {
    expect(Money.fromJson('19.99'), 1999);
    expect(Money.fromJson(0.1 + 0.2), 30);
    expect(Money.toDecimalString(1999), '19.99');
  });
}
