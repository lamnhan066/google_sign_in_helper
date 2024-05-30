import 'package:flutter/widgets.dart';
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_web/web_only.dart' as web;

import 'stub.dart';

/// Renders a web-only SIGN IN button.
Widget buildSignInButton({String text = 'Sign in', HandleSignInFn? onPressed}) {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      text: web.GSIButtonText.signin,
    ),
  );
}
