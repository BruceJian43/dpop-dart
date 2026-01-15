# dpop-dart

A secure, pure Dart implementation of **RFC 9449: OAuth 2.0 Demonstrating Proof-of-Possession (DPoP)** at the application layer.

This library abstracts the complexity of cryptographic signing and header formatting, allowing Dart and Flutter developers to easily upgrade from standard Bearer tokens to DPoP-bound access tokens.

> **⚠️ Status: Under Development**
> This project is currently a work in progress. APIs may change, and features are still being added.

## Usage
**1. Manual Proof Generation**

If you need raw control over the DPoP proof generation (e.g., for debugging or non-HTTP protocols), you can use DPopGenerator directly.

```dart
import 'package:dpop/dpop.dart';

void main() async {
  final dpop = DPopGenerator();

  final proof = await dpop.createProof(
    httpMethod: 'POST',
    httpUrl: 'https://api.example.com/resource',
    accessToken: 'your-access-token',
  );

  print('DPoP Header: $proof');
  print('Key ID: ${await dpop.publicKeyThumbprint}');
}
```

**2. Automatic HTTP Signing**

**Work in Progress**
