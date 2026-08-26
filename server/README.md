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

## Deployment Checklist

Before deploying:

1. **Set environment variables** OR copy `config.example.php` to `config.php` and fill in values
2. **Configure allowed origins** for browser clients via `GOOGLE_ALLOWED_ORIGINS` (optional, omit for native-only)
3. **Verify token endpoint** points to a Google host (default: `https://oauth2.googleapis.com/token`)
4. **(Optional)** Set `GOOGLE_API_TIMEOUT` environment variable (default: 30 seconds)

## Local Testing

```bash
# Start server in background
php -S localhost:8000 server/index.php &

# Test with curl (from allowed origin):
curl -X POST http://localhost:8000/server/index.php \
  -H "Origin: https://your-app.example" \
  -F "grant_type=authorization_code" \
  -F "code=YOUR_AUTH_CODE"

# Verify response headers include COOP/COEP/CSP
curl -v http://localhost:8000/server/index.php \
  -H "Origin: https://your-app.example" | grep -i "^< "
```

## Security Notes

- **`config.php` is ignored by git** to protect your secrets. Never commit this file.
- **COOP/COEP headers** are applied unconditionally (required for modern web security).
- **CSP header** is included as a defense-in-depth measure.
- **Origin-specific CORS**: Only configured origins receive `Access-Control-Allow-Origin` headers. Native apps (no Origin header) work without restrictions.

## Troubleshooting

### 405 Method Not Allowed
Ensure you're using POST requests, not GET/PUT/DELETE.

### Missing Access-Control-Allow-Origin Header
- Verify your request includes an `Origin` header (browser adds this automatically)
- Check that the origin is in `GOOGLE_ALLOWED_ORIGINS` config (or use wildcard)
- Native apps without Origin header will never receive CORS headers but still work

### Token endpoint errors (502)
Check network connectivity to Google and verify your server has outbound HTTPS access.

## Request contract


- `grant_type=authorization_code`
- `code=...`

or:

- `grant_type=refresh_token`
- `refresh_token=...`

The server forwards the request to Google and returns Google’s JSON response. The Flutter client no longer needs to ship a Google client secret.