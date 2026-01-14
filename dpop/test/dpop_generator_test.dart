import 'dart:convert';
import 'package:test/test.dart';
import 'package:webcrypto/webcrypto.dart';

import 'package:dpop/src/dpop_generator.dart';

void main() {
  group('DPopGenerator', () {
    late DPopGenerator generator;

    setUp(() async {
      generator = DPopGenerator();
    });

    test('generates a token with 3 parts (Header.Payload.Signature)', () async {
      final proof = await generator.createProof(
        httpUrl: 'https://api.mercari.jp/v2/entities:search',
        httpMethod: 'POST',
      );

      final parts = proof.split('.');
      expect(
        parts.length,
        3,
        reason: 'DPoP proof must be a standard JWT format',
      );
    });

    test('includes correct header fields (typ, alg, jwk)', () async {
      final proof = await generator.createProof(
        httpUrl: 'https://api.example.com',
        httpMethod: 'GET',
      );

      final parts = proof.split('.');
      final headerMap = _decodeJwtPart(parts[0]);

      expect(headerMap['typ'], 'dpop+jwt', reason: 'Must have explicit type');
      expect(headerMap['alg'], 'ES256', reason: 'Must use ES256');
      expect(
        headerMap.containsKey('jwk'),
        isTrue,
        reason: 'Must include public key',
      );

      final jwk = headerMap['jwk'] as Map;
      expect(jwk['kty'], 'EC');
      expect(jwk['crv'], 'P-256');
    });

    test('includes correct claims in payload', () async {
      final uri = 'https://api/test?query=ignore_me';
      const method = 'GET';
      const nonce = 'test-nonce-123';

      final proof = await generator.createProof(
        httpUrl: uri,
        httpMethod: method,
        nonce: nonce,
      );

      final payload = _decodeJwtPart(proof.split('.')[1]);
      // Check Normalization (query params should be removed)
      expect(payload['htu'], 'https://api/test');
      expect(payload['htm'], 'GET');
      expect(payload['nonce'], 'test-nonce-123');
      expect(payload.containsKey('jti'), isTrue);
      expect(payload.containsKey('iat'), isTrue);
      // Ensure 'ath' is NOT present if no access token provided
      expect(payload.containsKey('ath'), isFalse);
    });

    test(
      'calculates correct "ath" (Access Token Hash) when token provided',
      () async {
        const accessToken = 'my-secret-access-token';
        final expectedHashBytes = await Hash.sha256.digestBytes(
          utf8.encode(accessToken),
        );
        final expectedAth = base64Url
            .encode(expectedHashBytes)
            .replaceAll('=', '');

        final proof = await generator.createProof(
          httpUrl: 'https://example.com',
          httpMethod: 'POST',
          accessToken: accessToken,
        );

        final payload = _decodeJwtPart(proof.split('.')[1]);
        expect(payload.containsKey('ath'), isTrue);
        expect(payload['ath'], expectedAth);
      },
    );

    test('generates valid JWK thumbprint', () async {
      final thumbprint = await generator.publicKeyThumbprint;

      expect(thumbprint, isNotEmpty);
      expect(
        thumbprint,
        isNot(contains('=')),
        reason: 'Should be base64url without padding',
      );

      // It should remain consistent for the same instance
      final thumbprint2 = await generator.publicKeyThumbprint;
      expect(thumbprint, thumbprint2);
    });

    test('verifies cryptographically', () async {
      final proof = await generator.createProof(
        httpUrl: 'https://verify.me',
        httpMethod: 'POST',
      );

      final parts = proof.split('.');
      final headerString = parts[0];
      final payloadString = parts[1];
      final signatureBytes = base64Url.decode(base64.normalize(parts[2]));
      final signingInput = utf8.encode('$headerString.$payloadString');

      final header = _decodeJwtPart(headerString);
      final jwk = header['jwk'] as Map<String, dynamic>;

      final publicKey = await EcdsaPublicKey.importJsonWebKey(
        jwk,
        EllipticCurve.p256,
      );

      final isValid = await publicKey.verifyBytes(
        signatureBytes,
        signingInput,
        Hash.sha256,
      );
      expect(isValid, isTrue, reason: 'The generated signature must be valid');
    });
  });
}

Map<String, dynamic> _decodeJwtPart(String part) {
  final normalized = base64.normalize(part);
  final string = utf8.decode(base64Url.decode(normalized));
  return jsonDecode(string) as Map<String, dynamic>;
}
