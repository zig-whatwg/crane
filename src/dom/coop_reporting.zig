//! HTML 7.1.3.3's opener policy reports, the host's half: the navigation
//! reports "enforce a response's opener policy" steps 4.2 and 5.2 queue
//! (html.navigation.opener_policy builds their bodies), queued through
//! Reporting's queue for an endpoint list with a URL and no settings object
//! (dom.reporting.queueForEndpoint) - the form CSP's response-policy
//! reports use too. Its access reports (`checkAccess`) are the engine's
//! report_window_access, as Chromium makes them. This module owns no state,
//! tasks or network operations: the accessed window's reporting state keeps
//! which accesses were reported (reporting.State.useAccessMonitor), and the
//! Browser whether any can be (`startMonitoring`).
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#reporting

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const fetch = @import("fetch");
const html_core = @import("html_core");
const reporting = @import("reporting.zig");
const global_settings = @import("global_settings.zig");
const browser_state = @import("browser_state.zig");

const opener_policy = html_core.navigation.opener_policy;
const Endpoints = fetch.internal.policy_container.Endpoints;
const BrowsingContext = html_core.BrowsingContext;

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

// ============================================================================
// Access reports (HTML 7.1.3.3 "check if an access between two browsing
// contexts should be reported"), as Chromium ships them
// ============================================================================

/// WindowRealmOptions.report_window_access [window_access_reporting]: script
/// in realm `accessor` (the incumbent realm) used `property` of `window` -
/// one of CrossOriginProperties(Window)'s members, or "indexed" / "named" /
/// "opener" (the indexed getter, the named getter, the opener setter). Only
/// queues: reports to the ReportingObserver of the accessing page and to the
/// opener policies' report-only endpoints. `host` is not read (a frame's
/// realm is made with a host that lives only while it is made); every
/// argument is borrowed for the call.
///
/// Only Chrome ships access reports (wpt.fyi 1eecaa0c30, Chrome 157 /
/// Firefox 159.0.1 / Safari 27.2: the html/cross-origin-opener-policy/
/// reporting/access-reporting/ files pass in Chrome alone; Firefox and
/// Safari make none), so this follows Chromium where it differs from HTML's
/// text (golden rule 2: a browser that does not ship the feature does not
/// count): Chromium's CrossOriginOpenerPolicyAccessReportManager installs a
/// one-shot CoopAccessMonitor (content/browser/security/coop/
/// cross_origin_opener_policy_access_report_manager.cc) on each MAIN frame's
/// window for the accesses from every other top-level document of its
/// browsing context group in another virtual browsing context group, both
/// directions; DOMWindow::ReportCoopAccess (third_party/blink/renderer/core/
/// frame/dom_window.cc) runs it on the first access from the accessing main
/// frame or an iframe same origin with it, and
/// CrossOriginOpenerPolicyReporter::QueueAccessReport (content/browser/
/// security/coop/cross_origin_opener_policy_reporter.cc) builds the
/// "coop" reports. Where HTML queues "access-to-opener" and friends with
/// `coop`'s report-only value and every relationship, Chromium's report
/// types are "access-{from-coop-page-to,to-coop-page-from}-{opener,openee,
/// other}" and its ReportingObserver report "coop-access-violation".
pub fn checkAccess(host: ?*anyopaque, accessor: runtime.Context, window: *runtime.Instance, property: []const u8) void {
    _ = host;
    checkAccessFallible(accessor, window, property) catch {};
}

