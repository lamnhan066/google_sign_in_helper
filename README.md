# Google Sign In Helper

Make it easier for you to use google sign in on all platforms.

## Usage

**Configure the plguin:**

- Mobile: https://pub.dev/packages/google_sign_in
- Desktop: https://pub.dev/packages/google_sign_in_dartio

**Initialize the plugin:**

``` dart
final googleSignInHelper = GoogleSignInHelper(
  clientId: 'YOUR_CLIENT_ID',
  clientSecret: 'YOUR_CLIENT_SECRET',
  redirectUri: 'YOUR_REDIRECT_URI',
  debug: true,

  // Optional storage for refresh tokens used by signInSilently()
   authStorage: MyAuthStorage(),
);
```

Set `debug: true` to emit package logs through `lite_logger` while the helper initializes and runs sign-in flows.

On mobile and desktop, `signIn()` and `signInLightweight()` can exchange the
server auth code for a refresh token and save it through `AuthStorage`. On Web,
the plugin can still use a stored refresh token for `signInSilently()`, but the
client-side web flow does not mint a refresh token itself.

`redirectUri` must exactly match the redirect URI configured for the OAuth
client that is used to exchange the authorization code for refresh tokens.

``` dart
class MyAuthStorage implements AuthStorage {
  @override
  Future<void> save(String token) async {
    // persist token
  }

  @override
  Future<String?> read() async {
    // load token
    return null;
  }
}
```

**Sign in:**

``` dart
bool result = await googleSignInHelper.signIn();
```

**Sign in silently:**

``` dart
bool result = await googleSignInHelper.signInSilently();
```

**Sign out:**

``` dart
await googleSignInHelper.signOut();
```

**Disconnect:**

``` dart
await googleSignInHelper.disconnect();
```

**Values that you can get after signed in:**

``` dart
/// Get [GoogleSignIn] instance
GoogleSignIn? googleSignInHelper.googleSignIn;

/// Get headers from the google sign in
Map<String, String> googleSignInHelper.headers;

/// Get [GoogleSignInAuthentication] information
GoogleSignInAuthentication? googleSignInHelper.authInfo;

/// Get [GoogleUser] information
GoogleUser? googleSignInHelper.user;

/// Get [GoogleAuthClient]
GoogleAuthClient? googleSignInHelper.client;

/// Change when user sign in or sign out
Stream<bool> googleSignInHelper.onSignChanged;

/// Get current signed in state
bool googleSignInHelper.isSigned;
```
