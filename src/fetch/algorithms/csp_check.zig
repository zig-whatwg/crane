//! Main fetch's Content Security Policy hooks: step 4's "report Content
//! Security Policy violations for request" (CSP 4.1.1) and step 7's "should
//! request be blocked by Content Security Policy?" (CSP 4.1.2), asked of the
//! request's policy container's CSP list.
//!
//! The algorithms are CSP's (csp.request_check); this file hands it the
//! request as the parts they read. A violation (CSP 2.4.2) goes to the
//! reporter the request took from its client - its client's global fires
//! securitypolicyviolation (CSP 5.5, src/dom/csp_violations.zig).
//!
//! Deviation, stated: a request whose destination is "document" - a
//! top-level navigation - is not checked. CSP 6.8.1 would make its effective
//! directive connect-src, which no browser applies to a navigation; a
//! frame's navigation (destination "iframe" or "frame") is frame-src's.
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
        .integrity_metadata = request.integrity_metadata,
        .parser_inserted = request.parser_metadata == .parser_inserted,
    };
}

/// Main fetch step 7's "should request be blocked by Content Security
/// Policy?" over the request's policy container's CSP list, each violation
/// reported to the request's client. A request still on "client" (none
/// populated it) has none, and nothing blocks it.
pub fn shouldRequestBeBlocked(request: *const InternalRequest) bool {
    const container = checkedContainer(request) orelse return false;
    var reporting: RequestReporting = .{ .url = request.getUrl(), .client = request.csp_violation_reporter };
    return csp.request_check.shouldRequestBeBlocked(&container.csp_list, requestOf(request), reporting.reporter()) == .blocked;
}

/// Main fetch step 4, "report Content Security Policy violations for
/// request" (CSP 4.1.1): each report-only policy the request violates is
/// reported to the request's client; nothing is blocked.
pub fn reportViolationsForRequest(request: *const InternalRequest) void {
    const container = checkedContainer(request) orelse return;
    if (request.csp_violation_reporter == null) return;
    var reporting: RequestReporting = .{ .url = request.getUrl(), .client = request.csp_violation_reporter };
    csp.request_check.reportViolationsForRequest(&container.csp_list, requestOf(request), reporting.reporter().?);
}

/// Main fetch step 7 for a request a caller answers without main fetch - a
/// data: or blob: worker script: would a request for `url` with
/// `destination`, whose policy container is `container`, be blocked by
/// Content Security Policy? Its violations go to `reporter`, the request's
/// client's.
pub fn isBlockedFor(container: *const internal_request.PolicyContainer, url: []const u8, destination: internal_request.Destination, reporter: ?internal_request.CspViolationReporter) bool {
    if (container.csp_list.isEmpty()) return false;
    const request: csp.request_check.Request = .{ .url = urlParts(url), .destination = destinationName(destination) };
    var reporting: RequestReporting = .{ .url = url, .client = reporter };
    return csp.request_check.shouldRequestBeBlocked(&container.csp_list, request, reporting.reporter()) == .blocked;
}

/// The policy container whose CSP list main fetch checks `request` against:
/// none for a request still on "client", one with an empty list, or a
/// top-level navigation (stated above).
fn checkedContainer(request: *const InternalRequest) ?*const internal_request.PolicyContainer {
    const container = switch (request.policy_container) {
        .client => return null,
        .container => |*c| c,
    };
    if (container.csp_list.isEmpty()) return null;
    if (request.destination == .document) return null;
    return container;
}

/// CSP 2.4.2 "create a violation object for request, and policy": the
/// request's effective directive and, as its resource, the request's URL -
/// "not its current url, as the latter might contain information about
/// redirect targets" - handed to the client's reporter.
const RequestReporting = struct {
    url: []const u8,
    client: ?internal_request.CspViolationReporter,

    fn reporter(self: *RequestReporting) ?csp.request_check.Reporter {
        if (self.client == null) return null;
        return .{ .context = self, .report = &report };
    }

    fn report(context: *anyopaque, violation: csp.request_check.Violation) void {
        const self: *RequestReporting = @ptrCast(@alignCast(context));
        const client = self.client orelse return;
        client.reportViolation(&.{
            .policy = violation.policy,
            .effective_directive = violation.effective_directive,
            .resource = .{ .url = self.url },
        });
    }
};

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

const TestReports = struct {
    count: usize = 0,
    directive: [32]u8 = undefined,
    directive_len: usize = 0,
    resource: [128]u8 = undefined,
    resource_len: usize = 0,
    disposition: csp.PolicyDisposition = .enforce,

    fn report(context: *anyopaque, violation: *const csp.violation_events.Violation) void {
        const self: *TestReports = @ptrCast(@alignCast(context));
        self.count += 1;
        @memcpy(self.directive[0..violation.effective_directive.len], violation.effective_directive);
        self.directive_len = violation.effective_directive.len;
        const resource = violation.resource.keyword();
        @memcpy(self.resource[0..resource.len], resource);
        self.resource_len = resource.len;
        self.disposition = violation.policy.disposition;
    }
};

test "a blocked request's violation goes to its client's reporter: the effective directive and the request's URL" {
    const allocator = std.testing.allocator;
    const PolicyContainer = internal_request.PolicyContainer;
    const request = try InternalRequest.init(allocator, "https://a.test/w.js");
    defer request.deinit();
    request.destination = .worker;
    var reports: TestReports = .{};
    request.csp_violation_reporter = .{ .context = &reports, .report = &TestReports.report };
    request.setPolicyContainer(try PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "http://web-platform.test:8000/page.html",
        .csp = "script-src 'none'",
    }));
    // A redirect: the violation names the request's URL, not its current URL
    // (CSP 2.4.2 step 3).
    try request.url_list.append(allocator, try allocator.dupe(u8, "https://b.test/redirected.js"));
    try std.testing.expect(shouldRequestBeBlocked(request));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqualStrings("worker-src", reports.directive[0..reports.directive_len]);
    try std.testing.expectEqualStrings("https://a.test/w.js", reports.resource[0..reports.resource_len]);
}

test "main fetch step 4: a report-only policy's violation is reported and blocks nothing" {
    const allocator = std.testing.allocator;
    const PolicyContainer = internal_request.PolicyContainer;
    const request = try InternalRequest.init(allocator, "https://a.test/data.json");
    defer request.deinit();
    var reports: TestReports = .{};
    request.csp_violation_reporter = .{ .context = &reports, .report = &TestReports.report };
    request.setPolicyContainer(try PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "http://web-platform.test:8000/page.html",
        .csp_report_only = "connect-src 'self'",
    }));
    reportViolationsForRequest(request);
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqualStrings("connect-src", reports.directive[0..reports.directive_len]);
    try std.testing.expectEqual(csp.PolicyDisposition.report, reports.disposition);
    try std.testing.expect(!shouldRequestBeBlocked(request));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
}