/// The access reports of `bc`'s Browser start: from now on the engine asks
/// `checkAccess` about every use of a CrossOriginProperties(Window) member
/// (runtime.BrowserScope.window_access_monitored). Called when a navigation
/// gives the top-level context `bc` a new virtual browsing context group ID
/// ("obtain a browsing context to use for a navigation response" step 9.1).
///
/// Chromium installs its monitors at the same moment and finer:
/// CrossOriginOpenerPolicyAccessReportManager::InstallAccessMonitorsIfNeeded,
/// at a main frame's commit, puts a CoopAccessMonitor on each main-frame
/// window of the group in another virtual group, and only for a pair where
/// one side has an opener policy reporter; DOMWindow::ReportCoopAccess
/// returns at once for a window with none (dom_window.cc:882). Crane's
/// monitoring is coarser - the whole Browser, and for the rest of its life -
/// and misses nothing: `checkAccess` reports only between top-level contexts
/// of one group with different virtual group IDs, and those IDs part only
/// here (a new top-level context, child or popup takes its creator's, and a
/// group switch makes a new group). A Browser where no such navigation
/// happened pays for no question.
pub fn startMonitoring(bc: *BrowsingContext) void {
    const scope = browserScopeOf(bc) orelse return;
    scope.window_access_monitored.store(true, .monotonic);
}

/// `bc`'s Browser, through its active Window or, without one, through any
/// browsing context of the Browser that has one.
fn browserScopeOf(bc: *BrowsingContext) ?*runtime.BrowserScope {
    if (activeWindowScope(bc)) |scope| return scope;
    const navigables = bc.navigables orelse return null;
    for (navigables.contexts()) |other| {
        if (activeWindowScope(other)) |scope| return scope;
    }
    return null;
}

fn activeWindowScope(bc: *BrowsingContext) ?*runtime.BrowserScope {
    const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return null));
    return window.ctx.browser_scope;
}

/// One side of an access: a top-level browsing context's window, its
/// document's opener policy and where its reports go.
const AccessSide = struct {
    bc: *BrowsingContext,
    window: *runtime.Instance,
    /// Its active document's URL and serialized origin (OWNED by the
    /// window's allocator).
    url: []const u8,
    origin: []const u8,
    policy: *const opener_policy.OpenerPolicy,
    endpoints: ?*Endpoints,
    /// The URL its reports are made for: an initial about:blank document
    /// reports as its creator (OpenerPolicyReporter), any other as itself.
    report_url: []const u8,
    /// Its active document's referrer (Document.referrer). OWNED.
    referrer: []u8,

    fn of(bc: *BrowsingContext) error{OutOfMemory}!?AccessSide {
        const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return null));
        const settings = global_settings.of(window) orelse return null;
        const get = settings.policy_container orelse return null;
        const container = get(window) orelse return null;
        const url = window.ctx.documentUrl() orelse return null;
        const origin = settings.origin(window) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return null,
        };
        errdefer window.ctx.allocator.free(origin);
        const reporter = container.openerPolicyReporter();
        const referrer = try documentReferrerOf(bc, window.ctx.allocator);
        return .{
            .bc = bc,
            .window = window,
            .url = url,
            .origin = origin,
            .policy = container.openerPolicy(),
            .endpoints = if (reporter) |r| r.endpoints else container.endpoints,
            .report_url = if (reporter) |r| r.url else url,
            .referrer = referrer,
        };
    }

    fn deinit(self: *AccessSide) void {
        self.window.ctx.allocator.free(self.origin);
        self.window.ctx.allocator.free(self.referrer);
    }

    /// Chromium's CreateReporterParams: a document with an opener policy
    /// reporter - one whose opener policy names an endpoint, enforced or
    /// report-only ("endpoint_defined").
    fn reports(self: *const AccessSide) bool {
        return self.policy.reporting_endpoint != null or self.policy.report_only_reporting_endpoint != null;
    }
};

/// Which side of an opener relationship the accessed window is
/// (Chromium's CreateReporterParams, with TopLevelOpener: the top-level
/// context of the context that opened a top-level one).
const Relation = enum { accessed_is_openee, accessed_is_opener, other };

fn topLevelOpener(bc: *BrowsingContext) ?*BrowsingContext {
    const opener = bc.opener orelse return null;
    return opener.getTop();
}

