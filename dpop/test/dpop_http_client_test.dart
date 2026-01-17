import 'dart:convert';

import 'package:dpop/dpop.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const int _httpStatusUnauthorized = 401;
const int _httpStatusOk = 200;

void main() {
  group('DPopHttpClient', () {
    late DPopGenerator generator;

    setUp(() {
      generator = DPopGenerator();
    });

    test('automatically adds "DPoP" header to requests', () async {
      final mockInner = MockClient((request) async {
        expect(request.headers.containsKey('DPoP'), isTrue);

        final parts = request.headers['DPoP']!.split('.');
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64.normalize(parts[1]))),
        );

        expect(payload['htu'], 'https://api.example.com/test');
        expect(payload['htm'], 'GET');

        return http.Response('OK', _httpStatusOk);
      });

      final client = DPopHttpClient(client: mockInner, generator: generator);

      final response = await client.get(
        Uri.parse('https://api.example.com/test'),
      );
      expect(response.statusCode, _httpStatusOk);
    });

    test(
      'adds "Authorization: DPoP <token>" when access token is provided',
      () async {
        const myToken = 'test-access-token-123';
        final mockInner = MockClient((request) async {
          expect(request.headers.containsKey('DPoP'), isTrue);
          expect(request.headers['Authorization'], 'DPoP $myToken');
          final parts = request.headers['DPoP']!.split('.');
          final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64.normalize(parts[1]))),
          );
          expect(payload.containsKey('ath'), isTrue);
          return http.Response('OK', _httpStatusOk);
        });

        final client = DPopHttpClient(
          client: mockInner,
          generator: generator,
          getAccessToken: () async => myToken,
        );

        await client.post(Uri.parse('https://api.example.com/submit'));
      },
    );

    test('does NOT add Authorization header if access token is null', () async {
      final mockInner = MockClient((request) async {
        expect(request.headers.containsKey('DPoP'), isTrue);
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('OK', _httpStatusOk);
      });

      final client = DPopHttpClient(client: mockInner, generator: generator);

      await client.get(Uri.parse('https://api.example.com/public'));
    });

    test(
      'retries automatically with new nonce when server returns 401 + DPoP-Nonce',
      () async {
        int callCount = 0;
        const expectedNonce = 'server-provided-nonce-123';

        final mockInner = MockClient((request) async {
          callCount++;

          if (callCount == 1) {
            expect(request.headers.containsKey('DPoP'), isTrue);
            return http.Response(
              'Unauthorized',
              _httpStatusUnauthorized,
              headers: {'dpop-nonce': expectedNonce},
            );
          }

          if (callCount == 2) {
            final parts = request.headers['DPoP']!.split('.');
            final payload = jsonDecode(
              utf8.decode(base64Url.decode(base64.normalize(parts[1]))),
            );
            expect(payload['nonce'], expectedNonce);
            return http.Response('Success', _httpStatusOk);
          }

          throw Exception('Too many calls');
        });

        final client = DPopHttpClient(
          client: mockInner,
          generator: generator,
          getAccessToken: () async => 'token',
        );

        final response = await client.post(
          Uri.parse('https://api.example.com/retry-test'),
          body: {'key': 'value'}, // Add body to ensure copying works
        );

        expect(response.statusCode, 200);
        expect(response.body, 'Success');
        expect(callCount, 2); // Ensure it actually retried
      },
    );
  });
}
