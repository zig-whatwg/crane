//! Libcurl Error Code Mapping
//!
//! Maps libcurl CURLcode values to WHATWG Fetch NetworkError types.
//! Ensures spec-compliant error reporting for network failures.
//!
//! Spec: https://fetch.spec.whatwg.org/#concept-network-error
//!
//! Error categories follow the WHATWG Fetch specification's network
//! error types for consistent error handling across the Fetch implementation.

const std = @import("std");
const curl = @import("curl_ffi.zig");
const backend = @import("backend.zig");

pub const NetworkError = backend.NetworkError;

/// Map a libcurl error code to a NetworkError.
///
/// This mapping follows the WHATWG Fetch spec's network error categories:
/// - DNS resolution failures
/// - Connection failures (refused, timeout, reset)
/// - TLS/SSL failures (handshake, certificate)
/// - Protocol errors
/// - Abort
///
/// Error Mapping Table:
/// | Libcurl Error                  | NetworkError        | Context                |
/// |--------------------------------|---------------------|------------------------|
/// | CURLE_COULDNT_RESOLVE_HOST     | DnsResolutionFailed | DNS lookup failed      |
/// | CURLE_COULDNT_RESOLVE_PROXY    | DnsResolutionFailed | Proxy DNS failed       |
/// | CURLE_COULDNT_CONNECT          | ConnectionRefused   | TCP connection failed  |
/// | CURLE_OPERATION_TIMEDOUT       | RequestTimeout      | Overall timeout        |
/// | CURLE_SSL_CONNECT_ERROR        | SslHandshakeFailed  | TLS handshake failed   |
/// | CURLE_SSL_CERTPROBLEM          | SslCertificateError | Certificate issue      |
/// | CURLE_PEER_FAILED_VERIFICATION | SslCertificateError | Cert verification fail |
/// | CURLE_TOO_MANY_REDIRECTS       | TooManyRedirects    | Redirect limit         |
/// | CURLE_URL_MALFORMAT            | InvalidUrl          | Bad URL                |
/// | CURLE_ABORTED_BY_CALLBACK      | Aborted             | User abort             |
/// | CURLE_RECV_ERROR               | ConnectionReset     | Receive failed         |
/// | CURLE_OUT_OF_MEMORY            | OutOfMemory         | Allocation failed      |
/// | (others)                       | Unknown             | Catch-all              |
pub fn mapCurlError(code: curl.CURLcode) NetworkError {
    return switch (code) {
        // Success - should not be called with CURLE_OK
        curl.CURLE_OK => unreachable,

        // DNS Resolution Failures
        // Spec: "DNS error" in network error creation
        curl.CURLE_COULDNT_RESOLVE_PROXY,
        curl.CURLE_COULDNT_RESOLVE_HOST,
        => .DnsResolutionFailed,

        // Connection Refused
        // Spec: Connection error during TCP establishment
        curl.CURLE_COULDNT_CONNECT,
        => .ConnectionRefused,

        // Timeout
        // Spec: "timed out" in network error
        curl.CURLE_OPERATION_TIMEDOUT,
        => .RequestTimeout,

        // TLS Handshake Failures
        // Spec: "TLS negotiation" error
        curl.CURLE_SSL_CONNECT_ERROR,
        curl.CURLE_SSL_ENGINE_NOTFOUND,
        curl.CURLE_SSL_ENGINE_SETFAILED,
        => .SslHandshakeFailed,

        // TLS Certificate Errors
        // Spec: "bad TLS certificate" error
        curl.CURLE_SSL_CERTPROBLEM,
        curl.CURLE_SSL_CACERT,
        curl.CURLE_PEER_FAILED_VERIFICATION,
        curl.CURLE_SSL_ISSUER_ERROR,
        curl.CURLE_SSL_PINNEDPUBKEYNOTMATCH,
        => .SslCertificateError,

        // Redirect Limit
        // Spec: Handled by Fetch algorithm, but curl can hit this too
        curl.CURLE_TOO_MANY_REDIRECTS,
        => .TooManyRedirects,

        // Invalid URL
        // Spec: URL parsing failure
        curl.CURLE_URL_MALFORMAT,
        curl.CURLE_BAD_FUNCTION_ARGUMENT,
        => .InvalidUrl,

        // Aborted by User
        // Spec: "aborted" flag on response
        curl.CURLE_ABORTED_BY_CALLBACK,
        => .Aborted,

        // Connection Reset / Receive Errors
        // Spec: Connection terminated unexpectedly
        curl.CURLE_RECV_ERROR,
        curl.CURLE_SEND_ERROR,
        curl.CURLE_GOT_NOTHING,
        => .ConnectionReset,

        // Protocol Errors
        // Spec: Malformed HTTP response
        curl.CURLE_UNSUPPORTED_PROTOCOL,
        curl.CURLE_HTTP_RETURNED_ERROR,
        curl.CURLE_WEIRD_SERVER_REPLY,
        => .ProtocolError,

        // Memory Errors
        curl.CURLE_OUT_OF_MEMORY,
        => .OutOfMemory,

        // All other errors map to Unknown
        else => .Unknown,
    };
}

