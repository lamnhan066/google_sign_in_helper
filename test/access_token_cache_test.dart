import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_helper/src/google_oauth_server.dart';

void main() {
  test('AccessTokenCache stays fresh until the expiry skew elapses', () {
    var now = DateTime.utc(2026, 5, 11, 12);
    final cache = AccessTokenCache(now: () => now);

    cache.store(
      const GoogleOAuthTokenResponse(
        accessToken: 'access-token',
        expiresIn: 60,
      ),
    );

    expect(cache.accessToken, 'access-token');
    expect(cache.hasFreshAccessToken, isTrue);

    now = now.add(const Duration(seconds: 29));
    expect(cache.hasFreshAccessToken, isTrue);

    now = now.add(const Duration(seconds: 2));
    expect(cache.hasFreshAccessToken, isFalse);
  });

  test('AccessTokenCache clears when expiresIn is missing', () {
    var now = DateTime.utc(2026, 5, 11, 12);
    final cache = AccessTokenCache(now: () => now);

    cache.store(const GoogleOAuthTokenResponse(accessToken: 'access-token'));

    expect(cache.accessToken, isNull);
    expect(cache.hasFreshAccessToken, isFalse);
  });
}
