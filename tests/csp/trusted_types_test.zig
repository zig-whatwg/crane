//! The Trusted Types CSP directives (Trusted Types 4.2): `trusted-types` and
//! `require-trusted-types-for`, and the three algorithms that read them -
//! "does sink type require trusted types?" (4.2.3), "should sink type
//! mismatch violation be blocked by CSP?" (4.2.4) and "should Trusted Type
//! policy creation be blocked by CSP?" (4.2.5) - with the violations they
//! report.

const std = @import("std");
const testing = std.testing;
const csp = @import("csp");
const types = csp.types;
const tt = csp.directives.trusted_types;
const rtt = csp.directives.require_trusted_types;
const Violation = csp.violation_events.Violation;

/// A CSP list parsed from `(serialized, disposition)` pairs, as delivery
/// makes one.
fn listOf(allocator: std.mem.Allocator, policies: []const struct { []const u8, types.PolicyDisposition }) !types.CSPList {
    var list = types.CSPList.init(allocator);
    errdefer list.deinit();
    for (policies) |p| {
        const policy = try csp.parsing.parseSerializedCSP(allocator, p[0], .meta, p[1]);
        try list.append(policy);
    }
    return list;
}

/// Records what is reported, copied.
const Recorder = struct {
    allocator: std.mem.Allocator,
    directives: std.ArrayListUnmanaged([]u8) = .empty,
    samples: std.ArrayListUnmanaged([]u8) = .empty,
    resources: std.ArrayListUnmanaged([]const u8) = .empty,
    dispositions: std.ArrayListUnmanaged(types.PolicyDisposition) = .empty,

    fn deinit(self: *Recorder) void {
        for (self.directives.items) |d| self.allocator.free(d);
        for (self.samples.items) |s| self.allocator.free(s);
        self.directives.deinit(self.allocator);
        self.samples.deinit(self.allocator);
        self.resources.deinit(self.allocator);
        self.dispositions.deinit(self.allocator);
    }

    fn reporter(self: *Recorder) csp.violation_events.Reporter {
        return .{ .context = self, .report = &record };
    }

    fn record(context: *anyopaque, violation: *const Violation) void {
        const self: *Recorder = @ptrCast(@alignCast(context));
        self.directives.append(self.allocator, self.allocator.dupe(u8, violation.effective_directive) catch unreachable) catch unreachable;
        self.samples.append(self.allocator, self.allocator.dupe(u8, violation.sample) catch unreachable) catch unreachable;
        self.resources.append(self.allocator, violation.resource.keyword()) catch unreachable;
        self.dispositions.append(self.allocator, violation.policy.disposition) catch unreachable;
    }
};

fn creation(list: *const types.CSPList, name: []const u8, created: []const []const u8) tt.Result {
    return tt.shouldPolicyCreationBeBlocked(list, name, created, null);
}

// ============================================================================
// 4.2.5 Should Trusted Type policy creation be blocked by CSP?
// ============================================================================

test "no trusted-types directive: every name, duplicates too" {
    var list = try listOf(testing.allocator, &.{.{ "script-src 'self'", .enforce }});
    defer list.deinit();
    try testing.expectEqual(tt.Result.allowed, creation(&list, "foo", &.{}));
    try testing.expectEqual(tt.Result.allowed, creation(&list, "foo", &.{"foo"}));
}

test "named policies: listed names once each; others, and repeats, blocked" {
    var list = try listOf(testing.allocator, &.{.{ "trusted-types foo bar", .enforce }});
    defer list.deinit();
    try testing.expectEqual(tt.Result.allowed, creation(&list, "foo", &.{}));
    try testing.expectEqual(tt.Result.allowed, creation(&list, "bar", &.{"foo"}));
    try testing.expectEqual(tt.Result.blocked, creation(&list, "baz", &.{}));
    try testing.expectEqual(tt.Result.blocked, creation(&list, "foo", &.{"foo"}));
    // Names are case-sensitive.
    try testing.expectEqual(tt.Result.blocked, creation(&list, "Foo", &.{}));
}

test "the wildcard allows any unique name; 'allow-duplicates' (any case) allows repeats" {
    var unique = try listOf(testing.allocator, &.{.{ "trusted-types *", .enforce }});
    defer unique.deinit();
    try testing.expectEqual(tt.Result.allowed, creation(&unique, "anything", &.{}));
    try testing.expectEqual(tt.Result.blocked, creation(&unique, "anything", &.{"anything"}));

    var dupes = try listOf(testing.allocator, &.{.{ "trusted-types * 'aLLow-dUPLIcates'", .enforce }});
    defer dupes.deinit();
    try testing.expectEqual(tt.Result.allowed, creation(&dupes, "SomeName", &.{"SomeName"}));
}

