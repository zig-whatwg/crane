//! Main Fetch Algorithm - WHATWG Fetch Specification
//!
//! This module implements the main fetch algorithm that orchestrates
//! the entire fetch process.
//!
//! Spec: https://fetch.spec.whatwg.org/#main-fetch
//!
//! The main fetch algorithm:
//! 1. Checks local-URLs-only flag
//! 2. Reports CSP violations (stubbed)
//! 3. Upgrades mixed content (stubbed)
//! 4. Checks bad ports
//! 5. Sets referrer policy
//! 6. Determines referrer
//! 7. Handles service worker interception
//! 8. Dispatches to scheme fetch
//! 9. Creates filtered responses
//! 10. Records timing info

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_response = @import("../internal/response.zig");
const InternalResponse = internal_response.InternalResponse;
const ResponseType = internal_response.ResponseType;
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const fetch_params = @import("../internal/fetch_params.zig");
const FetchParams = fetch_params.FetchParams;
const scheme_fetch = @import("scheme_fetch.zig");
const http_fetch = @import("http_fetch.zig");

/// Bad ports that should be blocked per Fetch spec.
/// These are ports commonly associated with protocols that shouldn't
/// be accessed via HTTP/HTTPS.
const bad_ports = [_]u16{
    1, // tcpmux
    7, // echo
    9, // discard
    11, // systat
    13, // daytime
    15, // netstat
    17, // qotd
    19, // chargen
    20, // ftp-data
    21, // ftp
    22, // ssh
    23, // telnet
    25, // smtp
    37, // time
    42, // nameserver
    43, // nicname
    53, // domain
    69, // tftp
    77, // rje
    79, // finger
    87, // ttylink
    95, // supdup
    101, // hostname
    102, // iso-tsap
    103, // gppitnp
    104, // acr-nema
    109, // pop2
    110, // pop3
    111, // sunrpc
    113, // auth
    115, // sftp
    117, // uucp-path
    119, // nntp
    123, // ntp
    135, // epmap
    137, // netbios-ns
    139, // netbios-ssn
    143, // imap
    161, // snmp
    179, // bgp
    389, // ldap
    427, // svrloc
    465, // submissions
    512, // exec
    513, // login
    514, // shell
    515, // printer
    526, // tempo
    530, // courier
    531, // chat
    532, // netnews
    540, // uucp
    548, // afp
    554, // rtsp
    556, // remotefs
    563, // nntps
    587, // submission
    601, // syslog-conn
    636, // ldaps
    989, // ftps-data
    990, // ftps
    993, // imaps
    995, // pop3s
    1719, // h323gatestat
    1720, // h323hostcall
    1723, // pptp
    2049, // nfs
    3659, // apple-sasl
    4045, // npp
    5060, // sip
    5061, // sips
    6000, // x11
    6566, // sane-port
    6665, // irc
    6666, // irc
    6667, // irc
    6668, // irc
    6669, // irc
    6697, // ircs-u
    10080, // amanda
};

/// Error types for main fetch.
pub const MainFetchError = error{
    OutOfMemory,
    NetworkError,
};

/// Main fetch result.
pub const MainFetchResult = struct {
    response: *InternalResponse,
    timing_end: i64,
};

