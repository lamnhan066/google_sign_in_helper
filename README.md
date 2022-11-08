# Google Sign In Helper

Make it easier for you to use google sign in on all platforms.

## Usage

**Configure the plguin:**

- Mobile: https://pub.dev/packages/google_sign_in
- Desktop: https://pub.dev/packages/google_sign_in_dartio

**Initialize the plugin:**

``` dart
final googleSignInHelper = GoogleSignInHelper();

void main() async {
     googleSignInHelper.initial(
        currentPlatform: DefaultFirebaseOptions.currentPlatform,
        
        // Add desktop id to this if you're using desktop
        desktopId: null,
     );
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
