//! SRI §3.8.3: snapshot integrity-violation data into the existing Reporting
//! queue. Fetch borrows this reporter while its client is alive; this module
//! owns no global state, tasks or network operations.
//!
//! https://w3c.github.io/webappsec-subresource-integrity/#report-violation

const std = @import("std");
const runtime = @import("runtime");
const request = @import("fetch").internal.request;
const csp = @import("csp");
const reporting = @import("reporting.zig");

pub fn reporterFor(global: *runtime.Instance) request.IntegrityViolationReporter {
    return .{ .context = global, .report = report };
}

fn report(context: *anyopaque, violation: *const request.IntegrityViolation) void {
    reportFallible(@ptrCast(@alignCast(context)), violation) catch {};
}

fn reportFallible(global: *runtime.Instance, violation: *const request.IntegrityViolation) !void {
    // Steps 11-12 generate one report per named policy endpoint. Reporting
    // observers still hear it when Reporting-Endpoints maps no such name.
    if (violation.endpoints.len == 0) return;
    const allocator = global.ctx.allocator;
    // Steps 5-10: the realm's document URL (worker creation URL) and the
    // blocked request URL, stripped by the existing report URL helper.
    const document_url = try csp.violation_events.stripUrlForReports(allocator, global.ctx.documentUrl() orelse "");
    defer allocator.free(document_url);
    const blocked_url = try csp.violation_events.stripUrlForReports(allocator, violation.blocked_url);
    defer allocator.free(blocked_url);
    const body = try std.json.Stringify.valueAlloc(allocator, .{
        .documentURL = document_url,
        .blockedURL = blocked_url,
        .destination = if (violation.destination == .empty) "" else @tagName(violation.destination),
        .reportOnly = violation.report_only,
    }, .{});
    defer allocator.free(body);
    for (violation.endpoints) |endpoint| {
        try reporting.generate(global, "integrity-violation", endpoint, document_url, body);
    }
}
