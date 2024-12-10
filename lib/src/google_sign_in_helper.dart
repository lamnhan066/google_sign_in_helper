import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_dartio/google_sign_in_dartio.dart';
import 'package:google_sign_in_helper/src/sign_in_button.dart';
import 'package:universal_platform/universal_platform.dart';

import 'google_auth_client.dart';
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

  /// Get headers from the google sign in
  Map<String, String> headers = {};

  /// Get [GoogleSignInAuthentication] information
  GoogleSignInAuthentication? authInfo;

  /// Get [GoogleUser] information
  GoogleUser? user;

  /// Get [GoogleAuthClient]
  GoogleAuthClient? client;

  final List<String> scopes;

  /// Change when user sign in or sign out
  Stream<bool> get onSignChanged => _onSignedChangeController.stream;
  final StreamController<bool> _onSignedChangeController =
      StreamController.broadcast();

  /// Get current signed in state
  bool get isSigned => user != null;

  /// Create a instance:
  /// ``` dart
  /// void main() async {
  ///     final signInHelper = GoogleSignInHelper(currentPlatform: DefaultFirebaseOptions.currentPlatform);
  /// }
  /// ```
  ///
  /// Default scopes are: profile, email
  GoogleSignInHelper({
    required FirebaseOptions currentPlatform,
    this.scopes = const [
      GoogleSignInScope.profile,
      GoogleSignInScope.email,
    ],
    String? desktopId,
  }) {
    if (UniversalPlatform.isDesktop && desktopId != null) {
      GoogleSignInDart.register(
        clientId: desktopId,
      );
      googleSignIn = GoogleSignIn(
        scopes: scopes,
      );
    } else {
      googleSignIn = GoogleSignIn(
        clientId: UniversalPlatform.isIOS || UniversalPlatform.isMacOS
            ? currentPlatform.iosClientId
            : UniversalPlatform.isAndroid
                ? currentPlatform.androidClientId
                : null,
        scopes: scopes,
      );
    }
  }

  /// Render a sign in button.
  Widget signInButton({String text = 'Sign in'}) => buildSignInButton(
        text: text,
        onPressed: signIn,
      );

  /// Sign in.
  ///
  /// Not supported on the Web anymore. Use `signInButton()` widget instead.
  Future<bool> signIn() async {
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    final account = await googleSignIn.signIn();
    return _check(account != null);
  }

  /// Sign in silently.
  Future<bool> signInSilently() async {
    final account = await googleSignIn.signInSilently();
    return _check(account != null);
  }

  /// Sign out.
  Future<void> signOut() async {
    await googleSignIn.signOut();
    await _check(false);
  }

  /// Disconnect.
  Future<void> disconnect() async {
    await googleSignIn.disconnect();
    await _check(false);
  }

  /// Can access scopes
  Future<bool> canAccessScopes(List<String> scopes) {
    return googleSignIn.canAccessScopes(scopes);
  }

  /// Request additional scopes
  Future<bool> requestScopes(List<String> scopes) {
    return googleSignIn.requestScopes(scopes);
  }

  Future<bool> _check(bool isAuthorized) async {
    if (kIsWeb && isAuthorized) {
      isAuthorized = await requestScopes(scopes);
    }

    if (isAuthorized) {
      await _doIfSignedIn();
    } else {
      _doIfSignOut();
    }

    _onSignedChangeController.sink.add(isAuthorized);

    return isAuthorized;
  }

  Future<void> _doIfSignedIn() async {
    headers = await googleSignIn.currentUser!.authHeaders;
    authInfo = await googleSignIn.currentUser!.authentication;

    client = GoogleAuthClient(headers);
    user = await _getUserInfo();
  }

  void _doIfSignOut() async {
    headers = {};
    authInfo = null;
    client = null;
    user = null;
  }

  Future<GoogleUser?> _getUserInfo() async {
    if (client == null) return null;

    final response = await client!
        .get(Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'));

    return GoogleUser.fromJson(response.body);
  }
}
