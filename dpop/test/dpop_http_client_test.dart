import 'dart:convert';
import 'dart:io';

import 'package:dpop/dpop.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

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

        return http.Response('OK', HttpStatus.ok);
      });

      final client = DPopHttpClient(client: mockInner, generator: generator);

      final response = await client.get(
        Uri.parse('https://api.example.com/test'),
      );
      expect(response.statusCode, HttpStatus.ok);
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
          return http.Response('OK', HttpStatus.ok);
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
        return http.Response('OK', HttpStatus.ok);
      });

      final client = DPopHttpClient(client: mockInner, generator: generator);

      await client.get(Uri.parse('https://api.example.com/public'));
    });
  });
}