/// Execute the main fetch algorithm.
///
/// Per Fetch spec §4.1:
/// 1. Let request be fetchParams's request
/// 2. Let response be null
/// 3. If request's local-URLs-only flag is set and request's current URL is not local, return network error
/// 4. Report CSP violations for request
/// 5. Upgrade mixed content request
/// 6. If should request be blocked due to a bad port, return network error
/// 7. If should request be blocked due to mime type, return network error
/// 8. Set request's referrer policy
/// 9. Set request's referrer
/// 10. (various preparation steps)
/// 11-13. Service worker and scheme fetch dispatch
/// 14-18. Response filtering and callbacks
pub fn mainFetch(
    allocator: Allocator,
    params: *FetchParams,
    recursive: bool,
) MainFetchError!*InternalResponse {
    const request = params.request;

    // Step 3: Check local-URLs-only
    if (request.local_urls_only) {
        const url_str = request.currentUrl();
        if (!isLocalUrlString(url_str)) {
            return try internal_response.networkError(allocator);
        }
    }

    // Step 4: Report CSP violations (stubbed - requires CSP implementation)
    // TODO: Implement CSP violation reporting

    // Step 5: Upgrade mixed content (stubbed - requires mixed content spec)
    // TODO: Implement mixed content upgrading

    // Step 6: Check bad port
    if (shouldBlockDueToBadPort(request)) {
        return try internal_response.networkError(allocator);
    }

    // Step 7: Check MIME type blocking (stubbed - requires nosniff implementation)
    // TODO: Implement MIME type blocking

    // Step 8: Set referrer policy if empty
    // Note: In full implementation, would get from policy container
    // For now, default to strict-origin-when-cross-origin
    if (request.referrer_policy == .empty) {
        request.referrer_policy = .strict_origin_when_cross_origin;
    }

    // Step 9: Determine referrer
    // TODO: Implement full referrer determination using referrer_policy module

    // Step 10: Upgrade URL scheme if needed
    // TODO: Implement HTTPS upgrading

    // Step 11: If recursive is false, do main fetch preparation
    if (!recursive) {
        // Set timing info (DOMHighResTimeStamp in milliseconds)
        const now = getCurrentTimeMs();
        params.timing_info.start_time = now;
        params.timing_info.post_redirect_start_time = now;
    }

    // Step 12-13: Service worker interception and scheme fetch
    // For now, skip service worker and dispatch based on scheme
    var response: *InternalResponse = undefined;

    // Get scheme from current URL string
    const url_str = request.currentUrl();
    const scheme = extractScheme(url_str);

    // Dispatch based on scheme
    if (scheme_fetch.isHttpScheme(scheme)) {
        // HTTP(S) requests go through HTTP fetch
        // Pass trust_store from params for HTTPS certificate validation
        response = http_fetch.httpFetch(allocator, params, .{ .trust_store = params.trust_store }) catch |err| switch (err) {
            http_fetch.HttpFetchError.OutOfMemory => return MainFetchError.OutOfMemory,
            http_fetch.HttpFetchError.NetworkError,
            http_fetch.HttpFetchError.CorsError,
            => {
                return try internal_response.networkError(allocator);
            },
        };
    } else {
        // Non-HTTP schemes go through scheme fetch
        const scheme_result = scheme_fetch.schemeFetch(allocator, scheme, url_str) catch |err| {
            switch (err) {
                error.OutOfMemory => return MainFetchError.OutOfMemory,
            }
        };

        switch (scheme_result) {
            .response => |resp| {
                response = resp;
            },
            .network_error => {
                response = try internal_response.networkError(allocator);
            },
        }
    }

    // Step 14: If recursive, return early
    if (recursive) {
        return response;
    }

    // Step 15: Response filtering based on tainting
    if (!isNetworkError(response)) {
        switch (request.response_tainting) {
            .cors => {
                // Create CORS filtered response (would filter headers)
                // For now, just mark the type
                response.response_type = .cors;
            },
            .basic => {
                response.response_type = .basic;
            },
            .@"opaque" => {
                response.response_type = .@"opaque";
            },
        }
    }

    // Step 16: Record end timing
    params.timing_info.end_time = getCurrentTimeMs();

    // Step 17-18: Process callbacks (handled by caller)

    return response;
}

/// Extract scheme from URL string.
/// Returns everything before the first ':' or empty string.
fn extractScheme(url_str: []const u8) []const u8 {
    const colon_pos = std.mem.indexOf(u8, url_str, ":");
    if (colon_pos) |pos| {
        return url_str[0..pos];
    }
    return "";
}

/// Check if URL string is local (about, blob, data schemes).
fn isLocalUrlString(url_str: []const u8) bool {
    const url_scheme = extractScheme(url_str);
    return std.ascii.eqlIgnoreCase(url_scheme, "about") or
        std.ascii.eqlIgnoreCase(url_scheme, "blob") or
        std.ascii.eqlIgnoreCase(url_scheme, "data");
}

/// Should request be blocked due to bad port?
fn shouldBlockDueToBadPort(request: *InternalRequest) bool {
    const url_str = request.currentUrl();

    // Only check for HTTP(S) schemes
    const url_scheme = extractScheme(url_str);
    if (!std.ascii.eqlIgnoreCase(url_scheme, "http") and
        !std.ascii.eqlIgnoreCase(url_scheme, "https"))
    {
        return false;
    }

    // Extract port from URL string
    // URL format: scheme://host:port/path
    const port = extractPort(url_str) orelse return false;

    // Check against bad ports
    for (bad_ports) |bad| {
        if (port == bad) return true;
    }

    return false;
}

