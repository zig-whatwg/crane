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

fn reportFallible(global: *runtime.Instance, violation: *const request.CoepViolation) !void {
    const allocator = global.ctx.allocator;
    // 2. "Let serializedURL be the result of serializing a response URL for
    // reporting with response": no credentials, no fragment.
    const blocked_url = try csp.violation_events.stripUrlForReports(allocator, violation.blocked_url);
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
