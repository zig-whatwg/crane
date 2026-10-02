//! CSP Level 3 §4.1, Integration with Fetch: whether a request is blocked
//! (§4.1.2 "Should request be blocked by Content Security Policy?") and which
//! report-only policies it violates (§4.1.1), from the fetch directives'
//! pre-request checks (§6.1, §6.2.2, §6.7.1.1) and the directive algorithms
//! of §6.8.
//!
//! Fetch knows requests and CSP knows policies, so a request is handed over
//! as the parts these algorithms read: its current URL's parts, destination,
//! initiator, redirect count, nonce, integrity metadata and parser metadata.
//!
//! Spec: https://w3c.github.io/webappsec-csp/#should-block-request

const std = @import("std");
const types = @import("types.zig");
const matching = @import("matching.zig");

/// A URL as source matching reads it.
pub const Url = struct {
    /// The scheme, without ':'.
    scheme: []const u8,
    /// The host, serialized; null for a URL with none (data:, blob:, ...).
    host: ?[]const u8 = null,
    /// The port; null for the scheme's default (or none).
    port: ?u16 = null,
    /// The path, serialized.
    path: []const u8 = "",
};

/// A request, as the pre-request checks read it.
pub const Request = struct {
    /// Its current URL.
    url: Url,
    /// Its destination, as Fetch spells it ("" for the empty string).
    destination: []const u8 = "",
    /// Its initiator, as Fetch spells it.
    initiator: []const u8 = "",
    /// Its redirect count.
    redirect_count: u32 = 0,
    /// Its cryptographic nonce metadata.
    nonce: []const u8 = "",
    /// Its parser metadata is "parser-inserted".
    parser_inserted: bool = false,
};

/// A violation the caller reports (§5.5): the policy, the violated
/// directive's name and the request's effective directive.
pub const Violation = struct {
    policy: *const types.Policy,
    directive: []const u8,
    effective_directive: []const u8,
};

/// What the caller does with each violation: report it (§5.5). Optional.
pub const Reporter = struct {
    context: *anyopaque,
    report: *const fn (context: *anyopaque, violation: Violation) void,
};

pub const Result = enum { allowed, blocked };

/// §4.1.2 Should request be blocked by Content Security Policy?
pub fn shouldRequestBeBlocked(csp_list: *const types.CSPList, request: Request, reporter: ?Reporter) Result {
    // 1-2. Let CSP list be request's policy container's CSP list; result is
    // "Allowed".
    var result: Result = .allowed;
    // 3. For each policy of CSP list:
    for (csp_list.policies.items) |*policy| {
        // 3.1. A report-only policy is skipped.
        if (policy.disposition == .report) continue;
        // 3.2. Let violates be "Does request violate policy?".
        if (doesRequestViolatePolicy(request, policy)) |directive| {
            // 3.3.1. Report a violation.
            if (reporter) |r| r.report(r.context, .{ .policy = policy, .directive = directive, .effective_directive = effectiveDirective(request) orelse directive });
            // 3.3.2. Set result to "Blocked".
            result = .blocked;
        }
    }
    // 4. Return result.
    return result;
}

/// §4.1.1 Report Content Security Policy violations for request: each
/// report-only policy the request violates is reported; nothing is blocked.
pub fn reportViolationsForRequest(csp_list: *const types.CSPList, request: Request, reporter: Reporter) void {
    for (csp_list.policies.items) |*policy| {
        // 2.1. "If policy's disposition is "enforce", then skip."
        if (policy.disposition == .enforce) continue;
        if (doesRequestViolatePolicy(request, policy)) |directive| {
            reporter.report(reporter.context, .{ .policy = policy, .directive = directive, .effective_directive = effectiveDirective(request) orelse directive });
        }
    }
}

/// §6.7.2.1 Does request violate policy? The violated directive's name, or
/// null for "Does Not Violate".
pub fn doesRequestViolatePolicy(request: Request, policy: *const types.Policy) ?[]const u8 {
    // 1. A prefetch is checked as a resource hint (§6.7.2.2): against
    // default-src. Not modelled beyond that, stated.
    // 2. Let violates be "Does Not Violate".
    var violates: ?[]const u8 = null;
    // 3. For each directive of policy: its pre-request check.
    var it = policy.directive_set.items.iterator();
    while (it.next()) |entry| {
        const directive = entry.value_ptr;
        if (preRequestCheck(directive, request, policy) == .blocked) violates = directive.name;
    }
    // 4. Return violates.
    return violates;
}

