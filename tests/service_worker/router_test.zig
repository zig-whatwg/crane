//! Static routing's engine-free algorithms (src/service_worker/router.zig):
//! Verify Router Condition's structural steps, Check Router Registration
//! Limit, Match Router Condition and Get Router Source - URL patterns stood in
//! for by a matcher the test answers.

const std = @import("std");
const testing = std.testing;
const sw = @import("service_worker");
const router = sw.router;
const Condition = router.Condition;
const Rule = router.Rule;

/// A test's "URL pattern": a URL suffix, matched by `endsWith`.
const Suffix = struct { text: []const u8 };

fn suffixMatches(_: ?*anyopaque, pattern: *anyopaque, url: []const u8) bool {
    const suffix: *const Suffix = @ptrCast(@alignCast(pattern));
    return std.mem.endsWith(u8, url, suffix.text);
}

const matcher: router.Matcher = .{ .matches = suffixMatches };

fn noFree(_: *anyopaque, _: std.mem.Allocator) void {}
const no_ops: router.PatternOps = .{ .free = noFree };

fn get(url: []const u8) router.RequestFacts {
    return .{ .url = url, .method = "GET", .mode = .no_cors, .destination = .empty };
}

test "Verify Router Condition: a method must be one and not forbidden; or and not stand alone; an empty condition fails" {
    var get_method = "get".*;
    try testing.expect(router.verifyCondition(&.{ .method = &get_method }));
    var bad_method = "(GET|POST)".*;
    try testing.expect(!router.verifyCondition(&.{ .method = &bad_method }));
    var forbidden = "connect".*;
    try testing.expect(!router.verifyCondition(&.{ .method = &forbidden }));
    var empty_method = "".*;
    try testing.expect(!router.verifyCondition(&.{ .method = &empty_method }));
    // An empty condition has no condition.
    try testing.expect(!router.verifyCondition(&.{}));
    try testing.expect(router.verifyCondition(&.{ .mode = .navigate }));
    try testing.expect(router.verifyCondition(&.{ .running_status = .not_running }));
    // or: alone, and each of its conditions verified.
    var script_name = "script".*;
    var inner = [_]Condition{ .{ .mode = .cors }, .{ .destination = &script_name } };
    try testing.expect(router.verifyCondition(&.{ .any_of = &inner }));
    try testing.expect(!router.verifyCondition(&.{ .any_of = &inner, .mode = .cors }));
    var bad_inner = [_]Condition{ .{ .mode = .cors }, .{} };
    try testing.expect(!router.verifyCondition(&.{ .any_of = &bad_inner }));
    // An empty or is a condition (nothing to verify in it).
    var none: [0]Condition = .{};
    try testing.expect(router.verifyCondition(&.{ .any_of = &none }));
    // not: alone, verified.
    var negated: Condition = .{ .mode = .cors };
    try testing.expect(router.verifyCondition(&.{ .not = &negated }));
    var style_name = "style".*;
    try testing.expect(!router.verifyCondition(&.{ .not = &negated, .destination = &style_name }));
    var empty_negated: Condition = .{};
    try testing.expect(!router.verifyCondition(&.{ .not = &empty_negated }));
}

test "Check Router Registration Limit: 1024 conditions in all, or and not nested at most 10 deep" {
    const a = testing.allocator;
    // 1023 single conditions fit; the 1024th empties the count.
    const rules = try a.alloc(Rule, 1024);
    defer a.free(rules);
    for (rules) |*rule| rule.* = .{ .condition = .{ .mode = .cors }, .source = .network };
    try testing.expect(router.checkRegistrationLimit(rules[0..1023]));
    try testing.expect(!router.checkRegistrationLimit(rules[0..1024]));

    // or nested: a leaf under 9 ors fits; under 10 it does not. chain[k]
    // holds 11 - k ors above its leaf, built from the leaf up.
    var chain: [12]Condition = undefined;
    var chain_lists: [12][1]Condition = undefined;
    chain[11] = .{ .mode = .cors };
    var k: usize = 11;
    while (k > 0) {
        k -= 1;
        chain_lists[k] = .{chain[k + 1]};
        chain[k] = .{ .any_of = &chain_lists[k] };
    }
    // chain[2]: 9 ors, then the leaf - 10 levels.
    try testing.expect(router.checkRegistrationLimit(&.{.{ .condition = chain[2], .source = .network }}));
    // chain[1]: 10 ors, then the leaf - 11 levels.
    try testing.expect(!router.checkRegistrationLimit(&.{.{ .condition = chain[1], .source = .network }}));

    // not nested the same way.
    var nots: [12]Condition = undefined;
    nots[11] = .{ .mode = .cors };
    k = 11;
    while (k > 0) {
        k -= 1;
        nots[k] = .{ .not = &nots[k + 1] };
    }
    try testing.expect(router.checkRegistrationLimit(&.{.{ .condition = nots[2], .source = .network }}));
    try testing.expect(!router.checkRegistrationLimit(&.{.{ .condition = nots[1], .source = .network }}));
}

