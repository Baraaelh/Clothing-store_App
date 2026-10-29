import 'package:anaqa_mobile/core/error/exceptions.dart';
import 'package:anaqa_mobile/core/network/api_client.dart';
import 'package:anaqa_mobile/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolvePath fills and encodes path params', () {
    expect(ApiClient.resolvePath('/online-orders/{id}/status', {'id': 'WEB 1'}), '/online-orders/WEB%201/status');
    expect(() => ApiClient.resolvePath('/branches/{branchId}', {}), throwsArgumentError);
  });

  test('requests throw ApiNotConfiguredException until the API is configured', () async {
    expect(() => ApiClient(baseUrl: '').get('/sales'), throwsA(isA<ApiNotConfiguredException>()));
    expect(() => ApiClient(baseUrl: 'https://x.test').get(null), throwsA(isA<ApiNotConfiguredException>()));
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
