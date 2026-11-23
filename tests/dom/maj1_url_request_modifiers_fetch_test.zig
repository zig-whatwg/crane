//! Lane maj1: CSS Values 5 §4.1.1 request URL modifiers beyond a property
//! value - an @import's url() keeps them and serializes them in the
//! grammar's order (css/css-values/urls/url-request-modifiers-import-
//! parsing.sub.html: Chrome), an @font-face src url() accepts them beside
//! format() (url-request-modifiers-font-face-parsing.html: Chrome) - and
//! their URL request modifier steps change the style resource's request
//! (CSS Values 4 §4.5.4 step 5): cross-origin() sets mode "cors" with
//! credentials "include" or "same-origin", integrity() the integrity
//! metadata, referrer-policy() the referrer policy.
const std = @import("std");
const dom = @import("dom");
const css = dom.style.css;
const resources = dom.style.engine.resource_loading;
const fonts = resources.font_loading;
const testing = std.testing;
const a = testing.allocator;

fn importText(prelude: []const u8) !?[]u8 {
    const text = try std.fmt.allocPrint(a, "@import {s};", .{prelude});
    defer a.free(text);
    const record = try dom.style.SheetRecord.create(a, text, .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = a });
    if (list.items.len == 0) return null;
    return try list.items[0].serialize(a);
}

fn expectImport(prelude: []const u8, expected: []const u8) !void {
    const text = (try importText(prelude)) orelse {
        std.debug.print("@import {s}: no rule\n", .{prelude});
        return error.TestUnexpectedResult;
    };
    defer a.free(text);
    try testing.expectEqualStrings(expected, text);
}

fn expectNoImport(prelude: []const u8) !void {
    const text = try importText(prelude);
    defer if (text) |t| a.free(t);
    if (text) |t| std.debug.print("@import {s}: should be dropped, got {s}\n", .{ prelude, t });
    try testing.expect(text == null);
}

test "an @import's url() keeps its request modifiers in the grammar's order" {
    try expectImport("url(\"a.css\" cross-origin(anonymous))", "@import url(\"a.css\" cross-origin(anonymous));");
    try expectImport("url(\"a.css\" integrity(\"sha384-foobar\"))", "@import url(\"a.css\" integrity(\"sha384-foobar\"));");
    try expectImport("url(\"a.css\" referrer-policy(no-referrer) cross-origin(anonymous))", "@import url(\"a.css\" cross-origin(anonymous) referrer-policy(no-referrer));");
    try expectImport("url(\"a.css\" referrer-policy(no-referrer) integrity(\"x\") cross-origin(use-credentials)) screen", "@import url(\"a.css\" cross-origin(use-credentials) integrity(\"x\") referrer-policy(no-referrer)) screen;");
    try expectImport("url(\"a.css\")", "@import url(\"a.css\");");
}

test "an @import with a malformed, repeated or unquoted modifier is dropped" {
    try expectNoImport("url(\"a.css\" cross-origin(anonymous) cross-origin(anonymous))");
    try expectNoImport("url(\"a.css\" cross-origin(anonymous) referrer-policy(no-referrer) cross-origin(anonymous))");
    try expectNoImport("url(\"a.css\" foobar(baz))");
    try expectNoImport("url(\"a.css\" referrer-policy(nope))");
    // Values 4 §4.5.3: an unquoted URL takes no modifier (all three).
    try expectNoImport("url(a.css cross-origin(anonymous))");
}

test "an @import rule carries the parsed modifiers for its fetch" {
    const record = try dom.style.SheetRecord.create(a, "@import url(\"a.css\" referrer-policy(origin) cross-origin(use-credentials) integrity(\"sha256-x\"));", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = a });
    const modifiers = list.items[0].data.import.modifiers;
    try testing.expectEqual(css.style_values.RequestModifiers.CrossOrigin.use_credentials, modifiers.cross_origin.?);
    try testing.expectEqualStrings("sha256-x", modifiers.integrity.?);
    try testing.expectEqual(css.style_values.RequestModifiers.ReferrerPolicy.origin, modifiers.referrer_policy.?);
}

test "an @font-face src url() accepts request modifiers beside format()" {
    for ([_]struct { []const u8, []const u8 }{
        .{ "url(\"fonts/Ahem.ttf\" cross-origin(anonymous))", "url(\"fonts/Ahem.ttf\" cross-origin(anonymous))" },
        .{ "url(\"fonts/Ahem.ttf\" referrer-policy(no-referrer))", "url(\"fonts/Ahem.ttf\" referrer-policy(no-referrer))" },
        .{ "url(\"fonts/Ahem.ttf\" integrity(\"sha384-foobar\"))", "url(\"fonts/Ahem.ttf\" integrity(\"sha384-foobar\"))" },
        .{ "url(\"fonts/Ahem.ttf\" referrer-policy(no-referrer) cross-origin(anonymous))", "url(\"fonts/Ahem.ttf\" cross-origin(anonymous) referrer-policy(no-referrer))" },
        .{ "url(\"fonts/Ahem.ttf\" cross-origin(anonymous)) format(\"truetype\")", "url(\"fonts/Ahem.ttf\" cross-origin(anonymous)) format(\"truetype\")" },
    }) |case| {
        var sources = (try fonts.parseSources(a, case[0])) orelse {
            std.debug.print("src: {s} did not parse\n", .{case[0]});
            return error.TestUnexpectedResult;
        };
        defer sources.deinit();
        try testing.expectEqualStrings(case[1], sources.serialized);
    }
    var sources = (try fonts.parseSources(a, "url(\"a.woff2\" cross-origin(use-credentials))")).?;
    defer sources.deinit();
    try testing.expectEqual(css.style_values.RequestModifiers.CrossOrigin.use_credentials, sources.items[0].modifiers.cross_origin.?);
    // Repeated or unknown modifiers make the component invalid.
    for ([_][]const u8{ "url(\"a.ttf\" cross-origin(anonymous) cross-origin(anonymous))", "url(\"a.ttf\" foobar(baz))" }) |text| {
        var invalid = try fonts.parseSources(a, text);
        defer if (invalid) |*s| s.deinit();
        try testing.expect(invalid == null);
    }
}

test "the modifier steps change the style resource's request" {
    // CSS Values 4 §4.5.4 steps 3-4: an image is no-cors with credentials
    // "include", until a modifier says otherwise.
    var key: resources.RequestKey = .{ .url = "https://assets.example/a.png", .referrer_policy = .origin };
    resources.applyModifiers(&key, .{});
    try testing.expectEqual(.no_cors, key.mode);
    try testing.expectEqual(.include, key.credentials);
    try testing.expectEqualStrings("", key.integrity);
    resources.applyModifiers(&key, .{ .cross_origin = .anonymous, .integrity = "sha384-foobar", .referrer_policy = .no_referrer });
    try testing.expectEqual(.cors, key.mode);
    try testing.expectEqual(.same_origin, key.credentials);
    try testing.expectEqualStrings("sha384-foobar", key.integrity);
    try testing.expectEqual(.no_referrer, key.referrer_policy);
    resources.applyModifiers(&key, .{ .cross_origin = .use_credentials });
    try testing.expectEqual(.include, key.credentials);
    // Integrity is part of request equivalence.
    var other = key;
    other.integrity = "sha384-other";
    try testing.expect(!key.eql(other));
    const copy = try key.clone(a);
    defer copy.deinit(a);
    try testing.expect(copy.eql(key));
}
