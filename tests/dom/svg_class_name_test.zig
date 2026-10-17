//! SVG 2 4.4.1: className is a live, unnamespaced [SameObject] reflection.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");

fn expectValue(value: *runtime.Instance, expected: []const u8) !void {
    var base = try interfaces.SVGAnimatedString.get_baseVal(value);
    defer base.deinit(testing.allocator);
    var animated = try interfaces.SVGAnimatedString.get_animVal(value);
    defer animated.deinit(testing.allocator);
    try testing.expectEqualStrings(expected, base.asSlice());
    try testing.expectEqualStrings(expected, animated.asSlice());
}

test "SVG className reflects both directions without a deprecated namespace" {
    const allocator = testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const element = try interfaces.SVGScriptElement.init(allocator, &ctx);
    defer interfaces.SVGScriptElement.deinit(element);
    const value = try interfaces.SVGElement.get_className(element);
    defer interfaces.SVGAnimatedString.deinit(value);
    try testing.expectEqual(value, try interfaces.SVGElement.get_className(element));
    try expectValue(value, "");

    const name = runtime.DOMString.initInterned("class");
    const xlink = runtime.DOMString.initInterned("http://www.w3.org/1999/xlink");
    try interfaces.Element.call_setAttributeNS(element, xlink, runtime.DOMString.initInterned("xlink:class"), .{ .domstring = runtime.DOMString.initInterned("namespaced") });
    try expectValue(value, "");
    try interfaces.SVGAnimatedString.set_baseVal(value, .{ .domstring = runtime.DOMString.initInterned("first") });
    var attribute = (try interfaces.Element.call_getAttribute(element, name)).?;
    defer attribute.deinit(allocator);
    try testing.expectEqualStrings("first", attribute.asSlice());
    var namespaced = (try interfaces.Element.call_getAttributeNS(element, xlink, name)).?;
    defer namespaced.deinit(allocator);
    try testing.expectEqualStrings("namespaced", namespaced.asSlice());

    try interfaces.Element.call_setAttribute(element, name, .{ .domstring = runtime.DOMString.initInterned("second") });
    try expectValue(value, "second");
    try interfaces.Element.call_removeAttribute(element, name);
    try expectValue(value, "");
}
