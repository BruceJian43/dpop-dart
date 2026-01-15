import 'package:http/http.dart' as http;
import 'dpop_generator.dart';

class DPopHttpClient extends http.BaseClient {
  final http.Client _httpClient;
  final DPopGenerator _generator;
  final Future<String?> Function() _getAccessToken;
  final bool _isInternalClient;

  DPopHttpClient({
    Future<String?> Function()? getAccessToken,
    http.Client? client,
    DPopGenerator? generator,
  }) : _getAccessToken = getAccessToken ?? _noTokenProvider,
       _httpClient = client ?? http.Client(),
       _generator = generator ?? DPopGenerator(),
       _isInternalClient = client == null;

  static Future<String?> _noTokenProvider() async => null;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final accessToken = await _getAccessToken();

    final proof = await _generator.createProof(
      httpMethod: request.method,
      httpUrl: request.url.toString(),
      accessToken: accessToken,
    );

    request.headers['DPoP'] = proof;

    if (accessToken != null) {
      request.headers['Authorization'] = 'DPoP $accessToken';
    }

    return _httpClient.send(request);
  }

  @override
  void close() {
    if (_isInternalClient) {
      _httpClient.close();
    }
    super.close();
  }
}
