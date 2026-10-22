//! SVG 2 §4.3.3: specific interfaces through createElementNS, XML and HTML.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const helpers = @import("edges_node_holders_helpers.zig");

fn constructors() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    // Representative concrete and abstract classes from geometry, structure,
    // text, paint, animation and filters must reach their Node parent.
    inline for (.{ interfaces.SVGCircleElement, interfaces.SVGSVGElement, interfaces.SVGTextElement, interfaces.SVGLinearGradientElement, interfaces.SVGAnimateElement, interfaces.SVGFEBlendElement }) |T| {
        const element = try T.init(std.testing.allocator, &context);
        defer runtime.Instance.deinit(element);
        try std.testing.expectEqual(@as(u16, 1), try interfaces.Node.get_nodeType(element));
        try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("data-xm1"), .{ .domstring = runtime.DOMString.initInterned("value") });
        var value = (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("data-xm1"))) orelse return error.MissingAttribute;
        defer value.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("value", value.asSlice());
    }
}

test "SVG generated construction reaches Element and Node for every family" {
    try helpers.onFreshThread(constructors);
}

fn constructionFailure(allocator: std.mem.Allocator, context: runtime.Context) !void {
    inline for (.{ interfaces.SVGCircleElement, interfaces.SVGSVGElement, interfaces.SVGTextElement, interfaces.SVGLinearGradientElement, interfaces.SVGAnimateElement, interfaces.SVGFEBlendElement }) |T| {
        const element = try T.init(allocator, context);
        defer runtime.Instance.deinit(element);
        try std.testing.expectEqual(@as(u16, 1), try interfaces.Node.get_nodeType(element));
    }
}

fn allocationFailures() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    // The slab and context keep their normal leak-checking allocator; fail
    // each allocation made by the generated construction chain itself.
    try std.testing.checkAllAllocationFailures(std.testing.allocator, constructionFailure, .{&context});
}

test "SVG parent construction unwinds every failed allocation" {
    try helpers.onFreshThread(allocationFailures);
}
