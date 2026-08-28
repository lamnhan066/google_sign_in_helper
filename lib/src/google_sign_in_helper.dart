import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:google_sign_in_dartio/google_sign_in_dartio.dart';
import 'package:google_sign_in_helper/src/sign_in_button.dart';
import 'package:lite_logger/lite_logger.dart';

import 'auth_storage.dart';
import 'google_auth_client.dart';
import 'google_oauth_server.dart';
import 'google_user.dart';

class GoogleSignInScope {
  GoogleSignInScope._();

  /// See profile
  static const profile = 'https://www.googleapis.com/auth/userinfo.profile';

  /// See email
  static const email = 'https://www.googleapis.com/auth/userinfo.email';

  /// See, edit, create, and delete all of your Google Drive files
  static const driveScope = 'https://www.googleapis.com/auth/drive';

  /// See, create, and delete its own configuration data in your Google Drive
  static const driveAppdataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  /// See, edit, create, and delete only the specific Google Drive files you use
  /// with this app
  static const driveFileScope = 'https://www.googleapis.com/auth/drive.file';

  /// View and manage metadata of files in your Google Drive
  static const driveMetadataScope =
      'https://www.googleapis.com/auth/drive.metadata';

  /// See information about your Google Drive files
  static const driveMetadataReadonlyScope =
      'https://www.googleapis.com/auth/drive.metadata.readonly';

  /// View the photos, videos and albums in your Google Photos
  static const drivePhotosReadonlyScope =
      'https://www.googleapis.com/auth/drive.photos.readonly';

  /// See and download all your Google Drive files
  static const driveReadonlyScope =
      'https://www.googleapis.com/auth/drive.readonly';

  /// Modify your Google Apps Script scripts' behavior
  static const driveScriptsScope =
      'https://www.googleapis.com/auth/drive.scripts';
}

class GoogleSignInHelper {
  /// Get GoogleSignIn instance
  late GoogleSignIn googleSignIn;
  late final LiteLogger _logger;

  final String clientId;
  final Uri? oauthServerEndpoint;
  final bool debug;

  GoogleSignInAccount? _currentAccount;
  late Future<void> _initializeFuture;
  final AuthStorage? authStorage;
  late final OAuthServer _oauthServer;
  late StreamSubscription? _authEventSubscription;
  final AccessTokenCache _accessTokenCache = AccessTokenCache();

  /// Get headers from the google sign in
  Map<String, String> headers = {};

  /// Get [GoogleSignInAuthentication] information
  GoogleSignInAuthentication? authInfo;

  /// Get [GoogleUser] information
  GoogleUser? user;

  /// Get [GoogleAuthClient]
  GoogleAuthClient? client;

  final List<String> scopes;

  /// Volatile flag for tracking pending auth operations (concurrency guard)
  bool _authInProgress = false;

  /// Change when user sign in or sign out
  Stream<bool> get onSignChanged => _onSignedChangeController.stream;
  final StreamController<bool> _onSignedChangeController =
      StreamController.broadcast();

  /// Get current signed in state
  bool get isSigned => user != null;