test "'none', an empty value, and a value with no valid expression block everything" {
    for ([_][]const u8{ "trusted-types 'none'", "trusted-types 'nONe'", "trusted-types", "trusted-types *X", "trusted-types 'none' *X" }) |serialized| {
        var list = try listOf(testing.allocator, &.{.{ serialized, .enforce }});
        defer list.deinit();
        try testing.expectEqual(tt.Result.blocked, creation(&list, "policy", &.{}));
        try testing.expectEqual(tt.Result.blocked, creation(&list, "default", &.{}));
    }
}

test "'none' beside other expressions is ignored" {
    var list = try listOf(testing.allocator, &.{.{ "trusted-types * 'none' 'allow-duplicates'", .enforce }});
    defer list.deinit();
    try testing.expectEqual(tt.Result.allowed, creation(&list, "SomeName", &.{"SomeName"}));
    var named = try listOf(testing.allocator, &.{.{ "trusted-types 'none' foo", .enforce }});
    defer named.deinit();
    try testing.expectEqual(tt.Result.allowed, creation(&named, "foo", &.{}));
}

test "a name with characters outside tt-policy-name never matches a listed token" {
    var list = try listOf(testing.allocator, &.{.{ "trusted-types a#b=c_d/e@f.g%h-i", .enforce }});
    defer list.deinit();
    try testing.expectEqual(tt.Result.allowed, creation(&list, "a#b=c_d/e@f.g%h-i", &.{}));
    var odd = try listOf(testing.allocator, &.{.{ "trusted-types a!b", .enforce }});
    defer odd.deinit();
    try testing.expectEqual(tt.Result.blocked, creation(&odd, "a!b", &.{}));
}

test "a report-only policy reports but does not block; every violating policy reports" {
    var list = try listOf(testing.allocator, &.{
        .{ "trusted-types one", .report },
        .{ "trusted-types two", .enforce },
        .{ "trusted-types *", .report },
    });
    defer list.deinit();
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();

    // "two": only the report-only "one" policy objects.
    try testing.expectEqual(tt.Result.allowed, tt.shouldPolicyCreationBeBlocked(&list, "two", &.{}, recorder.reporter()));
    try testing.expectEqual(@as(usize, 1), recorder.directives.items.len);
    try testing.expectEqual(types.PolicyDisposition.report, recorder.dispositions.items[0]);
    try testing.expectEqualStrings("trusted-types", recorder.directives.items[0]);
    try testing.expectEqualStrings("trusted-types-policy", recorder.resources.items[0]);
    try testing.expectEqualStrings("two", recorder.samples.items[0]);

    // "three": both named policies object; the enforced one blocks.
    try testing.expectEqual(tt.Result.blocked, tt.shouldPolicyCreationBeBlocked(&list, "three", &.{}, recorder.reporter()));
    try testing.expectEqual(@as(usize, 3), recorder.directives.items.len);
}

test "the policy-creation sample is the name's first 40 characters" {
    var list = try listOf(testing.allocator, &.{.{ "trusted-types 'none'", .enforce }});
    defer list.deinit();
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    const name = "a-policy-name-that-is-much-longer-than-forty-characters";
    _ = tt.shouldPolicyCreationBeBlocked(&list, name, &.{}, recorder.reporter());
    try testing.expectEqualStrings(name[0..40], recorder.samples.items[0]);
}

// ============================================================================
// 4.2.3 Does sink type require trusted types?
// ============================================================================

test "require-trusted-types-for 'script' (any case) requires for the 'script' group" {
    var enforced = try listOf(testing.allocator, &.{.{ "require-trusted-types-for 'ScRiPt'", .enforce }});
    defer enforced.deinit();
    try testing.expect(rtt.doesSinkTypeRequireTrustedTypes(&enforced, "'script'", false));
    try testing.expect(rtt.doesSinkTypeRequireTrustedTypes(&enforced, "'script'", true));

    var report_only = try listOf(testing.allocator, &.{.{ "require-trusted-types-for 'script'", .report }});
    defer report_only.deinit();
    try testing.expect(!rtt.doesSinkTypeRequireTrustedTypes(&report_only, "'script'", false));
    try testing.expect(rtt.doesSinkTypeRequireTrustedTypes(&report_only, "'script'", true));

    var other = try listOf(testing.allocator, &.{.{ "require-trusted-types-for 'style'; trusted-types *", .enforce }});
    defer other.deinit();
    try testing.expect(!rtt.doesSinkTypeRequireTrustedTypes(&other, "'script'", true));

    var none = types.CSPList.init(testing.allocator);
    defer none.deinit();
    try testing.expect(!rtt.doesSinkTypeRequireTrustedTypes(&none, "'script'", true));
}