test "Match Router Condition: every member must match; or any, not none; the method normalized, the running status" {
    var direct: Suffix = .{ .text = "/direct.txt" };
    try testing.expect(router.matchCondition(&.{ .url_pattern = &direct }, true, get("https://a.test/x/direct.txt"), matcher));
    try testing.expect(!router.matchCondition(&.{ .url_pattern = &direct }, true, get("https://a.test/x/other.txt"), matcher));
    // No matcher: a URL pattern matches nothing.
    try testing.expect(!router.matchCondition(&.{ .url_pattern = &direct }, true, get("https://a.test/x/direct.txt"), null));

    // A method is normalized ("post" is POST); others compare as they are.
    var post = "post".*;
    var patch = "patch".*;
    var post_request = get("https://a.test/");
    post_request.method = "POST";
    try testing.expect(router.matchCondition(&.{ .method = &post }, true, post_request, matcher));
    var patch_request = get("https://a.test/");
    patch_request.method = "PATCH";
    try testing.expect(!router.matchCondition(&.{ .method = &patch }, true, patch_request, matcher));
    patch_request.method = "patch";
    try testing.expect(router.matchCondition(&.{ .method = &patch }, true, patch_request, matcher));

    // Several members: all of them.
    var cors_post = get("https://a.test/search?test");
    cors_post.mode = .cors;
    cors_post.method = "POST";
    const several: Condition = .{ .url_pattern = &direct, .mode = .cors, .method = &post };
    try testing.expect(!router.matchCondition(&several, true, cors_post, matcher));
    var direct_cors_post = cors_post;
    direct_cors_post.url = "https://a.test/direct.txt";
    try testing.expect(router.matchCondition(&several, true, direct_cors_post, matcher));

    // Destination and running status.
    var script = get("https://a.test/a.js");
    script.destination = .script;
    var script_name = "script".*;
    var style_name = "style".*;
    var empty_name = "".*;
    try testing.expect(router.matchCondition(&.{ .destination = &script_name }, true, script, matcher));
    try testing.expect(!router.matchCondition(&.{ .destination = &style_name }, true, script, matcher));
    try testing.expect(router.matchCondition(&.{ .destination = &empty_name }, true, get("https://a.test/"), matcher));
    try testing.expect(router.matchCondition(&.{ .running_status = .running }, true, script, matcher));
    try testing.expect(!router.matchCondition(&.{ .running_status = .running }, false, script, matcher));
    try testing.expect(router.matchCondition(&.{ .running_status = .not_running }, false, script, matcher));

    // or, not.
    var one: Suffix = .{ .text = "direct1.text" };
    var two: Suffix = .{ .text = "direct2.text" };
    var either = [_]Condition{ .{ .url_pattern = &one }, .{ .url_pattern = &two } };
    try testing.expect(router.matchCondition(&.{ .any_of = &either }, true, get("https://a.test/or-test/direct2.text"), matcher));
    try testing.expect(!router.matchCondition(&.{ .any_of = &either }, true, get("https://a.test/or-test/none.text"), matcher));
    var not_txt: Suffix = .{ .text = "/not.txt" };
    var inner: Condition = .{ .url_pattern = &not_txt };
    try testing.expect(!router.matchCondition(&.{ .not = &inner }, true, get("https://a.test/not.txt"), matcher));
    try testing.expect(router.matchCondition(&.{ .not = &inner }, true, get("https://a.test/yes.txt"), matcher));
}

test "Get Router Source: the first rule that matches, in order; none: null" {
    var direct: Suffix = .{ .text = "/direct.txt" };
    var html: Suffix = .{ .text = "/direct.html" };
    const rules = [_]Rule{
        .{ .condition = .{ .url_pattern = &direct }, .source = .network },
        .{ .condition = .{ .url_pattern = &html }, .source = .{ .cache = null } },
        .{ .condition = .{ .mode = .no_cors }, .source = .fetch_event },
    };
    try testing.expect(router.getRouterSource(&rules, true, get("https://a.test/direct.txt"), matcher).?.* == .network);
    try testing.expect(router.getRouterSource(&rules, true, get("https://a.test/direct.html"), matcher).?.* == .cache);
    try testing.expect(router.getRouterSource(&rules, true, get("https://a.test/any"), matcher).?.* == .fetch_event);
    var cors = get("https://a.test/any");
    cors.mode = .cors;
    try testing.expect(router.getRouterSource(&rules, true, cors, matcher) == null);
}

fn freeSuffix(pattern: *anyopaque, allocator: std.mem.Allocator) void {
    const suffix: *Suffix = @ptrCast(@alignCast(pattern));
    allocator.destroy(suffix);
}

test "a Rules list frees its conditions, nested ones and patterns included, when its last holder lets go" {
    // The testing allocator fails the test for anything left.
    const a = testing.allocator;
    const ops: router.PatternOps = .{ .free = freeSuffix };
    const p1 = try a.create(Suffix);
    p1.* = .{ .text = "a" };
    const p2 = try a.create(Suffix);
    p2.* = .{ .text = "b" };
    const negated = try a.create(Condition);
    negated.* = .{ .url_pattern = p2, .method = try a.dupe(u8, "GET") };
    const any_of = try a.alloc(Condition, 1);
    any_of[0] = .{ .not = negated };
    const rules = try a.alloc(Rule, 2);
    rules[0] = .{ .condition = .{ .url_pattern = p1 }, .source = .{ .cache = try a.dupe(u8, "v1") } };
    rules[1] = .{ .condition = .{ .any_of = any_of }, .source = .race_network_and_fetch_handler };
    const list = try router.Rules.create(a, rules, ops);
    const second = list.retain();
    list.release();
    // Still held: still there.
    try testing.expectEqualStrings("v1", second.rules[0].source.cache.?);
    second.release();
    _ = no_ops;
}
