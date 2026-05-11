import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_helper/src/google_oauth_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('exchangeAuthorizationCode posts the auth code contract', () async {
    final server = GoogleOAuthServer(
      Uri.parse('https://example.com/server/index.php'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://example.com/server/index.php');
        expect(request.bodyFields['grant_type'], 'authorization_code');
        expect(request.bodyFields['client_id'], 'client-id');
        expect(request.bodyFields['code'], 'auth-code');

        return http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final response = await server.exchangeAuthorizationCode(
      clientId: 'client-id',
      code: 'auth-code',
    );

    expect(response, isNotNull);
    expect(response!.accessToken, 'access-token');
    expect(response.refreshToken, 'refresh-token');
    expect(response.tokenType, 'Bearer');
    expect(response.expiresIn, 3600);
  });

  test('refreshAccessToken posts the refresh token contract', () async {
    final server = GoogleOAuthServer(
      Uri.parse('https://example.com/server/index.php'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.bodyFields['grant_type'], 'refresh_token');
        expect(request.bodyFields['client_id'], 'client-id');
        expect(request.bodyFields['refresh_token'], 'refresh-token');

        return http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'fresh-access-token',
            'expires_in': '3600',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final response = await server.refreshAccessToken(
      clientId: 'client-id',
      refreshToken: 'refresh-token',
    );

    expect(response, isNotNull);
    expect(response!.accessToken, 'fresh-access-token');
    expect(response.refreshToken, isNull);
    expect(response.expiresIn, 3600);
  });
}