// ============================================================================
// 4.2.4 Should sink type mismatch violation be blocked by CSP?
// ============================================================================

test "a sink type mismatch: blocked under an enforced policy, reported with sink|sample" {
    var list = try listOf(testing.allocator, &.{
        .{ "require-trusted-types-for 'script'", .enforce },
        .{ "require-trusted-types-for 'script'", .report },
        .{ "script-src 'none'", .enforce },
    });
    defer list.deinit();
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    const result = try rtt.shouldSinkTypeMismatchViolationBeBlocked(testing.allocator, &list, "Element innerHTML", "'script'", "<b>hi</b>", recorder.reporter());
    try testing.expectEqual(rtt.Result.blocked, result);
    try testing.expectEqual(@as(usize, 2), recorder.directives.items.len);
    try testing.expectEqualStrings("require-trusted-types-for", recorder.directives.items[0]);
    try testing.expectEqualStrings("trusted-types-sink", recorder.resources.items[0]);
    try testing.expectEqualStrings("Element innerHTML|<b>hi</b>", recorder.samples.items[0]);
}

test "report-only: allowed, still reported" {
    var list = try listOf(testing.allocator, &.{.{ "require-trusted-types-for 'script'", .report }});
    defer list.deinit();
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    try testing.expectEqual(rtt.Result.allowed, try rtt.shouldSinkTypeMismatchViolationBeBlocked(testing.allocator, &list, "Document write", "'script'", "x", recorder.reporter()));
    try testing.expectEqual(@as(usize, 1), recorder.directives.items.len);
}

test "the sample: the source's first 40 characters after the sink; Function's prefix stripped" {
    var list = try listOf(testing.allocator, &.{.{ "require-trusted-types-for 'script'", .enforce }});
    defer list.deinit();
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    const long = "0123456789012345678901234567890123456789-and-more";
    _ = try rtt.shouldSinkTypeMismatchViolationBeBlocked(testing.allocator, &list, "Element innerHTML", "'script'", long, recorder.reporter());
    try testing.expectEqualStrings("Element innerHTML|" ++ long[0..40], recorder.samples.items[0]);

    _ = try rtt.shouldSinkTypeMismatchViolationBeBlocked(testing.allocator, &list, "Function", "'script'", "function anonymous(a\n) {\nreturn a\n}", recorder.reporter());
    try testing.expectEqualStrings("Function|(a\n) {\nreturn a\n}", recorder.samples.items[1]);
    _ = try rtt.shouldSinkTypeMismatchViolationBeBlocked(testing.allocator, &list, "Function", "'script'", "async function* anonymous() {}", recorder.reporter());
    try testing.expectEqualStrings("Function|() {}", recorder.samples.items[2]);
    // Only for the Function sink.
    _ = try rtt.shouldSinkTypeMismatchViolationBeBlocked(testing.allocator, &list, "eval", "'script'", "function anonymous() {}", recorder.reporter());
    try testing.expectEqualStrings("eval|function anonymous() {}", recorder.samples.items[3]);
}

test "a 40-character sample never splits a multi-byte character" {
    var list = try listOf(testing.allocator, &.{.{ "require-trusted-types-for 'script'", .enforce }});
    defer list.deinit();
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    const source = "\u{e9}" ** 50;
    _ = try rtt.shouldSinkTypeMismatchViolationBeBlocked(testing.allocator, &list, "s", "'script'", source, recorder.reporter());
    try testing.expectEqualStrings("s|" ++ "\u{e9}" ** 40, recorder.samples.items[0]);
}

test "no require-trusted-types-for for the group: allowed, nothing reported" {
    var list = try listOf(testing.allocator, &.{.{ "trusted-types *", .enforce }});
    defer list.deinit();
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    try testing.expectEqual(rtt.Result.allowed, try rtt.shouldSinkTypeMismatchViolationBeBlocked(testing.allocator, &list, "Element innerHTML", "'script'", "x", recorder.reporter()));
    try testing.expectEqual(@as(usize, 0), recorder.directives.items.len);
}