/// Get a human-readable error message for a curl error code.
/// Returns a Zig slice containing the error description.
pub fn getErrorMessage(code: curl.CURLcode) []const u8 {
    return curl.getErrorMessage(code);
}

/// Check if an error is retryable (transient network issue).
///
/// Returns true for errors that might succeed on retry:
/// - DNS resolution (might be temporary)
/// - Connection timeout (server might be temporarily overloaded)
/// - Connection reset (might be a transient issue)
///
/// Useful for implementing retry logic in the Fetch algorithm.
pub fn isRetryable(err: NetworkError) bool {
    return switch (err) {
        .DnsResolutionFailed,
        .ConnectionTimeout,
        .RequestTimeout,
        .ConnectionReset,
        .NetworkUnreachable,
        .HostUnreachable,
        => true,

        .ConnectionRefused,
        .SslHandshakeFailed,
        .SslCertificateError,
        .TooManyRedirects,
        .InvalidUrl,
        .Aborted,
        .ProtocolError,
        .OutOfMemory,
        .Unknown,
        => false,
    };
}

/// Check if an error is related to TLS/SSL.
/// Useful for determining if the error might be fixable by
/// adjusting TLS settings or certificate configuration.
pub fn isTlsError(err: NetworkError) bool {
    return switch (err) {
        .SslHandshakeFailed,
        .SslCertificateError,
        => true,
        else => false,
    };
}

/// Check if an error is related to DNS resolution.
pub fn isDnsError(err: NetworkError) bool {
    return err == .DnsResolutionFailed;
}

/// Check if an error is related to connection establishment.
pub fn isConnectionError(err: NetworkError) bool {
    return switch (err) {
        .ConnectionRefused,
        .ConnectionTimeout,
        .ConnectionReset,
        .NetworkUnreachable,
        .HostUnreachable,
        => true,
        else => false,
    };
}

/// Check if an error represents a timeout condition.
pub fn isTimeoutError(err: NetworkError) bool {
    return switch (err) {
        .ConnectionTimeout,
        .RequestTimeout,
        => true,
        else => false,
    };
}

/// Get a spec-compliant error category name for logging/debugging.
/// These names align with WHATWG Fetch spec terminology.
pub fn getErrorCategoryName(err: NetworkError) []const u8 {
    return switch (err) {
        .DnsResolutionFailed => "DNS error",
        .ConnectionRefused => "connection error",
        .ConnectionTimeout => "connection timeout",
        .RequestTimeout => "request timeout",
        .SslHandshakeFailed => "TLS negotiation error",
        .SslCertificateError => "TLS certificate error",
        .TooManyRedirects => "redirect limit exceeded",
        .InvalidUrl => "URL error",
        .Aborted => "aborted",
        .NetworkUnreachable => "network unreachable",
        .HostUnreachable => "host unreachable",
        .ConnectionReset => "connection reset",
        .ProtocolError => "protocol error",
        .OutOfMemory => "out of memory",
        .Unknown => "unknown error",
    };
}

// =============================================================================
// Tests
// =============================================================================

test "mapCurlError - DNS errors" {
    try std.testing.expectEqual(
        NetworkError.DnsResolutionFailed,
        mapCurlError(curl.CURLE_COULDNT_RESOLVE_HOST),
    );
    try std.testing.expectEqual(
        NetworkError.DnsResolutionFailed,
        mapCurlError(curl.CURLE_COULDNT_RESOLVE_PROXY),
    );
}

