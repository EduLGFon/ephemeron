part of '../google_api_client.dart';

abstract class _GoogleApiBase implements GoogleApiClient {
  _GoogleApiBase({
    required this._accessToken,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _http = _TimeoutClient(httpClient ?? http.Client(), requestTimeout);

  final Future<String?> Function() _accessToken;
  final http.Client _http;
  final Duration requestTimeout;

  Future<Map<String, String>> _headers({String? etag}) async {
    final token = await _accessToken();
    if (token == null) throw GoogleApiException(401, 'no token');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    if (etag != null) headers['If-Match'] = etag;
    return headers;
  }

  Never _throw(http.Response r) {
    int? retry;
    final ra = r.headers['retry-after'];
    if (ra != null) retry = int.tryParse(ra);
    throw GoogleApiException(r.statusCode, r.body, retryAfterSec: retry);
  }
}

/// Wraps an inner [http.Client] so every request aborts after
/// [requestTimeout]. Tradeoff: a timeout surfaces as a [TimeoutException]
/// (classified as a network failure by callers) but cannot cancel the
/// underlying socket, which may keep running until the server responds.
class _TimeoutClient extends http.BaseClient {
  _TimeoutClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(_timeout);
  }

  @override
  void close() => _inner.close();
}
