//! SVG 2 4.6.7 / 4.7.4: animated href reflects the live attribute list.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const allocator = testing.allocator;
const xlink = runtime.DOMString.initInterned("http://www.w3.org/1999/xlink");
const href_name = runtime.DOMString.initInterned("href");

const Realm = struct {
    ctx: runtime.ContextData,

    fn init(self: *Realm) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        self.ctx = try runtime.ContextData.init(allocator, .{});
    }

    fn deinit(self: *Realm) void {
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }
};

fn expectValue(value: *runtime.Instance, expected: []const u8) !void {
    var base = try interfaces.SVGAnimatedString.get_baseVal(value);
    defer base.deinit(allocator);
    var animated = try interfaces.SVGAnimatedString.get_animVal(value);
    defer animated.deinit(allocator);
    try testing.expectEqualStrings(expected, base.asSlice());
    try testing.expectEqualStrings(expected, animated.asSlice());
}

test "SVG href reflects updates through either the element or the animated string" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    const use = try interfaces.SVGScriptElement.init(allocator, &realm.ctx);
    defer interfaces.SVGScriptElement.deinit(use);
    const href = try interfaces.SVGScriptElement.get_href(use);
    defer interfaces.SVGAnimatedString.deinit(href);
    try testing.expectEqual(href, try interfaces.SVGScriptElement.get_href(use));
    try expectValue(href, "");
    try interfaces.SVGAnimatedString.set_baseVal(href, .{ .domstring = runtime.DOMString.initInterned("#first") });
    try expectValue(href, "#first");
    try interfaces.Element.call_setAttribute(use, href_name, .{ .domstring = runtime.DOMString.initInterned("#second") });
    try expectValue(href, "#second");
    var attribute = (try interfaces.Element.call_getAttribute(use, href_name)).?;
    defer attribute.deinit(allocator);
    try testing.expectEqualStrings("#second", attribute.asSlice());
}

test "SVG href falls back to xlink only while href is absent" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    const use = try interfaces.SVGScriptElement.init(allocator, &realm.ctx);
    defer interfaces.SVGScriptElement.deinit(use);
    const href = try interfaces.SVGScriptElement.get_href(use);
    defer interfaces.SVGAnimatedString.deinit(href);
    try interfaces.Element.call_setAttributeNS(use, xlink, runtime.DOMString.initInterned("xlink:href"), .{ .domstring = runtime.DOMString.initInterned("#old") });
    try expectValue(href, "#old");
    try interfaces.SVGAnimatedString.set_baseVal(href, .{ .domstring = runtime.DOMString.initInterned("#new") });
    try testing.expect(!try interfaces.Element.call_hasAttribute(use, href_name));
    var legacy = (try interfaces.Element.call_getAttributeNS(use, xlink, href_name)).?;
    defer legacy.deinit(allocator);
    try testing.expectEqualStrings("#new", legacy.asSlice());
    try interfaces.Element.call_setAttribute(use, href_name, .{ .domstring = runtime.DOMString.initEmpty() });
    try expectValue(href, "");
    try interfaces.Element.call_removeAttribute(use, href_name);
    try expectValue(href, "#new");
}

test "an SVG animated href safely observes forced native element teardown" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    const use = try interfaces.SVGScriptElement.init(allocator, &realm.ctx);
    const href = interfaces.SVGScriptElement.get_href(use) catch |err| {
        interfaces.SVGScriptElement.deinit(use);
        return err;
    };
    defer interfaces.SVGAnimatedString.deinit(href);
    interfaces.SVGScriptElement.deinit(use);
    try testing.expectError(error.InvalidStateError, interfaces.SVGAnimatedString.get_baseVal(href));
    try testing.expectError(error.InvalidStateError, interfaces.SVGAnimatedString.set_baseVal(href, .{ .domstring = runtime.DOMString.initInterned("#gone") }));
}