/// §6.8.1 Get the effective directive for request; null for a "report"
/// destination.
pub fn effectiveDirective(request: Request) ?[]const u8 {
    // 1. A prefetch or a prerender: default-src.
    if (std.mem.eql(u8, request.initiator, "prefetch") or std.mem.eql(u8, request.initiator, "prerender")) return "default-src";
    // 2. Switch on request's destination.
    const d = request.destination;
    if (d.len == 0) return "connect-src";
    if (std.mem.eql(u8, d, "manifest")) return "manifest-src";
    if (std.mem.eql(u8, d, "object") or std.mem.eql(u8, d, "embed")) return "object-src";
    if (std.mem.eql(u8, d, "frame") or std.mem.eql(u8, d, "iframe")) return "frame-src";
    if (std.mem.eql(u8, d, "audio") or std.mem.eql(u8, d, "track") or std.mem.eql(u8, d, "video")) return "media-src";
    if (std.mem.eql(u8, d, "font")) return "font-src";
    if (std.mem.eql(u8, d, "image")) return "img-src";
    if (std.mem.eql(u8, d, "style")) return "style-src-elem";
    if (std.mem.eql(u8, d, "script") or std.mem.eql(u8, d, "xslt") or std.mem.eql(u8, d, "audioworklet") or std.mem.eql(u8, d, "paintworklet")) return "script-src-elem";
    if (std.mem.eql(u8, d, "serviceworker") or std.mem.eql(u8, d, "sharedworker") or std.mem.eql(u8, d, "worker")) return "worker-src";
    if (std.mem.eql(u8, d, "json") or std.mem.eql(u8, d, "webidentity")) return "connect-src";
    if (std.mem.eql(u8, d, "report")) return null;
    // 3. "Return connect-src."
    return "connect-src";
}

/// §6.8.3 Get fetch directive fallback list.
pub fn fallbackList(name: []const u8) []const []const u8 {
    const lists = [_]struct { name: []const u8, list: []const []const u8 }{
        .{ .name = "script-src-elem", .list = &.{ "script-src-elem", "script-src", "default-src" } },
        .{ .name = "script-src-attr", .list = &.{ "script-src-attr", "script-src", "default-src" } },
        .{ .name = "style-src-elem", .list = &.{ "style-src-elem", "style-src", "default-src" } },
        .{ .name = "style-src-attr", .list = &.{ "style-src-attr", "style-src", "default-src" } },
        .{ .name = "worker-src", .list = &.{ "worker-src", "child-src", "script-src", "default-src" } },
        .{ .name = "connect-src", .list = &.{ "connect-src", "default-src" } },
        .{ .name = "manifest-src", .list = &.{ "manifest-src", "default-src" } },
        .{ .name = "object-src", .list = &.{ "object-src", "default-src" } },
        .{ .name = "frame-src", .list = &.{ "frame-src", "child-src", "default-src" } },
        .{ .name = "media-src", .list = &.{ "media-src", "default-src" } },
        .{ .name = "font-src", .list = &.{ "font-src", "default-src" } },
        .{ .name = "img-src", .list = &.{ "img-src", "default-src" } },
    };
    for (lists) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.list;
    }
    // 2. "Return << >>."
    return &.{};
}

/// §6.8.4 Should fetch directive execute.
pub fn shouldFetchDirectiveExecute(effective_name: []const u8, directive_name: []const u8, policy: *const types.Policy) bool {
    // 1. Let directive fallback list be the fallback list of the effective
    // directive name.
    // 2. For each fallback directive: the directive executes if it is the
    // first of the list the policy has.
    for (fallbackList(effective_name)) |fallback_directive| {
        if (std.mem.eql(u8, directive_name, fallback_directive)) return true;
        if (policy.containsDirective(fallback_directive)) return false;
    }
    // 3. "Return "No"."
    return false;
}

const Check = enum { allowed, blocked };

/// The fetch directives with a pre-request check: a fetch directive
/// executes for a request whose effective directive's fallback list reaches
/// it first (§6.8.4).
fn isFetchDirective(name: []const u8) bool {
    const names = [_][]const u8{ "child-src", "connect-src", "default-src", "font-src", "frame-src", "img-src", "manifest-src", "media-src", "object-src", "script-src", "script-src-elem", "style-src", "style-src-elem", "worker-src" };
    for (names) |n| {
        if (std.mem.eql(u8, n, name)) return true;
    }
    return false;
}

