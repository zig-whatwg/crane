//! CSP 4.2.4 "Should navigation request of type be blocked by Content
//! Security Policy?", over a navigation request's policy container's CSP
//! list: the directives' pre-navigation checks (form-action's, 6.4.1.1) and,
//! for a javascript: URL, the inline check of the directive §6.8.4 picks
//! for type "navigation" (script-src-elem, else script-src, else
//! default-src) with the URL as the source - a nonce never matches it, a
//! hash does only under 'unsafe-hashes'.
//!
//! Trusted Types' require-trusted-types-for has a pre-navigation check too
//! (TT 4.2.1.1); it runs the default policy, which is script, so it is the
//! global's (dom.trusted_types.javascriptUrlPreNavigationCheck).
//!
//! Spec: https://w3c.github.io/webappsec-csp/#should-block-navigation-request

const std = @import("std");
const types = @import("types.zig");
const matching = @import("matching.zig");
const inline_check = @import("inline_check.zig");
const request_check = @import("request_check.zig");
const violation_events = @import("violation_events.zig");

pub const Result = enum { allowed, blocked };

/// 4.2.4's type.
pub const NavigationType = enum { form_submission, other };

/// A navigation request as 4.2.4 reads it.
pub const NavigationRequest = struct {
    /// Its current URL, as source matching reads it.
    url: request_check.Url,
    /// Its current URL, serialized: the javascript: check's source, and a
    /// pre-navigation violation's resource.
    serialized_url: []const u8,
    redirect_count: u32 = 0,

    /// The request for the serialized URL `serialized` (BORROWED: the
    /// request's parts are slices of it).
    pub fn ofSerialized(serialized: []const u8) NavigationRequest {
        return .{ .url = request_check.Url.ofSerialized(serialized), .serialized_url = serialized };
    }
};

/// 4.2.4 for `request` of `navigation_type` under `csp_list` - the request's
/// policy container's. Each violation goes to `reporter`, the request's
/// client's global's (null: none is reported).
///
/// Steps 2-3 here are the pre-navigation checks this module holds
/// (form-action's). require-trusted-types-for's runs the default policy -
/// script - so a caller with a global runs it first and continues with
/// `preNavigationChecks` and `javascriptUrlInlineChecks`
/// (dom.csp_violations.shouldJavascriptNavigationBeBlocked).
pub fn shouldNavigationRequestBeBlocked(
    csp_list: *const types.CSPList,
    request: NavigationRequest,
    navigation_type: NavigationType,
    reporter: ?violation_events.Reporter,
) Result {
    // 1-3.
    const result = preNavigationChecks(csp_list, request, navigation_type, reporter);
    // 4. "If result is "Allowed", and if navigation request's current URL's
    // scheme is javascript".
    if (result == .blocked) return .blocked;
    // 5. Return result.
    return javascriptUrlInlineChecks(csp_list, request, reporter);
}

/// 4.2.4 steps 1-3 with form-action's pre-navigation check (6.4.1.1), the
/// one directive here that has one: "Blocked" when an enforced policy's
/// check fails, each failing policy reported.
pub fn preNavigationChecks(
    csp_list: *const types.CSPList,
    request: NavigationRequest,
    navigation_type: NavigationType,
    reporter: ?violation_events.Reporter,
) Result {
    // 1. Let result be "Allowed".
    var result: Result = .allowed;
    // 2-3. For each policy, each directive's pre-navigation check.
    for (csp_list.policies.items) |*policy| {
        // form-action's (6.4.1.1): "If navigation type is
        // "form-submission"" and "Does request match source list?" with
        // its value and the self-origin is "Does Not Match": Blocked.
        if (navigation_type != .form_submission) continue;
        const directive = policy.getDirective("form-action") orelse continue;
        const self_origin: ?*const types.Origin = if (policy.self_origin) |*o| o else if (csp_list.self_origin) |*o| o else null;
        if (matching.doesUrlMatchSourceList(
            request.url.scheme,
            request.url.host orelse "",
            request.url.port,
            request.url.path,
            &directive.value,
            self_origin,
            request.redirect_count,
        )) continue;
        // 3.1.2-3.1.4. A violation of the directive, its resource the
        // request's URL.
        if (reporter) |r| r.reportViolation(&.{
            .policy = policy,
            .effective_directive = directive.name,
            .resource = .{ .url = request.serialized_url },
        });
        // 3.1.5.
        if (policy.disposition == .enforce) result = .blocked;
    }
    return result;
}