fn checkAccessFallible(accessor: runtime.Context, window: *runtime.Instance, property: []const u8) !void {
    // Chromium installs its monitors on main frames' windows only.
    const accessed_bc = browser_state.browsingContextOf(window) orelse return;
    if (accessed_bc.parent != null) return;
    const accessor_window = reporting.globalOf(accessor) orelse return;
    if (!std.mem.eql(u8, accessor_window.vtable.name, "Window")) return;
    // DOMWindow::ReportCoopAccess: "A frame might be destroyed, but its
    // context can still be able to execute some code. Those accesses are
    // ignored."
    const accessor_bc = browser_state.browsingContextOf(accessor_window) orelse return;
    const accessor_top = accessor_bc.getTop();
    if (accessor_top == accessed_bc) return;
    // CollectOtherWindowForCoopAccess: another top-level document of the
    // same browsing context group, in another virtual browsing context group
    // (HTML step 8).
    if (accessor_top.virtual_group_id != accessed_bc.virtual_group_id) return;
    if (accessor_top.virtual_browsing_context_group_id == accessed_bc.virtual_browsing_context_group_id) return;

    var accessing = (try AccessSide.of(accessor_top)) orelse return;
    defer accessing.deinit();
    var accessed = (try AccessSide.of(accessed_bc)) orelse return;
    defer accessed.deinit();
    // No reporter on either side: no monitor was installed.
    if (!accessing.reports() and !accessed.reports()) return;
    // ReportCoopAccess: "Iframes are allowed to trigger reports, only when
    // they are same-origin with their top-level document"
    // (IsCrossOriginToOutermostMainFrame; HTML step 7 checks every ancestor).
    if (accessor_bc != accessor_top) {
        const settings = global_settings.of(accessor_window) orelse return;
        const origin = settings.origin(accessor_window) catch return;
        defer accessor_window.ctx.allocator.free(origin);
        if (!sameOrigin(origin, accessing.origin)) return;
    }
    const relation: Relation = if (topLevelOpener(accessed_bc) == accessor_top)
        .accessed_is_openee
    else if (topLevelOpener(accessor_top) == accessed_bc)
        .accessed_is_opener
    else
        .other;
    // The accessed window's monitors, each used once (CoopAccessMonitor:
    // "used once and destroyed. This avoids sending multiple reports for
    // the same access"); a new Window on either side is a new pair.
    const monitors = global_settings.reportingOf(window) orelse return;
    const allocator = window.ctx.allocator;
    const same_origin = sameOrigin(accessing.origin, accessed.origin);
    if (accessing.reports() and try monitors.useAccessMonitor(allocator, accessing.window, .from_coop_page)) {
        try reportAccessFromCoopPage(&accessing, &accessed, relation, same_origin, property);
    }
    if (accessed.reports() and try monitors.useAccessMonitor(allocator, accessing.window, .to_coop_page)) {
        try reportAccessToCoopPage(&accessing, &accessed, relation, same_origin, property);
    }
}

/// HTML "same origin" for two serialized origins; an opaque one ("null")
/// is same origin with nothing here (each is its own).
fn sameOrigin(a: []const u8, b: []const u8) bool {
    if (std.mem.eql(u8, a, "null") or std.mem.eql(u8, b, "null")) return false;
    return std.mem.eql(u8, a, b);
}

/// The report types (network::mojom::CoopAccessReportType, as
/// CoopAccessReportTypeToString spells them).
fn fromCoopPageType(relation: Relation) []const u8 {
    return switch (relation) {
        .accessed_is_openee => "access-from-coop-page-to-openee",
        .accessed_is_opener => "access-from-coop-page-to-opener",
        .other => "access-from-coop-page-to-other",
    };
}

fn toCoopPageType(relation: Relation) []const u8 {
    return switch (relation) {
        // The accessor opened the COOP page.
        .accessed_is_openee => "access-to-coop-page-from-opener",
        .accessed_is_opener => "access-to-coop-page-from-openee",
        .other => "access-to-coop-page-from-other",
    };
}