/// Extract port from URL string.
/// Returns null if no explicit port or invalid.
fn extractPort(url_str: []const u8) ?u16 {
    // Find "://" to skip scheme
    const scheme_end = std.mem.indexOf(u8, url_str, "://") orelse return null;
    const authority_start = scheme_end + 3;

    if (authority_start >= url_str.len) return null;

    // Find end of authority (path start or end of string)
    const rest = url_str[authority_start..];
    const path_start = std.mem.indexOf(u8, rest, "/") orelse rest.len;
    const authority = rest[0..path_start];

    // Find port after last ':' (handle IPv6 addresses in brackets)
    // IPv6: [::1]:8080
    // IPv4: example.com:8080
    var port_start: ?usize = null;
    if (std.mem.indexOf(u8, authority, "]")) |bracket_end| {
        // IPv6 address - port is after the bracket
        if (bracket_end + 1 < authority.len and authority[bracket_end + 1] == ':') {
            port_start = bracket_end + 2;
        }
    } else {
        // Not IPv6 - find last colon
        port_start = std.mem.lastIndexOf(u8, authority, ":");
        if (port_start) |ps| {
            port_start = ps + 1;
        }
    }

    if (port_start) |ps| {
        if (ps < authority.len) {
            const port_str = authority[ps..];
            return std.fmt.parseInt(u16, port_str, 10) catch null;
        }
    }

    return null;
}

/// Check if response is a network error.
fn isNetworkError(response: *InternalResponse) bool {
    return response.response_type == .@"error" or response.status == 0;
}

/// Get current time in milliseconds (DOMHighResTimeStamp format).
fn getCurrentTimeMs() f64 {
    // std.time.timestamp() returns seconds, convert to milliseconds
    return @as(f64, @floatFromInt(std.time.timestamp())) * 1000.0;
}

// =============================================================================
// Tests
// =============================================================================

test "shouldBlockDueToBadPort - blocked ports" {
    // This test requires a mock InternalRequest
    // For now, just test the bad_ports array is populated
    try std.testing.expect(bad_ports.len > 0);
    // Verify array contains expected dangerous ports (don't check indices - they may shift)
    const contains = struct {
        fn check(port: u16) bool {
            for (bad_ports) |p| {
                if (p == port) return true;
            }
            return false;
        }
    };
    try std.testing.expect(contains.check(21)); // ftp
    try std.testing.expect(contains.check(22)); // ssh
    try std.testing.expect(contains.check(23)); // telnet
}

test "bad_ports contains common dangerous ports" {
    const contains = struct {
        fn check(port: u16) bool {
            for (bad_ports) |p| {
                if (p == port) return true;
            }
            return false;
        }
    };

    // FTP ports
    try std.testing.expect(contains.check(20));
    try std.testing.expect(contains.check(21));

    // SSH
    try std.testing.expect(contains.check(22));

    // Telnet
    try std.testing.expect(contains.check(23));

    // SMTP
    try std.testing.expect(contains.check(25));

    // IRC ports
    try std.testing.expect(contains.check(6667));

    // Common safe ports should not be blocked
    try std.testing.expect(!contains.check(80));
    try std.testing.expect(!contains.check(443));
    try std.testing.expect(!contains.check(8080));
    try std.testing.expect(!contains.check(3000));
}

test "isLocalUrlString helper" {
    try std.testing.expect(isLocalUrlString("about:blank"));
    try std.testing.expect(isLocalUrlString("blob:https://example.com/uuid"));
    try std.testing.expect(isLocalUrlString("data:text/plain,Hello"));
    try std.testing.expect(isLocalUrlString("ABOUT:blank")); // Case insensitive
    try std.testing.expect(!isLocalUrlString("http://example.com"));
    try std.testing.expect(!isLocalUrlString("https://example.com"));
    try std.testing.expect(!isLocalUrlString("file:///path/to/file"));
}

test "extractScheme helper" {
    try std.testing.expectEqualStrings("https", extractScheme("https://example.com"));
    try std.testing.expectEqualStrings("http", extractScheme("http://example.com"));
    try std.testing.expectEqualStrings("data", extractScheme("data:text/plain,Hello"));
    try std.testing.expectEqualStrings("about", extractScheme("about:blank"));
    try std.testing.expectEqualStrings("", extractScheme("no-colon-here"));
}
