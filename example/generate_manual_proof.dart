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
