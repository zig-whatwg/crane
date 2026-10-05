//! CSP §6.1.9 object-src, for plugin content without a URL: "If plugin
//! content is loaded without an associated URL (perhaps an object element
//! lacks a data attribute, but loads some default plugin based on the
//! specified type), it MUST be blocked if object-src's value is 'none', but
//! will otherwise be allowed."
//!
//! There is no request to run object-src's pre-request check on, so the rule
//! is read off each policy: the directive §6.8.4 "should fetch directive
//! execute" picks for object-src - object-src, else default-src (its
//! fallback list, §6.8.3) - whose value is 'none', or an empty source list
//! (which matches nothing either), blocks. Each such policy reports a
//! violation of object-src - its resource the empty URL, there being none -
//! and blocks when it is enforced; a monitored one reports and allows.
//!
//! Blink applies the same rule (an empty URL is allowed by every source
//! list but 'none'): its object element's CSP check for a plugin with no
//! URL. The element - an object or embed element whose type would select a
//! plugin - is its caller's (src/html/embedded_content.zig).
//!
//! Spec: https://w3c.github.io/webappsec-csp/#directive-object-src

const std = @import("std");
const types = @import("types.zig");
const violation_events = @import("violation_events.zig");

pub const Result = enum { allowed, blocked };

/// The directive object-src's checks read in `policy`: object-src, else
/// default-src.
fn objectSrcDirective(policy: *const types.Policy) ?*const types.Directive {
    if (policy.getDirective("object-src")) |directive| return directive;
    return policy.getDirective("default-src");
}

/// Whether plugin content without a URL is blocked by `csp_list` (the
/// element's node document's). Every violation goes to `reporter` (null:
/// none is reported), carrying `element` (opaque here: the reporter's
/// `*runtime.Instance`).
pub fn shouldPluginContentWithoutUrlBeBlocked(
    csp_list: *const types.CSPList,
    reporter: ?violation_events.Reporter,
    element: ?*anyopaque,
) Result {
    var result: Result = .allowed;
    for (csp_list.policies.items) |*policy| {
        const directive = objectSrcDirective(policy) orelse continue;
        // "it MUST be blocked if object-src's value is 'none'". An empty
        // source list matches nothing, as 'none' does.
        if (!directive.value.isNone() and !directive.value.isEmpty()) continue;
        if (reporter) |r| r.reportViolation(&.{
            .policy = policy,
            .effective_directive = "object-src",
            .resource = .{ .url = "" },
            .element = element,
        });
        if (policy.disposition == .enforce) result = .blocked;
    }
    return result;
}

const testing = std.testing;
const parsing = @import("parsing.zig");

const Seen = struct {
    count: usize = 0,
    directive: []const u8 = "",
    disposition: types.PolicyDisposition = .enforce,

    fn reporter(self: *Seen) violation_events.Reporter {
        return .{ .context = self, .report = &record };
    }

    fn record(context: *anyopaque, violation: *const violation_events.Violation) void {
        const self: *Seen = @ptrCast(@alignCast(context));
        self.count += 1;
        self.directive = violation.effective_directive;
        self.disposition = violation.policy.disposition;
    }
};

fn listOf(policies: []const struct { []const u8, types.PolicyDisposition }) !types.CSPList {
    var list = types.CSPList.init(testing.allocator);
    errdefer list.deinit();
    for (policies) |p| try list.append(try parsing.parseSerializedCSP(testing.allocator, p[0], .header, p[1]));
    return list;
}

test "object-src 'none' and an empty object-src block plugin content without a URL, and report object-src" {
    for ([_][]const u8{ "object-src 'none'; script-src 'self' 'unsafe-inline'", "object-src; script-src 'self' 'unsafe-inline'", "default-src 'none'" }) |serialized| {
        var list = try listOf(&.{.{ serialized, .enforce }});
        defer list.deinit();
        var seen: Seen = .{};
        try testing.expectEqual(Result.blocked, shouldPluginContentWithoutUrlBeBlocked(&list, seen.reporter(), null));
        try testing.expectEqual(@as(usize, 1), seen.count);
        try testing.expectEqualStrings("object-src", seen.directive);
    }
}

test "any other source list allows it, object-src overrides default-src, and no policy allows" {
    for ([_][]const u8{ "object-src 'self'", "object-src *", "default-src 'none'; object-src 'self'", "script-src 'none'" }) |serialized| {
        var list = try listOf(&.{.{ serialized, .enforce }});
        defer list.deinit();
        var seen: Seen = .{};
        try testing.expectEqual(Result.allowed, shouldPluginContentWithoutUrlBeBlocked(&list, seen.reporter(), null));
        try testing.expectEqual(@as(usize, 0), seen.count);
    }
    var empty = types.CSPList.init(testing.allocator);
    defer empty.deinit();
    try testing.expectEqual(Result.allowed, shouldPluginContentWithoutUrlBeBlocked(&empty, null, null));
}

test "a monitored policy reports and allows" {
    var list = try listOf(&.{.{ "object-src 'none'", .report }});
    defer list.deinit();
    var seen: Seen = .{};
    try testing.expectEqual(Result.allowed, shouldPluginContentWithoutUrlBeBlocked(&list, seen.reporter(), null));
    try testing.expectEqual(@as(usize, 1), seen.count);
    try testing.expectEqual(types.PolicyDisposition.report, seen.disposition);
}
