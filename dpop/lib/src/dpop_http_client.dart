import 'package:http/http.dart' as http;
import 'dpop_generator.dart';

const int _httpStatusUnauthorized = 401;

class DPopHttpClient extends http.BaseClient {
  final http.Client _httpClient;
  final DPopGenerator _generator;
  final Future<String?> Function() _getAccessToken;
  final bool _isInternalClient;

  String? _lastNonce;

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
    await _signRequest(request, accessToken, nonce: _lastNonce);
    final response = await _httpClient.send(request);
    _updateNonce(response.headers);

    if (response.statusCode != _httpStatusUnauthorized ||
        !response.headers.containsKey('dpop-nonce')) {
      // No need to handle nonce retry logic here.
      return response;
    }

    if (_lastNonce == null || _lastNonce!.isEmpty) {
      return response;
    }

    final retryRequest = _tryCopyRequest(request);
    if (retryRequest == null) {
      return response;
    }
    await response.stream.drain();

    await _signRequest(retryRequest, accessToken, nonce: _lastNonce);
    final retryResponse = await _httpClient.send(retryRequest);
    _updateNonce(retryResponse.headers);
    return retryResponse;
  }

  void _updateNonce(Map<String, String> headers) {
    if (headers.containsKey('dpop-nonce')) {
      _lastNonce = headers['dpop-nonce'];
    }
  }

  Future<void> _signRequest(
    http.BaseRequest request,
    String? accessToken, {
    String? nonce,
  }) async {
    final proof = await _generator.createProof(
      httpMethod: request.method,
      httpUrl: request.url.toString(),
      accessToken: accessToken,
      nonce: nonce,
    );

    request.headers['DPoP'] = proof;

    if (accessToken != null) {
      request.headers['Authorization'] = 'DPoP $accessToken';
    }
  }

  http.BaseRequest? _tryCopyRequest(http.BaseRequest original) {
    if (original is http.Request) {
      return http.Request(original.method, original.url)
        ..followRedirects = original.followRedirects
        ..headers.addAll(original.headers)
        ..maxRedirects = original.maxRedirects
        ..persistentConnection = original.persistentConnection
        ..encoding = original.encoding
        ..bodyBytes =
            original.bodyBytes; // References same memory, no deep copy
    }
    // We cannot safely retry MultipartRequest (File Uploads) or
    // StreamedRequest because the data stream is single-use and already consumed.
    return null;
  }

  @override
  void close() {
    if (_isInternalClient) {
      _httpClient.close();
    }
    super.close();
  }
}