/// `directive`'s pre-request check on `request` and `policy`.
fn preRequestCheck(directive: *const types.Directive, request: Request, policy: *const types.Policy) Check {
    if (!isFetchDirective(directive.name)) return .allowed;
    // 1. "Let name be the result of executing Get the effective directive
    // for request on request."
    const name = effectiveDirective(request) orelse return .allowed;
    // 2. "If the result of executing Should fetch directive execute on name,
    // <this directive> and policy is "No", return "Allowed"."
    if (!shouldFetchDirectiveExecute(name, directive.name, policy)) return .allowed;
    // child-src and default-src run "the pre-request check for the directive
    // whose name is name ... using this directive's value for the
    // comparison" (§6.1.1.1, §6.1.3.1); the other directives run their own.
    const check_name = if (std.mem.eql(u8, directive.name, "child-src") or std.mem.eql(u8, directive.name, "default-src")) name else directive.name;
    // script-src and script-src-elem: the script directives pre-request
    // check (§6.7.1.1).
    if (std.mem.eql(u8, check_name, "script-src") or std.mem.eql(u8, check_name, "script-src-elem")) {
        return scriptDirectivesPreRequestCheck(request, &directive.value, policy);
    }
    // Every other fetch directive: "If the result of executing Does request
    // match source list? on request, this directive's value, and policy, is
    // "Does Not Match", return "Blocked"." (§6.1.2.1 and the like.)
    if (!doesRequestMatchSourceList(request, &directive.value, policy)) return .blocked;
    return .allowed;
}

/// §6.7.1.1 Script directives pre-request check.
fn scriptDirectivesPreRequestCheck(request: Request, source_list: *const types.SourceList, policy: *const types.Policy) Check {
    // 1. "If request's destination is script-like":
    if (isScriptLike(request.destination)) {
        // 1.1. A nonce that matches: "Allowed".
        if (request.nonce.len > 0 and matching.doesNonceMatch(request.nonce, source_list)) return .allowed;
        // 1.2. Integrity metadata matching the source list's hashes: not
        // modelled (stated) - such a request falls through to URL matching.
        // 1.3. 'strict-dynamic': a parser-inserted request is "Blocked", any
        // other "Allowed".
        if (matching.hasStrictDynamic(source_list)) return if (request.parser_inserted) .blocked else .allowed;
        // 1.4. "If the result of executing Does request match source list?
        // on request, directive's value, and policy, is "Does Not Match",
        // return "Blocked"."
        if (!doesRequestMatchSourceList(request, source_list, policy)) return .blocked;
    }
    // 2. "Return "Allowed"."
    return .allowed;
}

/// Fetch: "A request's destination is script-like if it is
/// "audioworklet", "paintworklet", "script", "serviceworker",
/// "sharedworker", or "worker"."
fn isScriptLike(destination: []const u8) bool {
    const names = [_][]const u8{ "audioworklet", "paintworklet", "script", "serviceworker", "sharedworker", "worker" };
    for (names) |n| {
        if (std.mem.eql(u8, n, destination)) return true;
    }
    return false;
}

/// §6.7.2.5 Does request match source list? - its current URL against the
/// list, in policy's self-origin, with its redirect count.
fn doesRequestMatchSourceList(request: Request, source_list: *const types.SourceList, policy: *const types.Policy) bool {
    return matching.doesUrlMatchSourceList(request.url.scheme, request.url.host orelse "", request.url.port, request.url.path, source_list, if (policy.self_origin) |*o| o else null, request.redirect_count);
}

// ============================================================================
// Tests
// ============================================================================

const parsing = @import("parsing.zig");

fn testPolicy(serialized: []const u8, disposition: types.PolicyDisposition) !types.Policy {
    var policy = try parsing.parseSerializedCSP(std.testing.allocator, serialized, .meta, disposition);
    policy.self_origin = try types.Origin.create(std.testing.allocator, "http", "web-platform.test", 8000);
    return policy;
}

const same_origin_worker: Request = .{
    .url = .{ .scheme = "http", .host = "web-platform.test", .port = 8000, .path = "/common/security-features/subresource/worker.py" },
    .destination = "worker",
};
const data_worker: Request = .{
    .url = .{ .scheme = "data", .path = "text/javascript,import '/x.js';" },
    .destination = "worker",
};

