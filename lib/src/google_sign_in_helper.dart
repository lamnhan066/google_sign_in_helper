import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_dartio/google_sign_in_dartio.dart';
import 'package:universal_platform/universal_platform.dart';

import 'google_auth_client.dart';
import 'google_user.dart';

class GoogleSignInHelper {
  static GoogleSignIn? googleSignIn;

  static Map<String, String> headers = {};
  static late GoogleSignInAuthentication authInfo;
  static late GoogleUser user;
  static late GoogleAuthClient client;

  static Stream<bool> get onSignChanged => _onSignedChangeController.stream;
  static final StreamController<bool> _onSignedChangeController =
      StreamController.broadcast();
  static bool get isSigned => googleSignIn?.currentUser != null;

  static const _driveAppdataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  /// Initialize this plugin in main():
  /// ``` dart
  /// void main() async {
  ///     await GoogleSignInHelper.initialize(currentPlatform: DefaultFirebaseOptions.currentPlatform);
  /// }
  /// ```
  static Future<void> initialize({
    required FirebaseOptions currentPlatform,
    List<String> scopes = const [_driveAppdataScope, 'profile', 'email'],
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
            : currentPlatform.androidClientId,
        scopes: scopes,
      );
    }
  }

  static Future<bool> signIn() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    final result = await googleSignIn!.signIn();

    if (result != null) await _doIfSignedIn();

    _onSignedChangeController.sink.add(result != null);
    return result != null;
  }

  static Future<bool> signInSilently() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    final result = await googleSignIn!.signInSilently();

    if (result != null) await _doIfSignedIn();

    _onSignedChangeController.sink.add(result != null);
    return result != null;
  }

  static Future<void> signOut() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    await googleSignIn!.signOut();
  }

  static Future<void> disconnect() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    await googleSignIn!.disconnect();
  }

  static Future<void> _doIfSignedIn() async {
    assert(googleSignIn != null, 'You have to `initialize` the plugin first!');

    headers = await googleSignIn!.currentUser!.authHeaders;
    authInfo = await googleSignIn!.currentUser!.authentication;

    client = GoogleAuthClient(headers);
    user = await getUserInfo();
  }

  static Future getUserInfo() async {
    final response = await client
        .get(Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'));

    return GoogleUser.fromJson(response.body);
  }
}
