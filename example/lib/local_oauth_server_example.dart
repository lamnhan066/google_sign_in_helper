import 'package:google_sign_in_helper/google_sign_in_helper.dart';

Future<void> main() async {
  final helper = GoogleSignInHelper(
    clientId: 'YOUR_CLIENT_ID',
    oauthServer: LocalOAuthServer(
      clientId: 'YOUR_CLIENT_ID',
      clientSecret: 'YOUR_CLIENT_SECRET',
      redirectUri: 'https://your-domain.com/callback',
    ),
  );

  await helper.dispose();
}
