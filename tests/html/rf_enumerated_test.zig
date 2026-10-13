//! HTML's reflection limited to known values, through public accessors.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const fixture = @import("rf_fixture.zig");
const str = fixture.str;
const policies: []const []const u8 = &.{ "", "no-referrer", "no-referrer-when-downgrade", "same-origin", "origin", "strict-origin", "origin-when-cross-origin", "strict-origin-when-cross-origin", "unsafe-url" };

const Case = struct {
    tag: []const u8,
    attribute: []const u8,
    keywords: []const []const u8,
    default: []const u8,
    get: *const fn (*runtime.Instance) anyerror!runtime.DOMString,
    set: *const fn (*runtime.Instance, runtime.DOMString) anyerror!void,
};

fn check(case: Case) !void {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const element = try interfaces.Document.call_createElement(page.document, str(case.tag), .notPassed());
    defer runtime.Instance.deinit(element);
    {
        var value = try case.get(element);
        defer value.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(case.default, value.asSlice());
    }
    for (case.keywords) |keyword| {
        var uppercase: [64]u8 = undefined;
        for (keyword, 0..) |byte, i| uppercase[i] = std.ascii.toUpper(byte);
        const given = uppercase[0..keyword.len];
        try interfaces.Element.call_setAttribute(element, str(case.attribute), .{ .domstring = str(given) });
        var value = try case.get(element);
        defer value.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(keyword, value.asSlice());
        try case.set(element, str(given));
        var attribute = (try interfaces.Element.call_getAttribute(element, str(case.attribute))).?;
        defer attribute.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(given, attribute.asSlice());
    }
    for ([_][]const u8{ "unknown", " auto", "auto ", "\ttext", "EMAIL\x00" }) |invalid| {
        try case.set(element, str(invalid));
        var value = try case.get(element);
        defer value.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(case.default, value.asSlice());
    }
}

test "global inputMode and enterKeyHint return only canonical known keywords" {
    try check(.{ .tag = "div", .attribute = "inputmode", .keywords = &.{ "none", "text", "tel", "url", "email", "numeric", "decimal", "search" }, .default = "", .get = interfaces.HTMLElement.get_inputMode, .set = interfaces.HTMLElement.set_inputMode });
    try check(.{ .tag = "div", .attribute = "enterkeyhint", .keywords = &.{ "enter", "done", "go", "next", "previous", "search", "send" }, .default = "", .get = interfaces.HTMLElement.get_enterKeyHint, .set = interfaces.HTMLElement.set_enterKeyHint });
}

test "image enumerated attributes have their complete keyword sets and defaults" {
    try check(.{ .tag = "img", .attribute = "referrerpolicy", .keywords = policies, .default = "", .get = interfaces.HTMLImageElement.get_referrerPolicy, .set = interfaces.HTMLImageElement.set_referrerPolicy });
    try check(.{ .tag = "img", .attribute = "decoding", .keywords = &.{ "sync", "async", "auto" }, .default = "auto", .get = interfaces.HTMLImageElement.get_decoding, .set = interfaces.HTMLImageElement.set_decoding });
    try check(.{ .tag = "img", .attribute = "loading", .keywords = &.{ "eager", "lazy" }, .default = "eager", .get = interfaces.HTMLImageElement.get_loading, .set = interfaces.HTMLImageElement.set_loading });
    try check(.{ .tag = "img", .attribute = "fetchpriority", .keywords = &.{ "high", "low", "auto" }, .default = "auto", .get = interfaces.HTMLImageElement.get_fetchPriority, .set = interfaces.HTMLImageElement.set_fetchPriority });
}

test "script and iframe enumerated attributes read content attributes and canonicalize" {
    try check(.{ .tag = "script", .attribute = "referrerpolicy", .keywords = policies, .default = "", .get = interfaces.HTMLScriptElement.get_referrerPolicy, .set = interfaces.HTMLScriptElement.set_referrerPolicy });
    try check(.{ .tag = "script", .attribute = "fetchpriority", .keywords = &.{ "high", "low", "auto" }, .default = "auto", .get = interfaces.HTMLScriptElement.get_fetchPriority, .set = interfaces.HTMLScriptElement.set_fetchPriority });
    try check(.{ .tag = "iframe", .attribute = "referrerpolicy", .keywords = policies, .default = "", .get = interfaces.HTMLIFrameElement.get_referrerPolicy, .set = interfaces.HTMLIFrameElement.set_referrerPolicy });
    try check(.{ .tag = "iframe", .attribute = "loading", .keywords = &.{ "eager", "lazy" }, .default = "eager", .get = interfaces.HTMLIFrameElement.get_loading, .set = interfaces.HTMLIFrameElement.set_loading });
}

test "script crossOrigin distinguishes missing from invalid and preserves setter spelling" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const script = try interfaces.Document.call_createElement(page.document, str("script"), .notPassed());
    defer runtime.Instance.deinit(script);
    try std.testing.expect((try interfaces.HTMLScriptElement.get_crossOrigin(script)) == null);
    for ([_]struct { given: []const u8, expected: []const u8 }{
        .{ .given = "", .expected = "anonymous" },
        .{ .given = "invalid", .expected = "anonymous" },
        .{ .given = "Anonymous", .expected = "anonymous" },
        .{ .given = "USE-CREDENTIALS", .expected = "use-credentials" },
    }) |case| {
        try interfaces.HTMLScriptElement.set_crossOrigin(script, str(case.given));
        var value = (try interfaces.HTMLScriptElement.get_crossOrigin(script)).?;
        defer value.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(case.expected, value.asSlice());
        var attr = (try interfaces.Element.call_getAttribute(script, str("crossorigin"))).?;
        defer attr.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(case.given, attr.asSlice());
    }
    try interfaces.HTMLScriptElement.set_crossOrigin(script, null);
    try std.testing.expect(!(try interfaces.Element.call_hasAttribute(script, str("crossorigin"))));
}