test "worker-src 'none' blocks every worker; 'self' a data: one; '*' a data: one too" {
    var list = types.CSPList.init(std.testing.allocator);
    defer list.deinit();
    try list.append(try testPolicy("worker-src 'none'", .enforce));
    try std.testing.expectEqual(Result.blocked, shouldRequestBeBlocked(&list, same_origin_worker, null));

    var self_list = types.CSPList.init(std.testing.allocator);
    defer self_list.deinit();
    try self_list.append(try testPolicy("worker-src 'self'", .enforce));
    try std.testing.expectEqual(Result.allowed, shouldRequestBeBlocked(&self_list, same_origin_worker, null));
    try std.testing.expectEqual(Result.blocked, shouldRequestBeBlocked(&self_list, data_worker, null));

    var any_list = types.CSPList.init(std.testing.allocator);
    defer any_list.deinit();
    try any_list.append(try testPolicy("worker-src *", .enforce));
    try std.testing.expectEqual(Result.allowed, shouldRequestBeBlocked(&any_list, same_origin_worker, null));
    try std.testing.expectEqual(Result.blocked, shouldRequestBeBlocked(&any_list, data_worker, null));
}

test "a worker falls back to child-src, then script-src, then default-src - only the first present runs" {
    var list = types.CSPList.init(std.testing.allocator);
    defer list.deinit();
    // script-src governs the worker; default-src 'none' does not run.
    try list.append(try testPolicy("script-src 'self'; default-src 'none'", .enforce));
    try std.testing.expectEqual(Result.allowed, shouldRequestBeBlocked(&list, same_origin_worker, null));
    try std.testing.expectEqual(Result.blocked, shouldRequestBeBlocked(&list, data_worker, null));

    // A script request under the same policy: script-src-elem falls back to
    // script-src.
    const script: Request = .{ .url = .{ .scheme = "http", .host = "www1.web-platform.test", .port = 8000, .path = "/s.js" }, .destination = "script" };
    try std.testing.expectEqual(Result.blocked, shouldRequestBeBlocked(&list, script, null));
    // A fetch() is connect-src's, which falls back to default-src 'none'.
    const fetch_request: Request = .{ .url = .{ .scheme = "http", .host = "web-platform.test", .port = 8000, .path = "/x" } };
    try std.testing.expectEqual(Result.blocked, shouldRequestBeBlocked(&list, fetch_request, null));
}

test "a report-only policy blocks nothing; its violations are reported" {
    var list = types.CSPList.init(std.testing.allocator);
    defer list.deinit();
    try list.append(try testPolicy("worker-src 'none'", .report));
    try std.testing.expectEqual(Result.allowed, shouldRequestBeBlocked(&list, same_origin_worker, null));

    const Counter = struct {
        count: usize = 0,
        fn report(context: *anyopaque, violation: Violation) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            std.testing.expectEqualStrings("worker-src", violation.directive) catch {};
            std.testing.expectEqualStrings("worker-src", violation.effective_directive) catch {};
            self.count += 1;
        }
    };
    var counter: Counter = .{};
    reportViolationsForRequest(&list, same_origin_worker, .{ .context = &counter, .report = &Counter.report });
    try std.testing.expectEqual(@as(usize, 1), counter.count);
}

test "a nonce lets a script request through; 'strict-dynamic' blocks only a parser-inserted one" {
    var list = types.CSPList.init(std.testing.allocator);
    defer list.deinit();
    try list.append(try testPolicy("script-src 'nonce-abc' 'strict-dynamic'", .enforce));
    const cross: Url = .{ .scheme = "https", .host = "cdn.test", .path = "/s.js" };
    try std.testing.expectEqual(Result.allowed, shouldRequestBeBlocked(&list, .{ .url = cross, .destination = "script", .nonce = "abc", .parser_inserted = true }, null));
    try std.testing.expectEqual(Result.blocked, shouldRequestBeBlocked(&list, .{ .url = cross, .destination = "script", .parser_inserted = true }, null));
    try std.testing.expectEqual(Result.allowed, shouldRequestBeBlocked(&list, .{ .url = cross, .destination = "script" }, null));
}

test "the effective directive of each destination" {
    try std.testing.expectEqualStrings("worker-src", effectiveDirective(.{ .url = .{ .scheme = "http" }, .destination = "sharedworker" }).?);
    try std.testing.expectEqualStrings("script-src-elem", effectiveDirective(.{ .url = .{ .scheme = "http" }, .destination = "paintworklet" }).?);
    try std.testing.expectEqualStrings("connect-src", effectiveDirective(.{ .url = .{ .scheme = "http" } }).?);
    try std.testing.expectEqualStrings("default-src", effectiveDirective(.{ .url = .{ .scheme = "http" }, .destination = "script", .initiator = "prefetch" }).?);
    try std.testing.expect(effectiveDirective(.{ .url = .{ .scheme = "http" }, .destination = "report" }) == null);
}