  /// Create a instance:
  /// ``` dart
  /// void main() async {
  ///     final signInHelper = GoogleSignInHelper(
  ///       clientId: 'YOUR_CLIENT_ID',
  ///     );
  /// }
  /// ```
  ///
  /// Default scopes are: profile, email
  GoogleSignInHelper({
    required this.clientId,
    this.oauthServerEndpoint,
    this.scopes = const [GoogleSignInScope.profile, GoogleSignInScope.email],
    this.authStorage,
    this.debug = false,
    OAuthServer? oauthServer,
  }) {
    _logger = LiteLogger(
      name: 'GoogleSignInHelper',
      enabled: debug,
      minLevel: LogLevel.debug,
      usePrint: kIsWeb,
    );

    if (oauthServer != null) {
      _oauthServer = oauthServer;
    } else {
      final endpoint = oauthServerEndpoint;
      if (endpoint == null) {
        throw ArgumentError(
          'oauthServerEndpoint is required when oauthServer is not provided',
        );
      }

      _oauthServer = GoogleOAuthServer(
        endpoint,
        log: debug ? (message) => _logger.debug(() => message) : null,
      );
    }

    googleSignIn = GoogleSignIn.instance;
    _initializeFuture = googleSignIn
        .initialize(
          clientId: kIsWeb ? clientId : null,
          serverClientId: kIsWeb ? null : clientId,
        )
        .whenComplete(() {
          _logger.debug(() => 'Google Sign In initialized and ready');
        })
        .then((_) {
          _authEventSubscription = googleSignIn.authenticationEvents.listen(
            _handleAuthenticationEvent,
            onError: _handleAuthenticationError,
          );
        });
  }

  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    // Only check on web (for the sign in button)
    if (kIsWeb) {
      _logger.debug(() => 'Handle authentication events on the Web');
      final GoogleSignInAccount? account = switch (event) {
        GoogleSignInAuthenticationEventSignIn() => event.user,
        GoogleSignInAuthenticationEventSignOut() => null,
      };

      await _checkAndStoreToken(account);
    }
  }

  Future<void> _handleAuthenticationError(Object e) async {
    if (kIsWeb) {
      _logger.debug(() => 'Handle authentication error on the Web');
      await _clearRefreshToken();
    }
  }

  /// Render a sign in button.
  Widget signInButton({String text = 'Sign in'}) =>
      buildSignInButton(text: text, onPressed: signIn);

  /// Sign in.
  ///
  /// Not supported on the Web anymore. Use `signInButton()` widget instead.
  Future<bool> signIn() async {
    await _initializeFuture;
    _logger.debug(() => 'Starting interactive sign in');

    // Guard against concurrent auth operations
    if (_authInProgress) {
      _logger.debug(
        () => 'Skipping sign in: auth operation already in progress',
      );
      return false;
    }
    _authInProgress = true;

    try {
      if (!googleSignIn.supportsAuthenticate()) {
        _logger.debug(
          () => 'Interactive sign in not supported on this platform',
        );
        final result = await _check(false, account: null);
        _authInProgress = false;
        return result;
      }

      try {
        await googleSignIn.signOut();
      } catch (e) {
        _logger.debug(() => 'Error in signIn signOut cleanup: $e');
      }

      final account = await googleSignIn.authenticate(scopeHint: scopes);

      final result = await _checkAndStoreToken(account);
      _logger.debug(() => 'Interactive sign in completed: $result');
      return result;
    } finally {
      // Cleanup flag regardless of outcome
      _authInProgress = false;
    }
  }

  Future<bool> _checkAndStoreToken(GoogleSignInAccount? account) async {
    if (account == null) {
      await _clearRefreshToken();
      return false;
    }

    final isSignedIn = await _check(true, account: account);
    if (isSignedIn) {
      await _storeRefreshToken(account);
    } else {
      await _clearRefreshToken();
    }
    return isSignedIn;
  }

  /// Sign in lightweight.
  ///
  /// Attempts a lightweight (minimal UI) authentication using
  /// [GoogleSignIn.attemptLightweightAuthentication]. This may show a small
  /// system-level UI prompt and requires an active app foreground context.
  /// Use this as a fast path on app resume before falling back to [signIn].
  Future<bool> signInLightweight() async {
    await _initializeFuture;
    _logger.debug(() => 'Starting lightweight sign in');

    // Guard against concurrent auth operations
    if (_authInProgress) {
      _logger.debug(
        () =>
            'Skipping lightweight sign in: auth operation already in progress',
      );
      return false;
    }
    _authInProgress = true;

    try {
      final Future<GoogleSignInAccount?>? attempt = googleSignIn
          .attemptLightweightAuthentication();
      if (attempt == null) {
        _logger.debug(
          () => 'Lightweight sign in not supported on this platform',
        );
        return await _check(false, account: null);
      }

      final account = await attempt;
      return await _check(account != null, account: account);
    } finally {
      // Cleanup flag regardless of outcome
      _authInProgress = false;
    }
  }

  /// Sign in silently using a stored refresh token.
  ///
  /// Exchanges the stored OAuth2 refresh token through the PHP backend for a
  /// fresh access token. No Google client secret is shipped in the Flutter
  /// binary, so the backend owns the secret-bearing token exchange.
  ///
  /// Requirements:
  /// - The user must have signed in at least once via [signIn], which must
  ///   have stored a refresh token via [AuthStorage.save].
  ///
  /// Returns `true` and populates [headers] / [client] on success so that
  /// Drive API calls can proceed immediately after awaiting this method.
  Future<bool> signInSilently() async {
    // Guard against concurrent auth operations during token refresh flow
    if (_authInProgress) {
      _logger.debug(
        () => 'Skipping silent sign in: auth operation already in progress',
      );
      return false;
    }

    if (_accessTokenCache.hasFreshAccessToken) {
      final remainingLifetime = _accessTokenCache.remainingLifetime;
      _logger.debug(
        () =>
            'Silent sign in using cached access token${remainingLifetime == null ? '' : ' (${remainingLifetime.inSeconds}s remaining)'}',
      );
      return await _applyAccessToken(
        _accessTokenCache.accessToken!,
        skipUserInfoLookup: user != null && client != null,
      );
    }

    final refreshToken = await authStorage?.read();
    if (refreshToken == null) {
      _logger.debug(() => 'Silent sign in skipped: no refresh token available');
      return await _check(false, account: null);
    }

    _logger.debug(() => 'Starting silent sign in');
    _authInProgress = true;

    try {
      final response = await _oauthServer.refreshAccessToken(
        clientId: clientId,
        refreshToken: refreshToken,
      );
      if (response == null) {
        _logger.debug(
          () => 'Silent sign in failed: backend token exchange failed',
        );
        return await _check(false, account: null);
      }

      _logger.debug(
        () =>
            'Silent sign in received access token${response.refreshToken == null ? '' : ' and refresh token'}',
      );

      _accessTokenCache.store(response);

      return await _applyAccessToken(response.accessToken);
    } catch (_) {
      _logger.debug(() => 'Silent sign in failed with an exception');
      return await _check(false, account: null);
    } finally {
      // Cleanup flag after token refresh attempt
      _authInProgress = false;
    }
  }

  Future<void> _storeRefreshToken(GoogleSignInAccount account) async {
    final storage = authStorage;
    if (storage == null) {
      _logger.debug(
        () => 'Skipping refresh token storage: no AuthStorage configured',
      );
      return;
    }

    try {
      final serverAuth = await account.authorizationClient.authorizeServer(
        scopes,
      );
      final serverAuthCode = serverAuth?.serverAuthCode;
      if (serverAuthCode == null) {
        _logger.debug(
          () => 'Skipping refresh token storage: server auth code missing',
        );
        return;
      }

      final response = await _oauthServer.exchangeAuthorizationCode(
        clientId: clientId,
        code: serverAuthCode,
      );

      if (response == null) {
        _logger.debug(() => 'Refresh token exchange failed on backend');
        return;
      }

      _accessTokenCache.store(response);

      _logger.debug(
        () =>
            'Refresh token exchange completed${response.refreshToken == null ? ' without' : ' with'} refresh token',
      );
      final refreshToken = response.refreshToken;
      if (refreshToken == null) {
        _logger.debug(
          () => 'Refresh token exchange completed without a refresh token',
        );
        return;
      }

      await storage.save(refreshToken);
      _logger.debug(() => 'Refresh token saved');
    } catch (e) {
      _logger.debug(() => 'Error storing refresh token: $e');
    }
  }

  Future<void> _clearRefreshToken() async {
    await authStorage?.clear();
  }

  /// Sign out.
  Future<void> signOut() async {
    await _initializeFuture;
    _logger.debug(() => 'Signing out');

    // Cancel any pending auth operation during sign-out
    if (_authInProgress) {
      _logger.debug(() => 'Aborting in-flight auth operation due to sign-out');
    }

    try {
      await googleSignIn.signOut();
      await _check(false, account: null);
      await _clearRefreshToken();
    } finally {
      // Ensure flag is cleared even if sign-out fails partway through
      _authInProgress = false;
    }
  }

  /// Disconnect.
  Future<void> disconnect() async {
    await _initializeFuture;
    _logger.debug(() => 'Disconnecting Google Sign In');
    await googleSignIn.disconnect();
    await _check(false, account: null);
    await _clearRefreshToken();
  }

  /// Release backend resources owned by this helper.
  Future<void> dispose() async {
    _logger.debug(() => 'Disposing Google Sign In Helper');
    _authEventSubscription?.cancel();
    await _oauthServer.dispose();
  }

  /// Can access scopes
  Future<bool> canAccessScopes(List<String> scopes) async {
    await _initializeFuture;

    final GoogleSignInAccount? account = _currentAccount;
    if (account == null) {
      _logger.debug(() => 'Cannot check scopes: no signed in account');
      return false;
    }

    final GoogleSignInClientAuthorization? authorization = await account
        .authorizationClient
        .authorizationForScopes(scopes);
    _logger.debug(
      () => 'Scope access check completed: ${authorization != null}',
    );
    return authorization != null;
  }

  /// Request additional scopes
  Future<bool> requestScopes(List<String> scopes) async {
    await _initializeFuture;

    final GoogleSignInAccount? account = _currentAccount;
    if (account == null) {
      _logger.debug(() => 'Cannot request scopes: no signed in account');
      return false;
    }

    try {
      await account.authorizationClient.authorizeScopes(scopes);
      _logger.debug(() => 'Requested additional scopes successfully');
      return true;
    } on GoogleSignInException {
      _logger.debug(() => 'Requesting additional scopes failed');
      return false;
    }
  }

  Future<bool> _check(bool isAuthorized, {GoogleSignInAccount? account}) async {
    if (isAuthorized && account == null) {
      return _check(false, account: null);
    }

    if (isAuthorized) {
      await _doIfSignedIn(account!);
    } else {
      _doIfSignOut();
    }

    _onSignedChangeController.sink.add(isAuthorized);
    _logger.debug(
      () =>
          isAuthorized ? 'Signed in state updated' : 'Signed out state updated',
    );

    return isAuthorized;
  }

  Future<void> _doIfSignedIn(GoogleSignInAccount account) async {
    _currentAccount = account;
    authInfo = account.authentication;

    headers =
        await account.authorizationClient.authorizationHeaders(
          scopes,
          promptIfNecessary: true,
        ) ??
        <String, String>{};

    client = GoogleAuthClient(headers);
    user = await _getUserInfo();
    _logger.debug(
      () =>
          'Signed in${user?.email.isNotEmpty == true ? ' as ${user!.email}' : ''}',
    );
  }

  void _doIfSignOut() {
    _currentAccount = null;
    headers = {};
    authInfo = null;
    client = null;
    user = null;
    _accessTokenCache.clear();
    _logger.debug(() => 'Local sign in state cleared');
  }

  Future<bool> _applyAccessToken(
    String accessToken, {
    bool skipUserInfoLookup = false,
  }) async {
    headers = {'Authorization': 'Bearer $accessToken', 'X-Goog-AuthUser': '0'};
    client = GoogleAuthClient(headers);

    if (skipUserInfoLookup && user != null) {
      _onSignedChangeController.sink.add(true);
      _logger.debug(() => 'Silent sign in completed using cached user state');
      return true;
    }

    user = await _getUserInfo();

    // user will be null if the token was rejected by the userinfo endpoint.
    if (user == null) {
      _logger.debug(
        () => 'Silent sign in failed: user info request returned no user',
      );
      _accessTokenCache.clear();
      return _check(false, account: null);
    }

    _onSignedChangeController.sink.add(true);
    _logger.debug(() => 'Silent sign in completed: ${user?.email}');
    return true;
  }

  Future<GoogleUser?> _getUserInfo() async {
    if (client == null) return null;

    final response = await client!.get(
      Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
    );

    return GoogleUser.fromJson(response.body);
  }
}