/// 4.2.4 step 4, for a result still "Allowed": a javascript: URL is checked
/// by each policy's inline check of type "navigation"; any other URL is
/// Allowed.
pub fn javascriptUrlInlineChecks(
    csp_list: *const types.CSPList,
    request: NavigationRequest,
    reporter: ?violation_events.Reporter,
) Result {
    if (!std.ascii.eqlIgnoreCase(request.url.scheme, "javascript")) return .allowed;
    var result: Result = .allowed;
    for (csp_list.policies.items) |*policy| {
        // 4.1.1.1-4.1.1.2. The inline check upon null, "navigation",
        // policy and the URL; only the directive §6.8.4 picks runs.
        const directive = inline_check.blockingDirective(policy, .{}, .navigation, request.serialized_url) orelse continue;
        // 4.1.1.3-4.1.1.5. A violation of the effective directive for
        // inline checks, its resource "inline". The sample - the URL's
        // first 40 characters under 'report-sample' - is not in 4.2.4;
        // Blink sets it, and WPT reads it
        // (securitypolicyviolation/script-sample.html: "javascript:'inline
        // url'").
        if (reporter) |r| r.reportViolation(&.{
            .policy = policy,
            .effective_directive = inline_check.effectiveDirectiveForInlineCheck(.navigation),
            .resource = .@"inline",
            .sample = violation_events.sampleFor(directive, request.serialized_url),
        });
        // 4.1.1.6.
        if (policy.disposition == .enforce) result = .blocked;
    }
    return result;
}

const testing = std.testing;
const parsing = @import("parsing.zig");

const Seen = struct {
    count: usize = 0,
    directive: []const u8 = "",
    inline_resource: bool = false,
    url_buffer: [128]u8 = undefined,
    url_len: usize = 0,
    sample_buffer: [64]u8 = undefined,
    sample_len: usize = 0,

    fn reporter(self: *Seen) violation_events.Reporter {
        return .{ .context = self, .report = &record };
    }

    fn record(context: *anyopaque, violation: *const violation_events.Violation) void {
        const self: *Seen = @ptrCast(@alignCast(context));
        self.count += 1;
        self.directive = violation.effective_directive;
        switch (violation.resource) {
            .url => |u| {
                self.inline_resource = false;
                self.url_len = @min(u.len, self.url_buffer.len);
                @memcpy(self.url_buffer[0..self.url_len], u[0..self.url_len]);
            },
            .@"inline" => self.inline_resource = true,
            else => {},
        }
        self.sample_len = @min(violation.sample.len, self.sample_buffer.len);
        @memcpy(self.sample_buffer[0..self.sample_len], violation.sample[0..self.sample_len]);
    }
};

fn listOf(serialized: []const u8, disposition: types.PolicyDisposition) !types.CSPList {
    var list = types.CSPList.init(testing.allocator);
    errdefer list.deinit();
    try list.append(try parsing.parseSerializedCSP(testing.allocator, serialized, .meta, disposition));
    return list;
}

fn javascriptRequest(url: []const u8) NavigationRequest {
    return .{ .url = .{ .scheme = "javascript", .path = url["javascript:".len..] }, .serialized_url = url };
}

test "4.2.4 step 4: a javascript: URL is blocked by script-src without 'unsafe-inline', reported as inline script-src-elem with a sample" {
    var list = try listOf("script-src 'nonce-abc' 'report-sample'", .enforce);
    defer list.deinit();
    var seen: Seen = .{};
    try testing.expectEqual(Result.blocked, shouldNavigationRequestBeBlocked(&list, javascriptRequest("javascript:'inline url'"), .other, seen.reporter()));
    try testing.expectEqual(@as(usize, 1), seen.count);
    try testing.expectEqualStrings("script-src-elem", seen.directive);
    try testing.expect(seen.inline_resource);
    try testing.expectEqualStrings("javascript:'inline url'", seen.sample_buffer[0..seen.sample_len]);

    var inline_allowed = try listOf("script-src 'unsafe-inline'", .enforce);
    defer inline_allowed.deinit();
    try testing.expectEqual(Result.allowed, shouldNavigationRequestBeBlocked(&inline_allowed, javascriptRequest("javascript:void 0"), .other, null));
}

test "4.2.4 step 4: a hash of the whole URL allows it only with 'unsafe-hashes'" {
    // sha256("javascript:navigated();")
    var with = try listOf("script-src 'unsafe-hashes' 'nonce-abc' 'sha256-l0Wxf12cHMZT6UQ2zsQ7AcFSb6Y198d37Ki8zWITecM='", .enforce);
    defer with.deinit();
    try testing.expectEqual(Result.allowed, shouldNavigationRequestBeBlocked(&with, javascriptRequest("javascript:navigated();"), .other, null));
    try testing.expectEqual(Result.blocked, shouldNavigationRequestBeBlocked(&with, javascriptRequest("javascript:other();"), .other, null));
    var without = try listOf("script-src 'nonce-abc' 'sha256-l0Wxf12cHMZT6UQ2zsQ7AcFSb6Y198d37Ki8zWITecM='", .enforce);
    defer without.deinit();
    try testing.expectEqual(Result.blocked, shouldNavigationRequestBeBlocked(&without, javascriptRequest("javascript:navigated();"), .other, null));
}

test "4.2.4: a monitored policy reports a javascript: URL and allows it; other schemes are not inline-checked" {
    var list = try listOf("script-src 'none'", .report);
    defer list.deinit();
    var seen: Seen = .{};
    try testing.expectEqual(Result.allowed, shouldNavigationRequestBeBlocked(&list, javascriptRequest("javascript:1"), .other, seen.reporter()));
    try testing.expectEqual(@as(usize, 1), seen.count);
    var enforced = try listOf("script-src 'none'", .enforce);
    defer enforced.deinit();
    const https: NavigationRequest = .{ .url = .{ .scheme = "https", .host = "a.test", .path = "/" }, .serialized_url = "https://a.test/" };
    try testing.expectEqual(Result.allowed, shouldNavigationRequestBeBlocked(&enforced, https, .other, null));
}

