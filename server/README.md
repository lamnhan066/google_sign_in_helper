# PHP OAuth Server

This folder contains a minimal PHP token proxy for `google_sign_in_helper`.

## Environment

Set these variables on the server:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URI` optional, only needed if your Google OAuth client requires it for the auth-code exchange
- `GOOGLE_TOKEN_ENDPOINT` optional, defaults to `https://oauth2.googleapis.com/token`
- `GOOGLE_ALLOWED_ORIGINS` optional, comma-separated list of browser origins allowed to call this endpoint

The `GOOGLE_CLIENT_ID` value must match the `clientId` passed to
`GoogleSignInHelper` in the Flutter app. Only the server keeps
`GOOGLE_CLIENT_SECRET`.

You can store these values either as environment variables or in a local
`config.php` file in this folder. For the file-based setup, copy
`config.example.php` to `config.php` and fill in the values. The repository
ignores `config.php` so secrets stay out of version control.

For browser clients, set `GOOGLE_ALLOWED_ORIGINS` to the exact origins you
trust, such as `http://localhost:8080` during development and your production
app origin in production. If the origin is not listed, the server will not
emit `Access-Control-Allow-Origin`.

If your client is mobile or another native app, CORS does not apply in the
same way because the request is not enforced by a browser. In that case, you
do not need to configure `GOOGLE_ALLOWED_ORIGINS` unless you also serve the
same endpoint to a web client.

The server also rejects any `GOOGLE_TOKEN_ENDPOINT` that does not point to a
Google token host. Keep it on the default Google endpoint unless you have a
specific Google-hosted alternative.

## Request contract

`POST /server/index.php`

Form fields:

- `grant_type=authorization_code`
- `code=...`

or:

- `grant_type=refresh_token`
- `refresh_token=...`

The server forwards the request to Google and returns Google’s JSON response. The Flutter client no longer needs to ship a Google client secret.