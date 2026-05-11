# PHP OAuth Server

This folder contains a minimal PHP token proxy for `google_sign_in_helper`.

## Environment

Set these variables on the server:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URI` optional, only needed if your Google OAuth client requires it for the auth-code exchange
- `GOOGLE_TOKEN_ENDPOINT` optional, defaults to `https://oauth2.googleapis.com/token`

The `GOOGLE_CLIENT_ID` value must match the `clientId` passed to
`GoogleSignInHelper` in the Flutter app. Only the server keeps
`GOOGLE_CLIENT_SECRET`.

You can store these values either as environment variables or in a local
`config.php` file in this folder. For the file-based setup, copy
`config.example.php` to `config.php` and fill in the values. The repository
ignores `config.php` so secrets stay out of version control.

## Request contract

`POST /server/index.php`

Form fields:

- `grant_type=authorization_code`
- `code=...`

or:

- `grant_type=refresh_token`
- `refresh_token=...`

The server forwards the request to Google and returns Google’s JSON response. The Flutter client no longer needs to ship a Google client secret.