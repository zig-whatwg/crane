//! Main fetch's Content Security Policy hooks: step 7's "should request be
//! blocked by Content Security Policy?" (CSP 4.1.2), asked of the request's
//! policy container's CSP list.
//!
//! The algorithms are CSP's (csp.request_check); this file hands it the
//! request as the parts they read.
//!
//! Deviation, stated: a request whose destination is "document" - a
//! top-level navigation - is not checked. CSP 6.8.1 would make its effective
//! directive connect-src, which no browser applies to a navigation; a
//! frame's navigation (destination "iframe" or "frame") is frame-src's.
//! Not modelled, stated: violation reports (CSP 5.5) - the request carries
//! no global to fire securitypolicyviolation at; callers that have one
//! report through `csp.request_check` themselves.
//!
//! Spec: https://w3c.github.io/webappsec-csp/#should-block-request

const std = @import("std");
const csp = @import("csp");
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;

/// The parts of a serialized URL that source matching reads: its scheme,
/// host, port and path. The URL is one Fetch holds - already parsed and
/// serialized, so its scheme and host are in their normal forms.
pub fn urlParts(url: []const u8) csp.request_check.Url {
    const colon = std.mem.indexOfScalar(u8, url, ':') orelse return .{ .scheme = "" };
    var parts: csp.request_check.Url = .{ .scheme = url[0..colon] };
    var rest = url[colon + 1 ..];
    // The path ends at the query or the fragment.
    const path_end = std.mem.indexOfAny(u8, rest, "?#") orelse rest.len;
    rest = rest[0..path_end];
    if (!std.mem.startsWith(u8, rest, "//")) {
        // No authority: no host, and the rest is the path.
        parts.path = rest;
        return parts;
    }
    const after = rest[2..];
    const authority_end = std.mem.indexOfScalar(u8, after, '/') orelse after.len;
    var authority = after[0..authority_end];
    parts.path = after[authority_end..];
    // Credentials end at the last '@'.
    if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| authority = authority[at + 1 ..];
    // The host - an IPv6 address keeps its brackets - then a port.
    const host_end = if (authority.len > 0 and authority[0] == '[')
        (std.mem.indexOfScalar(u8, authority, ']') orelse authority.len - 1) + 1
    else
        std.mem.indexOfScalar(u8, authority, ':') orelse authority.len;
    parts.host = if (host_end > 0) authority[0..host_end] else null;
    if (host_end < authority.len and authority[host_end] == ':') {
        parts.port = std.fmt.parseInt(u16, authority[host_end + 1 ..], 10) catch null;
    }
    return parts;
}

/// `request`, as CSP's pre-request checks read it.
pub fn requestOf(request: *const InternalRequest) csp.request_check.Request {
    return .{
        .url = urlParts(request.currentUrl()),
        .destination = destinationName(request.destination),
        .initiator = initiatorName(request.initiator),
        .redirect_count = request.redirect_count,
        .nonce = request.cryptographic_nonce_metadata,
        .parser_inserted = request.parser_metadata == .parser_inserted,
    };
}

/// Main fetch step 7's "should request be blocked by Content Security
/// Policy?" over the request's policy container's CSP list. A request still
/// on "client" (none populated it) has none, and nothing blocks it.
pub fn shouldRequestBeBlocked(request: *const InternalRequest) bool {
    const container = switch (request.policy_container) {
        .client => return false,
        .container => |*c| c,
    };
    if (container.csp_list.isEmpty()) return false;
    if (request.destination == .document) return false;
    return csp.request_check.shouldRequestBeBlocked(&container.csp_list, requestOf(request), null) == .blocked;
}

/// Main fetch step 7 for a request a caller answers without main fetch - a
/// data: or blob: worker script: would a request for `url` with
/// `destination`, whose policy container is `container`, be blocked by
/// Content Security Policy?
pub fn isBlockedFor(container: *const internal_request.PolicyContainer, url: []const u8, destination: internal_request.Destination) bool {
    if (container.csp_list.isEmpty()) return false;
    const request: csp.request_check.Request = .{ .url = urlParts(url), .destination = destinationName(destination) };
    return csp.request_check.shouldRequestBeBlocked(&container.csp_list, request, null) == .blocked;
}

/// A destination as Fetch spells it.
pub fn destinationName(destination: internal_request.Destination) []const u8 {
    return switch (destination) {
        .empty => "",
        else => @tagName(destination),
    };
}

fn initiatorName(initiator: internal_request.Initiator) []const u8 {
    return switch (initiator) {
        .empty => "",
        else => @tagName(initiator),
    };
}

test "urlParts: special and opaque URLs" {
    const a = urlParts("https://user:pw@www1.web-platform.test:8443/x/y.js?q#f");
    try std.testing.expectEqualStrings("https", a.scheme);
    try std.testing.expectEqualStrings("www1.web-platform.test", a.host.?);
    try std.testing.expectEqual(@as(?u16, 8443), a.port);
    try std.testing.expectEqualStrings("/x/y.js", a.path);
    const b = urlParts("http://[::1]/");
    try std.testing.expectEqualStrings("[::1]", b.host.?);
    try std.testing.expect(b.port == null);
    const c = urlParts("data:text/javascript,import '/x';");
    try std.testing.expectEqualStrings("data", c.scheme);
    try std.testing.expect(c.host == null);
}

test "a request's policy container's CSP list blocks it at main fetch step 7" {
    const allocator = std.testing.allocator;
    const PolicyContainer = internal_request.PolicyContainer;
    const request = try InternalRequest.init(allocator, "data:text/javascript,1");
    defer request.deinit();
    request.destination = .worker;
    // No container: nothing to block.
    try std.testing.expect(!shouldRequestBeBlocked(request));
    request.setPolicyContainer(try PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "http://web-platform.test:8000/page.html",
        .csp = "worker-src 'self'",
    }));
    try std.testing.expect(shouldRequestBeBlocked(request));
    // A top-level navigation is not checked.
    request.destination = .document;
    try std.testing.expect(!shouldRequestBeBlocked(request));
}