/// A report body's members, written in Chromium's order and with its keys
/// (cross_origin_opener_policy_reporter.cc kType ... kOtherDocumentURL).
const AccessBody = struct {
    type: []const u8,
    disposition: ?[]const u8 = null,
    effectivePolicy: ?[]const u8 = null,
    property: []const u8,
    sourceFile: ?[]const u8 = null,
    lineNumber: ?u32 = null,
    columnNumber: ?u32 = null,
    openerURL: ?[]const u8 = null,
    referrer: ?[]const u8 = null,
    openeeURL: ?[]const u8 = null,
    initialPopupURL: ?[]const u8 = null,
    otherDocumentURL: ?[]const u8 = null,
};

/// The window URL a report names: the other side's URL, sanitized, when the
/// two documents are same origin (CreateReporterParams'
/// reported_window_url); "" otherwise. OWNED.
fn reportedWindowUrl(allocator: std.mem.Allocator, side: *const AccessSide, same_origin: bool) ![]u8 {
    if (!same_origin) return allocator.dupe(u8, "");
    return opener_policy.sanitizeUrlForReport(allocator, side.url);
}

/// The openee's initial popup URL, sanitized, when the reporting document is
/// same origin with the openee's opener origin at creation (Chromium's
/// popup_creator_origin); "" otherwise. OWNED.
fn initialPopupUrl(allocator: std.mem.Allocator, reporting_side: *const AccessSide, openee: *const AccessSide) ![]u8 {
    const creator = openee.bc.opener_origin_at_creation orelse return allocator.dupe(u8, "");
    const initial = openee.bc.initial_url orelse return allocator.dupe(u8, "");
    if (!sameOrigin(creator, reporting_side.origin)) return allocator.dupe(u8, "");
    return opener_policy.sanitizeUrlForReport(allocator, initial);
}

/// An access from the COOP page (`accessing`'s): Chromium's
/// DOMWindow::ReportCoopAccess for a monitor with an access_from_coop_page
/// report type - the "coop" report to the page's report-only endpoint
/// (QueueAccessReport) and the "coop-access-violation" report queued on
/// the accessing main frame's window for its ReportingObservers.
fn reportAccessFromCoopPage(accessing: *const AccessSide, accessed: *const AccessSide, relation: Relation, same_origin: bool, property: []const u8) !void {
    const allocator = accessing.window.ctx.allocator;
    const report_type = fromCoopPageType(relation);
    const reported_url = try reportedWindowUrl(allocator, accessed, same_origin);
    defer allocator.free(reported_url);
    // "Let sourceFile, lineNumber, and columnNumber be the relevant script
    // URL and problematic position which triggered this report"
    // (CaptureSourceLocation).
    const location = engine.runningScriptLocation(accessing.window.ctx.agent orelse return, allocator) catch null;
    defer if (location) |l| l.deinit(allocator);
    const source: ?engine.ScriptLocation = if (location) |l| (if (l.url.len != 0) l else null) else null;

    if (accessing.policy.report_only_reporting_endpoint) |endpoint| {
        var body: AccessBody = .{
            .type = report_type,
            .disposition = "reporting",
            .effectivePolicy = accessing.policy.report_only_value.token(),
            .property = property,
        };
        if (source) |s| {
            body.sourceFile = s.url;
            body.lineNumber = s.line;
            body.columnNumber = s.column;
        }
        var initial: ?[]u8 = null;
        defer if (initial) |u| allocator.free(u);
        var referrer: ?[]u8 = null;
        defer if (referrer) |r| allocator.free(r);
        switch (relation) {
            .accessed_is_opener => {
                body.openerURL = reported_url;
                referrer = try opener_policy.sanitizeUrlForReport(allocator, accessing.referrer);
                body.referrer = referrer;
            },
            .accessed_is_openee => {
                body.openeeURL = reported_url;
                initial = try initialPopupUrl(allocator, accessing, accessed);
                body.initialPopupURL = initial;
            },
            .other => body.otherDocumentURL = reported_url,
        }
        try queueAccessReport(accessing, endpoint, body);
    }

    // ReportingContext::QueueReport(Report(kCoopAccessViolation, the
    // accessing main frame's document URL, CoopAccessViolationReportBody(
    // location, report_type, property, reported_window_url))).
    var observed: AccessBody = .{ .type = report_type, .property = property };
    if (source) |s| {
        observed.sourceFile = s.url;
        observed.lineNumber = s.line;
        observed.columnNumber = s.column;
    }
    switch (relation) {
        .accessed_is_opener => observed.openerURL = reported_url,
        .accessed_is_openee => observed.openeeURL = reported_url,
        .other => observed.otherDocumentURL = reported_url,
    }
    const body_json = try std.json.Stringify.valueAlloc(allocator, observed, .{ .emit_null_optional_fields = false });
    defer allocator.free(body_json);
    // No endpoint: Chromium sends this report to the observers only (the
    // "coop" report above is its network form).
    try reporting.generate(accessing.window, "coop-access-violation", "", accessing.url, body_json);
}

