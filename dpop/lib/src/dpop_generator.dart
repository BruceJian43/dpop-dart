import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:webcrypto/webcrypto.dart';

enum DPopAlgorithm { ES256 }

class DPopGenerator {
  final Uuid _uuid = const Uuid();
  final DPopAlgorithm algorithm;
  KeyPair<EcdsaPrivateKey, EcdsaPublicKey>? _keyPair;

  DPopGenerator({
    KeyPair<EcdsaPrivateKey, EcdsaPublicKey>? keyPair,
    this.algorithm = DPopAlgorithm.ES256,
  }) : _keyPair = keyPair;

  Future<String> get publicKeyThumbprint async {
    await _ensureInitialized();
    final jwk = await _keyPair!.publicKey.exportJsonWebKey();
    final canonicalJwk = {
      'crv': jwk['crv'],
      'kty': jwk['kty'],
      'x': jwk['x'],
      'y': jwk['y'],
    };

    final jsonString = jsonEncode(canonicalJwk);

    final hashBytes = await Hash.sha256.digestBytes(utf8.encode(jsonString));

    return _base64UrlBytes(hashBytes);
  }

  Future<String> createProof({
    required String httpMethod,
    required String httpUrl,
    String? accessToken,
    String? nonce,
  }) async {
    await _ensureInitialized();

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final jti = _uuid.v4();
    final jwk = await _keyPair!.publicKey.exportJsonWebKey();
    final uri = Uri.parse(httpUrl);

    final header = {
      'typ': 'dpop+jwt',
      'alg': 'ES256',
      'jwk': {
        'kty': jwk['kty'],
        'crv': jwk['crv'],
        'x': jwk['x'],
        'y': jwk['y'],
        'use': 'sig',
      },
    };

    final claims = {
      'htu': _normalizeUrl(uri),
      'htm': httpMethod.toUpperCase(),
      'jti': jti,
      'iat': now,
      if (nonce != null) 'nonce': nonce,
      if (accessToken != null) 'ath': await _calculateAth(accessToken),
    };

    final encodedHeader = _base64Url(jsonEncode(header));
    final encodedPayload = _base64Url(jsonEncode(claims));
    final signingInput = '$encodedHeader.$encodedPayload';

    final signatureBytes = await _keyPair!.privateKey.signBytes(
      utf8.encode(signingInput),
      Hash.sha256,
    );
    final encodedSignature = _base64UrlBytes(signatureBytes);

    return '$signingInput.$encodedSignature';
  }

  Future<void> _ensureInitialized() async {
    if (_keyPair != null) return;
    _keyPair = await EcdsaPrivateKey.generateKey(EllipticCurve.p256);
  }

  Future<String> _calculateAth(String accessToken) async {
    final bytes = utf8.encode(accessToken);
    final hashBytes = await Hash.sha256.digestBytes(bytes);
    return _base64UrlBytes(hashBytes);
  }

  String _normalizeUrl(Uri uri) {
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: uri.path,
    ).toString();
  }

  String _base64UrlBytes(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  String _base64Url(String input) => _base64UrlBytes(utf8.encode(input));
}
