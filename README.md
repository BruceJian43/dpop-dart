# dpop-dart

A secure, pure Dart implementation of **RFC 9449: OAuth 2.0 Demonstrating Proof-of-Possession (DPoP)** at the application layer.

This library abstracts the complexity of cryptographic signing and header formatting, allowing Dart and Flutter developers to easily upgrade from standard Bearer tokens to DPoP-bound access tokens.

> **⚠️ Status: Under Development**
> This project is currently a work in progress. APIs may change, and features are still being added.

## Usage

**1. Automatic HTTP Signing**

Use `DPopHttpClient` to automatically generate proofs, attach headers, and handle nonce retries. It serves as a drop-in wrapper around `http.Client`.

**Features**:

* **Automatic Header Injection**: Adds DPoP proof and sets Authorization: DPoP <token> automatically.

* **Nonce Handling**: Automatically caches DPoP-Nonce headers from the server.

* **Auto-Retry**: If the server rejects a request with a 401 and a new nonce, the client automatically re-signs and retries the request transparently.

```dart
import 'package:dpop/dpop.dart';
import 'package:http/http.dart' as http;

void main() async {
  // By default, this generates a fresh key pair for the session.
  final client = DPopHttpClient(
    // Optional: Provide a callback if you need to attach an Access Token
    // getAccessToken: () async => 'your-access-token',
  );

  try {
    // The client automatically adds the 'DPoP' header to this request.
    final response = await client.get(
      Uri.parse('https://pub.dev/'),
    );
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } finally {
    // Close the client when done to release resources.
    client.close();
  }
}
```

**2. Manual Proof Generation**

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