/// An access to the COOP page (`accessed`'s) from another window: the
/// "coop" report to the page's report-only endpoint (QueueAccessReport for
/// an access_to_coop_page type: no source location, no observer report).
fn reportAccessToCoopPage(accessing: *const AccessSide, accessed: *const AccessSide, relation: Relation, same_origin: bool, property: []const u8) !void {
    const endpoint = accessed.policy.report_only_reporting_endpoint orelse return;
    const allocator = accessed.window.ctx.allocator;
    const reported_url = try reportedWindowUrl(allocator, accessing, same_origin);
    defer allocator.free(reported_url);
    var body: AccessBody = .{
        .type = toCoopPageType(relation),
        .disposition = "reporting",
        .effectivePolicy = accessed.policy.report_only_value.token(),
        .property = property,
    };
    var initial: ?[]u8 = null;
    defer if (initial) |u| allocator.free(u);
    var referrer: ?[]u8 = null;
    defer if (referrer) |r| allocator.free(r);
    switch (relation) {
        // The accessor is the COOP page's opener.
        .accessed_is_openee => {
            body.openerURL = reported_url;
            referrer = try opener_policy.sanitizeUrlForReport(allocator, accessed.referrer);
            body.referrer = referrer;
        },
        // The accessor is the COOP page's openee.
        .accessed_is_opener => {
            body.openeeURL = reported_url;
            initial = try initialPopupUrl(allocator, accessed, accessing);
            body.initialPopupURL = initial;
        },
        .other => body.otherDocumentURL = reported_url,
    }
    try queueAccessReport(accessed, endpoint, body);
}

/// Queue `body` as "coop" for the side's report-only endpoint, with its
/// report URL (NetworkContext::QueueReport("coop", endpoint, context_url)).
fn queueAccessReport(side: *const AccessSide, endpoint: []const u8, body: AccessBody) !void {
    const allocator = side.window.ctx.allocator;
    const body_json = try std.json.Stringify.valueAlloc(allocator, body, .{ .emit_null_optional_fields = false });
    defer allocator.free(body_json);
    try reporting.queueForEndpoint(side.window, .{
        .type = "coop",
        .url = side.report_url,
        .destination = endpoint,
        .body_json = body_json,
        .endpoints = side.endpoints,
    });
}

/// The referrer of `bc`'s active document (Document.referrer: the URL of
/// the document that navigated to it, or ""). OWNED by `allocator`.
fn documentReferrerOf(bc: *BrowsingContext, allocator: std.mem.Allocator) error{OutOfMemory}![]u8 {
    const document: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveDocument() orelse return allocator.dupe(u8, "")));
    const referrer = interfaces.Document.get_referrer(document) catch return allocator.dupe(u8, "");
    // The getter's copy is the document's realm allocator's; the side's
    // strings are its window's - the same realm.
    return @constCast(referrer);
}
