<?php
declare(strict_types=1);

// Initialize config first - all header logic now consolidated here
$config = loadConfig();

// Consolidate all security headers after config validation but before any output
applySecurityHeaders($config);

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
    respondError('method_not_allowed', 'POST only', 405);
}

$input = readInput();
$grantType = trim((string)($input['grant_type'] ?? ''));

if ($grantType !== 'authorization_code' && $grantType !== 'refresh_token') {
    respondError('unsupported_grant_type', 'grant_type must be authorization_code or refresh_token', 400);
}

$clientId = configValue($config, 'GOOGLE_CLIENT_ID');
$clientSecret = configValue($config, 'GOOGLE_CLIENT_SECRET');
$tokenEndpoint = configValue($config, 'GOOGLE_TOKEN_ENDPOINT') ?: 'https://oauth2.googleapis.com/token';
$redirectUri = configValue($config, 'GOOGLE_REDIRECT_URI');

if (!isAllowedTokenEndpoint($tokenEndpoint)) {
    respondError('invalid_token_endpoint', 'GOOGLE_TOKEN_ENDPOINT must point to a Google token endpoint', 500);
}

if ($clientId === '' || $clientSecret === '') {
    respondError('server_not_configured', 'Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET', 500);
}

$payload = [
    'client_id' => $clientId,
    'client_secret' => $clientSecret,
    'grant_type' => $grantType,
];

if ($grantType === 'authorization_code') {
    $code = trim((string)($input['code'] ?? ''));
    if ($code === '') {
        respondError('missing_code', 'code is required', 400);
    }

    $payload['code'] = $code;
    if ($redirectUri !== '') {
        $payload['redirect_uri'] = $redirectUri;
    }
} else {
    $refreshToken = trim((string)($input['refresh_token'] ?? ''));
    if ($refreshToken === '') {
        respondError('missing_refresh_token', 'refresh_token is required', 400);
    }

    $payload['refresh_token'] = $refreshToken;
}

$response = postForm($tokenEndpoint, $payload);
if ($response['status'] < 200 || $response['status'] >= 300) {
    http_response_code($response['status']);
    echo $response['body'];
    exit;
}

http_response_code(200);
echo $response['body'];


function readInput(): array
{
    $input = $_POST;
    if (!empty($input)) {
        return $input;
    }

    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function loadConfig(): array
{
    $configPath = __DIR__ . '/config.php';
    if (is_file($configPath)) {
        $config = require $configPath;
        return is_array($config) ? $config : [];
    }

    return [];
}

/**
 * Consolidate all security headers after config validation.
 * This ensures COOP/COEP headers are applied safely and CSP is present.
 */
function applySecurityHeaders(array $config): void
{
    // Apply COOP/COEP headers (always needed for modern web security)
    header('Cross-Origin-Opener-Policy: same-origin');
    header('Cross-Origin-Embedder-Policy: require-corp');
    header('Cross-Origin-Opener-Policy-Report-Only: same-origin');
    header('Cross-Origin-Embedder-Policy-Report-Only: require-corp');

    // Add Content-Security-Policy for defense in depth
    header('Content-Security-Policy: default-src \'self\'; script-src \'none\'');

    // CORS logic - only apply to browser requests with Origin header
    $requestOrigin = trim((string)($_SERVER['HTTP_ORIGIN'] ?? ''));
    
    if ($requestOrigin !== '') {
        $allowedOrigins = allowedOrigins($config);
        
        // Check if origin is in allowlist or wildcard is configured
        if (!in_array('*', $allowedOrigins, true) && !in_array($requestOrigin, $allowedOrigins, true)) {
            // Origin not allowed - don't send CORS headers (browser will block)
            return;
        }

        header('Vary: Origin');
        header('Access-Control-Allow-Origin: ' . (in_array('*', $allowedOrigins, true) ? '*' : $requestOrigin));
        
        // Add max-age to cache preflight responses (performance optimization)
        header('Access-Control-Max-Age: 86400');
    }

    // Always allow POST methods and required headers
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Origin');
}

function allowedOrigins(array $config): array
{
    $rawOrigins = configValue($config, 'GOOGLE_ALLOWED_ORIGINS');
    if ($rawOrigins === '') {
        return [];
    }

    $origins = array_filter(array_map('trim', explode(',', $rawOrigins)), static fn (string $origin): bool => $origin !== '');
    return array_values(array_unique($origins));
}

function configValue(array $config, string $name): string
{
    if (array_key_exists($name, $config)) {
        return trim((string)$config[$name]);
    }

    return envValue($name);
}

function envValue(string $name): string
{
    $value = getenv($name);
    return $value === false ? '' : trim((string)$value);
}

function isAllowedTokenEndpoint(string $url): bool
{
    $parts = parse_url($url);
    if (!is_array($parts)) {
        return false;
    }

    $scheme = strtolower((string)($parts['scheme'] ?? ''));
    $host = strtolower((string)($parts['host'] ?? ''));

    if ($scheme !== 'https' || $host === '') {
        return false;
    }

    return in_array($host, ['oauth2.googleapis.com', 'accounts.google.com', 'www.googleapis.com'], true);
}

function postForm(string $url, array $payload): array
{
    // Remove hardcoded timeout and make it configurable via env var if needed
    $timeout = getenv('GOOGLE_API_TIMEOUT') ?: 30;
    
    $context = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => "Content-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\n",
            'content' => http_build_query($payload),
            'ignore_errors' => true,
            'timeout' => (float)$timeout,
        ],
    ]);

    $body = file_get_contents($url, false, $context);
    if ($body === false) {
        return [
            'status' => 502,
            'body' => json_encode([
                'error' => 'upstream_request_failed',
                'error_description' => 'Unable to contact Google token endpoint',
            ], JSON_UNESCAPED_SLASHES),
        ];
    }

    $status = 200;
    if (isset($http_response_header) && is_array($http_response_header)) {
        foreach ($http_response_header as $header) {
            if (preg_match('#^HTTP/\S+\s(\d{3})#', $header, $matches) === 1) {
                $status = (int)$matches[1];
                break;
            }
        }
    }

    return [
        'status' => $status,
        'body' => $body,
    ];
}

function respondError(string $error, string $message, int $statusCode): void
{
    http_response_code($statusCode);
    echo json_encode([
        'error' => $error,
        'error_description' => $message,
    ], JSON_UNESCAPED_SLASHES);
    exit;
}
