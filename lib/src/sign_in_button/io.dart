import 'package:flutter/material.dart';

import 'stub.dart';

/// Renders a SIGN IN button that calls `handleSignIn` onclick.
Widget buildSignInButton({String text = 'Sign in', HandleSignInFn? onPressed}) {
  return ElevatedButton(
    onPressed: onPressed,
    child: Text(text),
  );
}
