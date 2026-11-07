//! Fetch 3.7 "queue a cross-origin embedder policy CORP violation report":
//! snapshot a CORP violation of a request's client's embedder policy into the
//! client global's Reporting queue, as a "coep" report (HTML 7.1.4: visible to
//! ReportingObservers). Fetch borrows this reporter while its client is alive,
//! exactly as it borrows sri_reporting's; this module owns no global state,
//! tasks or network operations.
//!
//! Spec: https://fetch.spec.whatwg.org/#queue-a-cross-origin-embedder-policy-corp-violation-report

const std = @import("std");
const runtime = @import("runtime");
const request = @import("fetch").internal.request;
const csp = @import("csp");
const reporting = @import("reporting.zig");

/// The reporter for `global`'s requests. Its context is the global's REALM,
/// resolved when fetch reports - never the global, which can end while a
/// request still carries the reporter (csp_violations.reporterFor says why).
pub fn reporterFor(global: *runtime.Instance) request.CoepViolationReporter {
    return .{ .context = global.ctx, .report = report };
}

fn report(context: *anyopaque, violation: *const request.CoepViolation) void {
    // A realm whose global is gone reports nothing.
    const global = @import("global_settings.zig").liveGlobalOf(@ptrCast(@alignCast(context))) orelse return;
    reportFallible(global, violation) catch {};
}

/// Fetch "serialize a response URL for reporting", given the response's URL
/// list (serialized URLs, oldest first). OWNED.
///
/// The COEP reports name this algorithm (Fetch "queue a cross-origin
/// embedder policy CORP violation report" step 2; HTML "queue a cross-origin
/// embedder policy inheritance violation" step 1). CSP §5.4's "strip URL for
/// use in reports" - a non-HTTP(S) URL becomes its scheme ("data") - is
/// CSP's own rule, for CSP's reports only (csp.violation_events
/// .stripUrlForReports): a COEP report's blockedURL keeps a data:, blob: or
/// about: URL whole. html/cross-origin-embedder-policy/
/// block-local-documents-inheriting-none.https.html expects them so
/// (C157 1/1 at wpt.fyi 94f58d592d; lane coi2 batch 3).
pub fn serializeResponseUrlForReporting(allocator: std.mem.Allocator, url_list: []const []const u8) error{OutOfMemory}![]u8 {
    // 1. "Assert: response's URL list is not empty."
    std.debug.assert(url_list.len > 0);
    // 2. "Let url be a copy of response's URL list[0]" - not the response's
    // URL, which would leak where its redirects went.
    const url = url_list[0];
    // 5's "exclude fragment": nothing from the first "#" on (a serialized
    // URL's only unescaped "#" starts its fragment).
    const without_fragment = url[0 .. std.mem.indexOfScalar(u8, url, '#') orelse url.len];
    // 3. "Set the username given url and the empty string." 4. "Set the
    // password given url and the empty string." In a serialization, both are
    // the authority's userinfo, before its last "@"; a URL with no authority
    // (data:, about:) has none.
    const colon = std.mem.indexOfScalar(u8, without_fragment, ':') orelse return allocator.dupe(u8, without_fragment);
    if (!std.mem.startsWith(u8, without_fragment[colon..], "://")) return allocator.dupe(u8, without_fragment);
    const authority_start = colon + 3;
    const rest = without_fragment[authority_start..];
    const authority_end = std.mem.indexOfAny(u8, rest, "/?") orelse rest.len;
    const at = std.mem.lastIndexOfScalar(u8, rest[0..authority_end], '@') orelse return allocator.dupe(u8, without_fragment);
    // 5. "Return the serialization of url with exclude fragment set to true."
    return std.mem.concat(allocator, u8, &.{ without_fragment[0..authority_start], rest[at + 1 ..] });
}

test "a response URL for reporting: URL list[0], every scheme whole, no fragment, no credentials" {
    const cases = [_]struct { list: []const []const u8, want: []const u8 }{
        .{ .list = &.{"https://user:pass@example.test:8443/a/b?q=1#frag"}, .want = "https://example.test:8443/a/b?q=1" },
        .{ .list = &.{"https://example.test/path@not-userinfo"}, .want = "https://example.test/path@not-userinfo" },
        .{ .list = &.{"data:text/html,%3Cp%3Ehi"}, .want = "data:text/html,%3Cp%3Ehi" },
        .{ .list = &.{"blob:https://example.test/2ca1a43f-d322-4704-8ca6-9280c4d9e4a3"}, .want = "blob:https://example.test/2ca1a43f-d322-4704-8ca6-9280c4d9e4a3" },
        .{ .list = &.{"about:blank"}, .want = "about:blank" },
        // A redirected response: its URL list[0], never where it ended.
        .{ .list = &.{ "https://a.test/start#x", "https://b.test/end" }, .want = "https://a.test/start" },
    };
    for (cases) |case| {
        const got = try serializeResponseUrlForReporting(std.testing.allocator, case.list);
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings(case.want, got);
    }
}

fn reportFallible(global: *runtime.Instance, violation: *const request.CoepViolation) !void {
    const allocator = global.ctx.allocator;
    // 2. "Let serializedURL be the result of serializing a response URL for
    // reporting with response": Fetch's algorithm, not CSP §5.4's strip rule
    // (CSP's own): no credentials, no fragment, every scheme's URL whole.
    // The violation's URL is the request's URL list[0] (http_fetch's
    // corpBlocks), which main fetch made the response's.
    const blocked_url = try serializeResponseUrlForReporting(allocator, &.{violation.blocked_url});
    defer allocator.free(blocked_url);
    // 4. The body: "type" "corp", "blockedURL", "destination" and
    // "disposition" ("reporting" for the report-only value's report).
    const body = try std.json.Stringify.valueAlloc(allocator, .{
        .type = "corp",
        .blockedURL = blocked_url,
        .destination = if (violation.destination == .empty) "" else @tagName(violation.destination),
        .disposition = if (violation.report_only) "reporting" else "enforce",
    }, .{});
    defer allocator.free(body);
    // The report's URL: the settings object's (its document's, or its
    // worker's creation URL).
    const url = try csp.violation_events.stripUrlForReports(allocator, global.ctx.documentUrl() orelse "");
    defer allocator.free(url);
    // 5. "Generate and queue a report for settingsObject's global object
    // given the "coep" report type, endpoint, and body."
    try reporting.generate(global, "coep", violation.endpoint, url, body);
}
