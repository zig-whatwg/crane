//! Q103: every descriptor entry point preserves unicode-range source syntax.
const std = @import("std");
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");

const valid = [_]struct { source: []const u8, expected: []const u8 }{
    .{ .source = "U+0-7F /* c */", .expected = "U+0-7F" },
    .{ .source = "U+41, /* c */ U+42", .expected = "U+41, U+42" },
    .{ .source = "u+0041-005a, U+4??", .expected = "U+41-5A, U+400-4FF" },
};
const invalid = [_][]const u8{ "U/**/+41", "U+/**/41", "U+ 41" };

fn fresh(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

const RulePath = enum { set_property, camel_attribute, dashed_attribute };

fn setRuleRange(comptime path: RulePath, style: *runtime.Instance, text: []const u8) !void {
    const value = runtime.DOMString.initInterned(text);
    switch (path) {
        .set_property => try interfaces.CSSStyleDeclaration.call_setProperty(style, .initInterned("unicode-range"), value, .{ .was_passed = false, .value = undefined }),
        .camel_attribute => try interfaces.CSSFontFaceDescriptors.set_unicodeRange(style, value),
        .dashed_attribute => try interfaces.CSSFontFaceDescriptors.set_unicode_range(style, value),
    }
}

fn ruleRange(comptime path: RulePath) !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const held = try browser.evaluateScript(
        "(() => { const sheet = new CSSStyleSheet(); sheet.replaceSync('@font-face {}'); return sheet.cssRules[0].style; })()",
    );
    defer held.release();
    const style = engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NoDescriptorStyle;
    // Fonts 4 descriptor parsing reaches Syntax 3 §4.3.14 directly. These
    // paths already bypass the generic declaration-value Serializer.
    for (valid) |case| {
        try setRuleRange(path, style, case.source);
        var actual = try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, .initInterned("unicode-range"));
        defer actual.deinit(realm.allocator);
        try std.testing.expectEqualStrings(case.expected, actual.asSlice());
    }
    try setRuleRange(path, style, "U+99");
    for (invalid) |source| {
        try setRuleRange(path, style, source);
        var actual = try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, .initInterned("unicode-range"));
        defer actual.deinit(realm.allocator);
        try std.testing.expectEqualStrings("U+99", actual.asSlice());
    }
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "font rule setProperty retokenizes unicode ranges without generic serialization" {
    try fresh(struct {
        fn run() !void {
            try ruleRange(.set_property);
        }
    }.run);
}

test "font descriptor camel attribute retokenizes unicode ranges without generic serialization" {
    try fresh(struct {
        fn run() !void {
            try ruleRange(.camel_attribute);
        }
    }.run);
}

test "font descriptor dashed attribute retokenizes unicode ranges without generic serialization" {
    try fresh(struct {
        fn run() !void {
            try ruleRange(.dashed_attribute);
        }
    }.run);
}

fn constructorRange() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    for (valid) |case| {
        const face = try interfaces.FontFace.call_constructor(realm, .initInterned("Range"), .{ .cssomstring = .initInterned("url(range.woff2)") }, .{
            .was_passed = true,
            .value = .{ .unicodeRange = .initInterned(case.source) },
        });
        const generation = runtime.SlabAllocator.generationOf(face);
        defer face.releaseIfUnwrapped(generation);
        var actual = try interfaces.FontFace.get_unicodeRange(face);
        defer actual.deinit(realm.allocator);
        try std.testing.expectEqualStrings(case.expected, actual.asSlice());
        try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(face));
    }
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "FontFace constructor retokenizes unicodeRange descriptor text with comments" {
    try fresh(constructorRange);
}

fn faceSetterRange() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const face = try interfaces.FontFace.call_constructor(realm, .initInterned("Range"), .{ .cssomstring = .initInterned("url(range.woff2)") }, .{ .was_passed = false, .value = undefined });
    const generation = runtime.SlabAllocator.generationOf(face);
    defer face.releaseIfUnwrapped(generation);
    for (valid) |case| {
        try interfaces.FontFace.set_unicodeRange(face, .initInterned(case.source));
        var actual = try interfaces.FontFace.get_unicodeRange(face);
        defer actual.deinit(realm.allocator);
        try std.testing.expectEqualStrings(case.expected, actual.asSlice());
    }
    try interfaces.FontFace.set_unicodeRange(face, .initInterned("U+99"));
    for (invalid) |source| {
        // Font Loading 3 §2's attributes: an invalid setter throws and preserves the
        // previous descriptor; unlike an invalid constructor, it does not
        // reject loaded or change the face's status.
        try std.testing.expectError(error.SyntaxError, interfaces.FontFace.set_unicodeRange(face, .initInterned(source)));
        var actual = try interfaces.FontFace.get_unicodeRange(face);
        defer actual.deinit(realm.allocator);
        try std.testing.expectEqualStrings("U+99", actual.asSlice());
        try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(face));
    }
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "FontFace unicodeRange setter preserves comments and rejects split ranges atomically" {
    try fresh(faceSetterRange);
}
