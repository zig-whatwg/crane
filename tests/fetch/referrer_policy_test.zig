//! Referrer Policy (src/referrer_policy/), through the fetch module that
//! imports it: the module's own test blocks are in no test target's root
//! module, so they never run (docs/lessons/testing-a-test-block-runs-only-
//! in-a-file-the-build-collects.md). These do, under `zig build test`.

const std = @import("std");
const referrer_policy = @import("fetch").referrer_policy;

const ReferrerSource = referrer_policy.ReferrerSource;
const TargetInfo = referrer_policy.TargetInfo;

test "stripping a URL for use as a referrer drops its credentials and fragment" {
    const allocator = std.testing.allocator;
    const cases = [_][2][]const u8{
        .{ "http://user:pass@a.test:8000/p/q?x=1#frag", "http://a.test:8000/p/q?x=1" },
        .{ "http://user@a.test/p", "http://a.test/p" },
        .{ "https://a.test/p?q@x#f", "https://a.test/p?q@x" },
        .{ "https://a.test", "https://a.test" },
    };
    for (cases) |case| {
        const stripped = (try referrer_policy.stripUrlForReferrer(allocator, case[0])).?;
        defer allocator.free(stripped);
        try std.testing.expectEqualStrings(case[1], stripped);
    }
    // A local scheme is no referrer.
    try std.testing.expect((try referrer_policy.stripUrlForReferrer(allocator, "about:blank")) == null);
    try std.testing.expect((try referrer_policy.stripUrlForReferrer(allocator, "data:,x")) == null);
    try std.testing.expect((try referrer_policy.stripUrlForReferrer(allocator, "blob:https://a.test/x")) == null);
}

test "determine request's referrer: step 8, policy by policy" {
    const allocator = std.testing.allocator;
    const source: ReferrerSource = .{ .scheme = "https", .host = "a.test", .port = null, .full_url = "https://a.test/page?q" };
    const same: TargetInfo = .{ .scheme = "https", .host = "a.test", .port = null };
    const cross: TargetInfo = .{ .scheme = "https", .host = "b.test", .port = null };
    const downgrade: TargetInfo = .{ .scheme = "http", .host = "b.test", .port = null };
    const Case = struct { policy: referrer_policy.ReferrerPolicy, target: TargetInfo, same_origin: bool, want: ?[]const u8 };
    const cases = [_]Case{
        .{ .policy = .no_referrer, .target = same, .same_origin = true, .want = null },
        .{ .policy = .unsafe_url, .target = downgrade, .same_origin = false, .want = "https://a.test/page?q" },
        .{ .policy = .origin, .target = same, .same_origin = true, .want = "https://a.test/" },
        .{ .policy = .same_origin, .target = same, .same_origin = true, .want = "https://a.test/page?q" },
        .{ .policy = .same_origin, .target = cross, .same_origin = false, .want = null },
        .{ .policy = .origin_when_cross_origin, .target = cross, .same_origin = false, .want = "https://a.test/" },
        .{ .policy = .origin_when_cross_origin, .target = same, .same_origin = true, .want = "https://a.test/page?q" },
        .{ .policy = .strict_origin, .target = downgrade, .same_origin = false, .want = null },
        .{ .policy = .strict_origin, .target = cross, .same_origin = false, .want = "https://a.test/" },
        .{ .policy = .strict_origin_when_cross_origin, .target = same, .same_origin = true, .want = "https://a.test/page?q" },
        .{ .policy = .strict_origin_when_cross_origin, .target = cross, .same_origin = false, .want = "https://a.test/" },
        .{ .policy = .strict_origin_when_cross_origin, .target = downgrade, .same_origin = false, .want = null },
        .{ .policy = .no_referrer_when_downgrade, .target = downgrade, .same_origin = false, .want = null },
        .{ .policy = .no_referrer_when_downgrade, .target = cross, .same_origin = false, .want = "https://a.test/page?q" },
        // The empty policy is the default, strict-origin-when-cross-origin.
        .{ .policy = .empty, .target = cross, .same_origin = false, .want = "https://a.test/" },
    };
    for (cases) |case| {
        const got = try referrer_policy.determineReferrer(allocator, case.policy, source, case.target, case.same_origin);
        defer got.deinit(allocator);
        if (case.want) |want| {
            try std.testing.expectEqualStrings(want, got.url);
        } else {
            try std.testing.expect(got == .no_referrer);
        }
    }
}

test "determine request's referrer: step 6, a referrerURL over 4096 bytes is its origin" {
    const allocator = std.testing.allocator;
    const long = try std.mem.concat(allocator, u8, &.{ "http://a.test/", "x" ** 4100 });
    defer allocator.free(long);
    const source: ReferrerSource = .{ .scheme = "http", .host = "a.test", .port = null, .full_url = long };
    const target: TargetInfo = .{ .scheme = "http", .host = "a.test", .port = null };
    const got = try referrer_policy.determineReferrer(allocator, .unsafe_url, source, target, true);
    defer got.deinit(allocator);
    try std.testing.expectEqualStrings("http://a.test/", got.url);
}

test "a non-default port stays in the origin-only referrer" {
    const allocator = std.testing.allocator;
    const source: ReferrerSource = .{ .scheme = "http", .host = "a.test", .port = 8000, .full_url = "http://a.test:8000/p" };
    const target: TargetInfo = .{ .scheme = "http", .host = "b.test", .port = 8000 };
    const got = try referrer_policy.determineReferrer(allocator, .origin, source, target, false);
    defer got.deinit(allocator);
    try std.testing.expectEqualStrings("http://a.test:8000/", got.url);
}

test "Secure Contexts: which origins are potentially trustworthy" {
    try std.testing.expect(referrer_policy.determine_referrer.isPotentiallyTrustworthyOrigin("https", "a.test"));
    try std.testing.expect(referrer_policy.determine_referrer.isPotentiallyTrustworthyOrigin("wss", "a.test"));
    try std.testing.expect(referrer_policy.determine_referrer.isPotentiallyTrustworthyOrigin("http", "127.0.0.1"));
    try std.testing.expect(referrer_policy.determine_referrer.isPotentiallyTrustworthyOrigin("http", "127.4.5.6"));
    try std.testing.expect(referrer_policy.determine_referrer.isPotentiallyTrustworthyOrigin("http", "[::1]"));
    try std.testing.expect(referrer_policy.determine_referrer.isPotentiallyTrustworthyOrigin("http", "localhost"));
    try std.testing.expect(referrer_policy.determine_referrer.isPotentiallyTrustworthyOrigin("http", "a.localhost"));
    try std.testing.expect(!referrer_policy.determine_referrer.isPotentiallyTrustworthyOrigin("http", "127.example"));
    try std.testing.expect(!referrer_policy.determine_referrer.isPotentiallyTrustworthyOrigin("http", "web-platform.test"));
}
