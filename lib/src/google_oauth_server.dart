import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class OAuthServer {
  Future<GoogleOAuthTokenResponse?> exchangeAuthorizationCode({
    required String clientId,
    required String code,
  });

  Future<GoogleOAuthTokenResponse?> refreshAccessToken({
    required String clientId,
    required String refreshToken,
  });

  Future<void> dispose();
}

class GoogleOAuthTokenResponse {
  const GoogleOAuthTokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.tokenType,
    this.expiresIn,
    this.raw = const <String, dynamic>{},
  });

  final String accessToken;
  final String? refreshToken;
  final String? tokenType;
  final int? expiresIn;
  final Map<String, dynamic> raw;
}

class GoogleOAuthServer implements OAuthServer {
  GoogleOAuthServer(
    this.endpoint, {
    http.Client? client,
    void Function(String message)? log,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _log = log;

  final Uri endpoint;
  final http.Client _client;
  final bool _ownsClient;
  final void Function(String message)? _log;

  @override
  Future<void> dispose() async {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<GoogleOAuthTokenResponse?> exchangeAuthorizationCode({
    required String clientId,
    required String code,
  }) {
    _log?.call(
      'OAuth exchange: authorization_code -> ${endpoint.host}${endpoint.path}',
    );
    return _exchange(<String, String>{
      'grant_type': 'authorization_code',
      'client_id': clientId,
      'code': code,
    });
  }

  @override
  Future<GoogleOAuthTokenResponse?> refreshAccessToken({
    required String clientId,
    required String refreshToken,
  }) {
    _log?.call(
      'OAuth exchange: refresh_token -> ${endpoint.host}${endpoint.path}',
    );
    return _exchange(<String, String>{
      'grant_type': 'refresh_token',
      'client_id': clientId,
      'refresh_token': refreshToken,
    });
  }

  Future<GoogleOAuthTokenResponse?> _exchange(Map<String, String> body) async {
    try {
      final response = await _client.post(
        endpoint,
        body: body,
        headers: <String, String>{'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        _log?.call(
          'OAuth exchange failed: HTTP ${response.statusCode} from ${endpoint.host}${endpoint.path}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _log?.call('OAuth exchange failed: response was not a JSON object');
        return null;
      }

      final accessToken = decoded['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        _log?.call('OAuth exchange failed: access_token missing in response');
        return null;
      }

      _log?.call(
        'OAuth exchange succeeded: access token received${decoded['refresh_token'] == null ? '' : ', refresh token present'}',
      );

      return GoogleOAuthTokenResponse(
        accessToken: accessToken,
        refreshToken: decoded['refresh_token'] as String?,
        tokenType: decoded['token_type'] as String?,
        expiresIn: decoded['expires_in'] is int
            ? decoded['expires_in'] as int
            : int.tryParse('${decoded['expires_in'] ?? ''}'),
        raw: decoded,
      );
    } catch (_) {
      _log?.call(
        'OAuth exchange failed: exception while contacting ${endpoint.host}${endpoint.path}',
      );
      return null;
    }
  }
}

class LocalOAuthServer implements OAuthServer {
  LocalOAuthServer({
    required this.clientId,
    required this.clientSecret,
    this.redirectUri,
    http.Client? client,
    void Function(String message)? log,
    Uri? tokenEndpoint,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _log = log,
       endpoint =
           tokenEndpoint ?? Uri.parse('https://oauth2.googleapis.com/token');

  final String clientId;
  final String clientSecret;
  final String? redirectUri;
  final Uri endpoint;
  final http.Client _client;
  final bool _ownsClient;
  final void Function(String message)? _log;

  @override
  Future<void> dispose() async {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<GoogleOAuthTokenResponse?> exchangeAuthorizationCode({
    required String clientId,
    required String code,
  }) {
    _log?.call(
      'Local OAuth exchange: authorization_code -> ${endpoint.host}${endpoint.path}',
    );
    return _exchange(<String, String>{
      'grant_type': 'authorization_code',
      'client_id': clientId,
      'client_secret': clientSecret,
      'code': code,
      if (redirectUri != null && redirectUri!.isNotEmpty)
        'redirect_uri': redirectUri!,
    });
  }

  @override
  Future<GoogleOAuthTokenResponse?> refreshAccessToken({
    required String clientId,
    required String refreshToken,
  }) {
    _log?.call(
      'Local OAuth exchange: refresh_token -> ${endpoint.host}${endpoint.path}',
    );
    return _exchange(<String, String>{
      'grant_type': 'refresh_token',
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
    });
  }

  Future<GoogleOAuthTokenResponse?> _exchange(Map<String, String> body) async {
    try {
      final response = await _client.post(
        endpoint,
        body: body,
        headers: <String, String>{'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        _log?.call(
          'Local OAuth exchange failed: HTTP ${response.statusCode} from ${endpoint.host}${endpoint.path}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _log?.call(
          'Local OAuth exchange failed: response was not a JSON object',
        );
        return null;
      }

      final accessToken = decoded['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        _log?.call(
          'Local OAuth exchange failed: access_token missing in response',
        );
        return null;
      }

      _log?.call(
        'Local OAuth exchange succeeded: access token received${decoded['refresh_token'] == null ? '' : ', refresh token present'}',
      );

      return GoogleOAuthTokenResponse(
        accessToken: accessToken,
        refreshToken: decoded['refresh_token'] as String?,
        tokenType: decoded['token_type'] as String?,
        expiresIn: decoded['expires_in'] is int
            ? decoded['expires_in'] as int
            : int.tryParse('${decoded['expires_in'] ?? ''}'),
        raw: decoded,
      );
    } catch (_) {
      _log?.call(
        'Local OAuth exchange failed: exception while contacting ${endpoint.host}${endpoint.path}',
      );
      return null;
    }
  }
}
