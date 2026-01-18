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
