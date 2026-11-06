//! HTML 7.1.3.3's opener policy reports, the host's half: the navigation
//! reports "enforce a response's opener policy" steps 4.2 and 5.2 queue
//! (html.navigation.opener_policy builds their bodies), queued through
//! Reporting's queue for an endpoint list with a URL and no settings object
//! (dom.reporting.queueForEndpoint) - the form CSP's response-policy
//! reports use too. This module owns no state, tasks or network operations.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#reporting

const std = @import("std");
const runtime = @import("runtime");
const fetch = @import("fetch");
const html_core = @import("html_core");
const reporting = @import("reporting.zig");

const opener_policy = html_core.navigation.opener_policy;
const Endpoints = fetch.internal.policy_container.Endpoints;

/// One side of a navigation's opener policy decision: the response's, or the
/// navigable's active document's (the current enforcement result's). Every
/// field is borrowed for the call.
pub const Side = struct {
    /// Its opener policy, with its endpoint names.
    policy: opener_policy.OpenerPolicy,
    /// The URL its reports are made for (coopURL): the response's URL, or
    /// the enforcement result's url.
    url: []const u8,
    /// Its origin, serialized ("null" when opaque).
    origin: []const u8,
    /// The endpoint list its policy's names resolve in: the response's
    /// Reporting-Endpoints, or the active document's. For an initial
    /// about:blank document whose opener policy its creator's top-level
    /// document gave it (HTML "create a new browsing context and document"
    /// step 19.3), that document's, with `url` its URL: Chromium gives the
    /// popup's initial empty document a COOP reporter made from its
    /// creator's URL and reporting source, and its
    /// CrossOriginOpenerPolicyStatus reports with the opener's URL; WebKit's
    /// CrossOriginOpenerPolicyEnforcementResult::from takes openerURL. The
    /// tests expect the report at the opener's endpoint with the opener's
    /// URL (document-reporting/report-only-four-reports: C157 1/1, S27.2
    /// 1/1, F159 0/1); HTML's text would report about:blank, to no endpoint.
    endpoints: ?*Endpoints,
};

/// HTML "enforce a response's opener policy" steps 4.2 and 5.2, after
/// `opener_policy.enforce` said which apply (`reports`: it asks only when
/// the browsing context's group holds another top-level context): for each
/// disposition, "queue a violation report for browsing context group switch
/// when navigating to a COOP response" (the response's policy, from the
/// current result's url) and "... when navigating away from a COOP
/// response" (the current result's policy, to the response's URL).
/// `referrer` is the request's referrer (serialized, or null for
/// "no-referrer"); `current_is_navigation_source` the current result's
/// "current context is navigation source". `sender` carries the uploads:
/// the navigable's active Window. Reports that cannot be made are dropped:
/// a report is never a reason to fail a navigation.
pub fn queueNavigationReports(
    sender: *runtime.Instance,
    reports: opener_policy.Reports,
    response: Side,
    current: Side,
    referrer: ?[]const u8,
    current_is_navigation_source: bool,
) void {
    if (reports.enforce) queueFor(sender, .enforce, response, current, referrer, current_is_navigation_source) catch {};
    if (reports.reporting) queueFor(sender, .reporting, response, current, referrer, current_is_navigation_source) catch {};
}

fn queueFor(
    sender: *runtime.Instance,
    disposition: opener_policy.Disposition,
    response: Side,
    current: Side,
    referrer: ?[]const u8,
    current_is_navigation_source: bool,
) !void {
    const allocator = sender.ctx.allocator;
    // 4.2.1 / 5.2.1: to the response, from the current result's url.
    if (try opener_policy.navigationToResponseReport(allocator, response.policy, disposition, current.url, response.origin, current.origin, referrer)) |report| {
        defer allocator.free(report.body_json);
        // Step 7: "Queue body as "coop" for coop's reporting endpoint with
        // coopURL."
        try queue(sender, response, report);
    }
    // 4.2.2 / 5.2.2: from the current result, to the response's URL.
    if (try opener_policy.navigationFromResponseReport(allocator, current.policy, disposition, response.url, current.origin, response.origin, current_is_navigation_source)) |report| {
        defer allocator.free(report.body_json);
        // Step 5.
        try queue(sender, current, report);
    }
}

fn queue(sender: *runtime.Instance, side: Side, report: opener_policy.NavigationReport) !void {
    try reporting.queueForEndpoint(sender, .{
        .type = "coop",
        .url = side.url,
        .destination = report.endpoint,
        .body_json = report.body_json,
        .endpoints = side.endpoints,
        // The navigation report's document is being navigated away from.
        .kept = true,
    });
}
