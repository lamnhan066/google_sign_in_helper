# Google Sign In Helper

Make it easier for you to use google sign in on all platforms.

## How to Get Google OAuth Credentials

To use Google OAuth in your application, create OAuth 2.0 credentials
(Client ID and Client Secret) in the Google Cloud Console.

1. Go to the Google Cloud Console at https://console.cloud.google.com/apis/credentials and sign in with your Google account.
2. Set up the OAuth consent screen before creating credentials.
3. Select your project, or create a new one if you have not already created one for your app.
4. Open "OAuth consent screen" in the sidebar.
5. Choose "External" for user type, which is recommended for most cases.
6. Fill in the required information, including the app name and user support email.
7. Save and continue until the setup is complete.
8. Open "Credentials" in the sidebar.
9. Click "Create Credentials" and then "OAuth client ID".
10. Choose "Web application" as the application type.
11. Leave "Authorized JavaScript origins" empty if you do not need it.
12. Under "Authorized redirect URIs", add your needed urls.
13. Copy the Client ID and Client Secret after creation and use them in your app configuration.

## Usage

**Configure the plguin:**

- Mobile: https://pub.dev/packages/google_sign_in
- Desktop: https://pub.dev/packages/google_sign_in_dartio

**Initialize the plugin:**

``` dart
final googleSignInHelper = GoogleSignInHelper(
  clientId: 'YOUR_CLIENT_ID',
  oauthServerEndpoint: Uri.parse('https://your-domain.com/server/index.php'),
  debug: true,

  // Optional storage for refresh tokens used by signInSilently()
   authStorage: MyAuthStorage(),
);
```

Set `debug: true` to emit package logs through `lite_logger` while the helper initializes and runs sign-in flows.

Use the same Google OAuth `clientId` in the Flutter app and in the PHP server
configuration. The server exchanges tokens with Google using that ID and keeps
the `clientSecret` out of the Flutter binary.

`signIn()` and `signInLightweight()` still use the Google Sign-In SDK for the
interactive user session, but the long-lived refresh token is now requested
through the PHP backend at `oauthServerEndpoint`. That keeps the Google client
secret off the Flutter client.

`signInSilently()` uses the stored refresh token and the same backend endpoint
to mint a fresh access token without shipping a client secret in the app.

For local development, you can skip the PHP server entirely and use
`LocalOAuthServer`:

```dart
final googleSignInHelper = GoogleSignInHelper(
  clientId: 'YOUR_CLIENT_ID',
  oauthServer: LocalOAuthServer(
    clientId: 'YOUR_CLIENT_ID',
    clientSecret: 'YOUR_CLIENT_SECRET',
    redirectUri: 'https://your-domain.com/callback',
  ),
);
```

That mode sends the token exchange directly to Google, so it is convenient for
development but still keeps the secret in the app binary.

See [server/README.md](server/README.md) for the PHP configuration and request
contract.

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