test "4.2.4 step 3: form-action blocks a form submission whose URL it does not match, and only a form submission" {
    var list = try listOf("form-action https://allowed.test", .enforce);
    defer list.deinit();
    var seen: Seen = .{};
    const other: NavigationRequest = .{ .url = .{ .scheme = "https", .host = "other.test", .path = "/submit" }, .serialized_url = "https://other.test/submit" };
    try testing.expectEqual(Result.blocked, shouldNavigationRequestBeBlocked(&list, other, .form_submission, seen.reporter()));
    try testing.expectEqualStrings("form-action", seen.directive);
    try testing.expectEqualStrings("https://other.test/submit", seen.url_buffer[0..seen.url_len]);
    try testing.expectEqual(Result.allowed, shouldNavigationRequestBeBlocked(&list, other, .other, null));
    const allowed: NavigationRequest = .{ .url = .{ .scheme = "https", .host = "allowed.test", .path = "/x" }, .serialized_url = "https://allowed.test/x" };
    try testing.expectEqual(Result.allowed, shouldNavigationRequestBeBlocked(&list, allowed, .form_submission, null));
}

test "NavigationRequest.ofSerialized: the parts source matching reads" {
    const js = NavigationRequest.ofSerialized("javascript:void(0)");
    try testing.expectEqualStrings("javascript", js.url.scheme);
    try testing.expect(js.url.host == null);
    try testing.expectEqualStrings("void(0)", js.url.path);
    try testing.expectEqualStrings("javascript:void(0)", js.serialized_url);
    const https = NavigationRequest.ofSerialized("https://user@a.test:8443/p/q?x=1#f");
    try testing.expectEqualStrings("https", https.url.scheme);
    try testing.expectEqualStrings("a.test", https.url.host.?);
    try testing.expectEqual(@as(?u16, 8443), https.url.port);
    try testing.expectEqualStrings("/p/q", https.url.path);
}

test "4.2.4 steps 1-3 alone: form-action's pre-navigation check, no javascript: inline check" {
    var list = try listOf("form-action 'none'; script-src 'none'", .enforce);
    defer list.deinit();
    var seen: Seen = .{};
    // A form submission to a javascript: URL: form-action's violation, the
    // resource its URL - and step 4 is not this function's.
    try testing.expectEqual(Result.blocked, preNavigationChecks(&list, NavigationRequest.ofSerialized("javascript:void(0)"), .form_submission, seen.reporter()));
    try testing.expectEqual(@as(usize, 1), seen.count);
    try testing.expectEqualStrings("form-action", seen.directive);
    try testing.expect(!seen.inline_resource);
    // An anchor's navigation is not a form submission: form-action does not
    // apply.
    seen = .{};
    try testing.expectEqual(Result.allowed, preNavigationChecks(&list, NavigationRequest.ofSerialized("javascript:void(0)"), .other, seen.reporter()));
    try testing.expectEqual(@as(usize, 0), seen.count);
}

test "4.2.4 step 4 alone: the javascript: URL's inline check, whatever the navigation type" {
    var list = try listOf("form-action 'none'; script-src 'none'", .enforce);
    defer list.deinit();
    var seen: Seen = .{};
    try testing.expectEqual(Result.blocked, javascriptUrlInlineChecks(&list, NavigationRequest.ofSerialized("javascript:void(0)"), seen.reporter()));
    try testing.expectEqual(@as(usize, 1), seen.count);
    try testing.expectEqualStrings("script-src-elem", seen.directive);
    try testing.expect(seen.inline_resource);
    // Not a javascript: URL: nothing to check.
    try testing.expectEqual(Result.allowed, javascriptUrlInlineChecks(&list, NavigationRequest.ofSerialized("https://a.test/"), null));
}

test "4.2.4: a form submission blocked by form-action skips step 4 - one violation, form-action's" {
    var list = try listOf("form-action 'none'; script-src 'none'", .enforce);
    defer list.deinit();
    var seen: Seen = .{};
    try testing.expectEqual(Result.blocked, shouldNavigationRequestBeBlocked(&list, NavigationRequest.ofSerialized("javascript:void(0)"), .form_submission, seen.reporter()));
    try testing.expectEqual(@as(usize, 1), seen.count);
    try testing.expectEqualStrings("form-action", seen.directive);
    // As an anchor's navigation it reaches step 4: script-src-elem's.
    seen = .{};
    try testing.expectEqual(Result.blocked, shouldNavigationRequestBeBlocked(&list, NavigationRequest.ofSerialized("javascript:void(0)"), .other, seen.reporter()));
    try testing.expectEqual(@as(usize, 1), seen.count);
    try testing.expectEqualStrings("script-src-elem", seen.directive);
}
