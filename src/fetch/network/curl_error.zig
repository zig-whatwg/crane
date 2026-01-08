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
pub fn mapCurlError(code: curl.CURLcode) NetworkError {
    // DNS Resolution Failures
    if (code == curl.CURLE_COULDNT_RESOLVE_PROXY or
        code == curl.CURLE_COULDNT_RESOLVE_HOST)
    {
        return NetworkError.DnsResolutionFailed;
    }

    // Connection Refused
    if (code == curl.CURLE_COULDNT_CONNECT) {
        return NetworkError.ConnectionRefused;
    }

    // Timeout
    if (code == curl.CURLE_OPERATION_TIMEDOUT) {
        return NetworkError.RequestTimeout;
    }

    // TLS Handshake Failures
    if (code == curl.CURLE_SSL_CONNECT_ERROR or
        code == curl.CURLE_SSL_ENGINE_NOTFOUND or
        code == curl.CURLE_SSL_ENGINE_SETFAILED)
    {
        return NetworkError.SslHandshakeFailed;
    }

    // TLS Certificate Errors
    if (code == curl.CURLE_SSL_CERTPROBLEM or
        code == curl.CURLE_SSL_CACERT or
        code == curl.CURLE_SSL_ISSUER_ERROR or
        code == curl.CURLE_SSL_PINNEDPUBKEYNOTMATCH)
    {
        return NetworkError.SslCertificateError;
    }

    // Redirect Limit
    if (code == curl.CURLE_TOO_MANY_REDIRECTS) {
        return NetworkError.TooManyRedirects;
    }

    // Invalid URL
    if (code == curl.CURLE_URL_MALFORMAT or
        code == curl.CURLE_BAD_FUNCTION_ARGUMENT)
    {
        return NetworkError.InvalidUrl;
    }

    // Aborted by User
    if (code == curl.CURLE_ABORTED_BY_CALLBACK) {
        return NetworkError.Aborted;
    }

    // Connection Reset / Receive Errors
    if (code == curl.CURLE_RECV_ERROR or
        code == curl.CURLE_SEND_ERROR or
        code == curl.CURLE_GOT_NOTHING)
    {
        return NetworkError.ConnectionReset;
    }

    // Protocol Errors
    if (code == curl.CURLE_UNSUPPORTED_PROTOCOL or
        code == curl.CURLE_HTTP_RETURNED_ERROR or
        code == curl.CURLE_WEIRD_SERVER_REPLY)
    {
        return NetworkError.ProtocolError;
    }

    // Memory Errors
    if (code == curl.CURLE_OUT_OF_MEMORY) {
        return NetworkError.OutOfMemory;
    }

    // All other errors map to Unknown
    return NetworkError.Unknown;
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
    return err == NetworkError.DnsResolutionFailed or
        err == NetworkError.ConnectionTimeout or
        err == NetworkError.RequestTimeout or
        err == NetworkError.ConnectionReset or
        err == NetworkError.NetworkUnreachable or
        err == NetworkError.HostUnreachable;
}

/// Check if an error is related to TLS/SSL.
/// Useful for determining if the error might be fixable by
/// adjusting TLS settings or certificate configuration.
pub fn isTlsError(err: NetworkError) bool {
    return err == NetworkError.SslHandshakeFailed or
        err == NetworkError.SslCertificateError;
}

/// Check if an error is related to DNS resolution.
pub fn isDnsError(err: NetworkError) bool {
    return err == NetworkError.DnsResolutionFailed;
}

/// Check if an error is related to connection establishment.
pub fn isConnectionError(err: NetworkError) bool {
    return err == NetworkError.ConnectionRefused or
        err == NetworkError.ConnectionTimeout or
        err == NetworkError.ConnectionReset or
        err == NetworkError.NetworkUnreachable or
        err == NetworkError.HostUnreachable;
}

/// Check if an error represents a timeout condition.
pub fn isTimeoutError(err: NetworkError) bool {
    return err == NetworkError.ConnectionTimeout or
        err == NetworkError.RequestTimeout;
}

/// Get a spec-compliant error category name for logging/debugging.
/// These names align with WHATWG Fetch spec terminology.
pub fn getErrorCategoryName(err: NetworkError) []const u8 {
    if (err == NetworkError.DnsResolutionFailed) return "DNS error";
    if (err == NetworkError.ConnectionRefused) return "connection error";
    if (err == NetworkError.ConnectionTimeout) return "connection timeout";
    if (err == NetworkError.RequestTimeout) return "request timeout";
    if (err == NetworkError.SslHandshakeFailed) return "TLS negotiation error";
    if (err == NetworkError.SslCertificateError) return "TLS certificate error";
    if (err == NetworkError.TooManyRedirects) return "redirect limit exceeded";
    if (err == NetworkError.InvalidUrl) return "URL error";
    if (err == NetworkError.Aborted) return "aborted";
    if (err == NetworkError.NetworkUnreachable) return "network unreachable";
    if (err == NetworkError.HostUnreachable) return "host unreachable";
    if (err == NetworkError.ConnectionReset) return "connection reset";
    if (err == NetworkError.ProtocolError) return "protocol error";
    if (err == NetworkError.OutOfMemory) return "out of memory";
    return "unknown error";
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
    try std.testing.expect(isRetryable(NetworkError.DnsResolutionFailed));
    try std.testing.expect(isRetryable(NetworkError.RequestTimeout));
    try std.testing.expect(isRetryable(NetworkError.ConnectionReset));
}

test "isRetryable - permanent errors" {
    try std.testing.expect(!isRetryable(NetworkError.SslCertificateError));
    try std.testing.expect(!isRetryable(NetworkError.Aborted));
    try std.testing.expect(!isRetryable(NetworkError.InvalidUrl));
    try std.testing.expect(!isRetryable(NetworkError.TooManyRedirects));
}

test "isTlsError" {
    try std.testing.expect(isTlsError(NetworkError.SslHandshakeFailed));
    try std.testing.expect(isTlsError(NetworkError.SslCertificateError));
    try std.testing.expect(!isTlsError(NetworkError.DnsResolutionFailed));
    try std.testing.expect(!isTlsError(NetworkError.ConnectionRefused));
}

test "isDnsError" {
    try std.testing.expect(isDnsError(NetworkError.DnsResolutionFailed));
    try std.testing.expect(!isDnsError(NetworkError.ConnectionRefused));
}

test "isConnectionError" {
    try std.testing.expect(isConnectionError(NetworkError.ConnectionRefused));
    try std.testing.expect(isConnectionError(NetworkError.ConnectionReset));
    try std.testing.expect(!isConnectionError(NetworkError.DnsResolutionFailed));
    try std.testing.expect(!isConnectionError(NetworkError.SslCertificateError));
}

test "isTimeoutError" {
    try std.testing.expect(isTimeoutError(NetworkError.RequestTimeout));
    try std.testing.expect(isTimeoutError(NetworkError.ConnectionTimeout));
    try std.testing.expect(!isTimeoutError(NetworkError.ConnectionRefused));
}

test "getErrorCategoryName" {
    try std.testing.expectEqualStrings("DNS error", getErrorCategoryName(NetworkError.DnsResolutionFailed));
    try std.testing.expectEqualStrings("TLS certificate error", getErrorCategoryName(NetworkError.SslCertificateError));
    try std.testing.expectEqualStrings("aborted", getErrorCategoryName(NetworkError.Aborted));
}