test "mapCurlError - connection errors" {
    try std.testing.expectEqual(
        NetworkError.ConnectionRefused,
        mapCurlError(curl.CURLE_COULDNT_CONNECT),
    );
    try std.testing.expectEqual(
        NetworkError.RequestTimeout,
        mapCurlError(curl.CURLE_OPERATION_TIMEDOUT),
    );
}

test "mapCurlError - TLS handshake errors" {
    try std.testing.expectEqual(
        NetworkError.SslHandshakeFailed,
        mapCurlError(curl.CURLE_SSL_CONNECT_ERROR),
    );
    try std.testing.expectEqual(
        NetworkError.SslHandshakeFailed,
        mapCurlError(curl.CURLE_SSL_ENGINE_NOTFOUND),
    );
}

test "mapCurlError - TLS certificate errors" {
    try std.testing.expectEqual(
        NetworkError.SslCertificateError,
        mapCurlError(curl.CURLE_PEER_FAILED_VERIFICATION),
    );
    try std.testing.expectEqual(
        NetworkError.SslCertificateError,
        mapCurlError(curl.CURLE_SSL_CACERT),
    );
    try std.testing.expectEqual(
        NetworkError.SslCertificateError,
        mapCurlError(curl.CURLE_SSL_CERTPROBLEM),
    );
}

test "mapCurlError - redirect and URL errors" {
    try std.testing.expectEqual(
        NetworkError.TooManyRedirects,
        mapCurlError(curl.CURLE_TOO_MANY_REDIRECTS),
    );
    try std.testing.expectEqual(
        NetworkError.InvalidUrl,
        mapCurlError(curl.CURLE_URL_MALFORMAT),
    );
}

test "mapCurlError - abort and transfer errors" {
    try std.testing.expectEqual(
        NetworkError.Aborted,
        mapCurlError(curl.CURLE_ABORTED_BY_CALLBACK),
    );
    try std.testing.expectEqual(
        NetworkError.ConnectionReset,
        mapCurlError(curl.CURLE_RECV_ERROR),
    );
    try std.testing.expectEqual(
        NetworkError.ConnectionReset,
        mapCurlError(curl.CURLE_SEND_ERROR),
    );
}

test "mapCurlError - protocol and memory errors" {
    try std.testing.expectEqual(
        NetworkError.ProtocolError,
        mapCurlError(curl.CURLE_UNSUPPORTED_PROTOCOL),
    );
    try std.testing.expectEqual(
        NetworkError.OutOfMemory,
        mapCurlError(curl.CURLE_OUT_OF_MEMORY),
    );
}

test "isRetryable - transient errors" {
    try std.testing.expect(isRetryable(.DnsResolutionFailed));
    try std.testing.expect(isRetryable(.RequestTimeout));
    try std.testing.expect(isRetryable(.ConnectionReset));
}

test "isRetryable - permanent errors" {
    try std.testing.expect(!isRetryable(.SslCertificateError));
    try std.testing.expect(!isRetryable(.Aborted));
    try std.testing.expect(!isRetryable(.InvalidUrl));
    try std.testing.expect(!isRetryable(.TooManyRedirects));
}

test "isTlsError" {
    try std.testing.expect(isTlsError(.SslHandshakeFailed));
    try std.testing.expect(isTlsError(.SslCertificateError));
    try std.testing.expect(!isTlsError(.DnsResolutionFailed));
    try std.testing.expect(!isTlsError(.ConnectionRefused));
}

test "isDnsError" {
    try std.testing.expect(isDnsError(.DnsResolutionFailed));
    try std.testing.expect(!isDnsError(.ConnectionRefused));
}

test "isConnectionError" {
    try std.testing.expect(isConnectionError(.ConnectionRefused));
    try std.testing.expect(isConnectionError(.ConnectionReset));
    try std.testing.expect(!isConnectionError(.DnsResolutionFailed));
    try std.testing.expect(!isConnectionError(.SslCertificateError));
}

test "isTimeoutError" {
    try std.testing.expect(isTimeoutError(.RequestTimeout));
    try std.testing.expect(isTimeoutError(.ConnectionTimeout));
    try std.testing.expect(!isTimeoutError(.ConnectionRefused));
}

test "getErrorCategoryName" {
    try std.testing.expectEqualStrings("DNS error", getErrorCategoryName(.DnsResolutionFailed));
    try std.testing.expectEqualStrings("TLS certificate error", getErrorCategoryName(.SslCertificateError));
    try std.testing.expectEqualStrings("aborted", getErrorCategoryName(.Aborted));
}
