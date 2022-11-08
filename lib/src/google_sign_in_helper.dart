import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_dartio/google_sign_in_dartio.dart';
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
  GoogleSignIn? googleSignIn;

  /// Get headers from the google sign in
  Map<String, String> headers = {};

  /// Get [GoogleSignInAuthentication] information
  GoogleSignInAuthentication? authInfo;

  /// Get [GoogleUser] information
  GoogleUser? user;

  /// Get [GoogleAuthClient]
  GoogleAuthClient? client;

  /// Change when user sign in or sign out
  Stream<bool> get onSignChanged => _onSignedChangeController.stream;
  final StreamController<bool> _onSignedChangeController =
      StreamController.broadcast();

  /// Get current signed in state
  bool get isSigned => googleSignIn?.currentUser != null;

  /// Initialize this plugin in main():
  /// ``` dart
  /// void main() async {
  ///     GoogleSignInHelper.instance.initialize(currentPlatform: DefaultFirebaseOptions.currentPlatform);
  /// }
  /// ```
  ///
  /// Default scopes are: profile, email
  void initial({
    required FirebaseOptions currentPlatform,
    List<String> scopes = const [
      GoogleSignInScope.profile,
      GoogleSignInScope.email,
    ],
    String? desktopId,
  }) async {
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

  /// Sign in
  Future<bool> signIn() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    final result = await googleSignIn!.signIn();

    if (result != null) await _doIfSignedIn();

    _onSignedChangeController.sink.add(result != null);
    return result != null;
  }

  /// Sign in silently
  Future<bool> signInSilently() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    final result = await googleSignIn!.signInSilently();

    if (result != null) await _doIfSignedIn();

    _onSignedChangeController.sink.add(result != null);
    return result != null;
  }

  /// Sign out
  Future<void> signOut() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    await googleSignIn!.signOut();
    _doIfSignOut();
    _onSignedChangeController.sink.add(false);
  }

  /// Disconnect
  Future<void> disconnect() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    await googleSignIn!.disconnect();
    _doIfSignOut();
    _onSignedChangeController.sink.add(false);
  }

  Future<void> _doIfSignedIn() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    headers = await googleSignIn!.currentUser!.authHeaders;
    authInfo = await googleSignIn!.currentUser!.authentication;

    client = GoogleAuthClient(headers);
    user = await _getUserInfo();
  }

  void _doIfSignOut() async {
    googleSignIn = null;
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
