//! CSS Transitions 1/2 §2: declarations and computed lists, no execution.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(allocator: std.mem.Allocator, name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(specified, out.items);
    if (computed) |expected| {
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        out.clearRetainingCapacity();
        const property = css.properties.lookup(name) orelse return error.MissingTransitionProperty;
        try style.serializeResolved(property.longhand, &out, allocator);
        try testing.expectEqualStrings(expected, out.items);
    }
}

test "transition lists keep unknown identifiers and duplicate property entries" {
    try check(testing.allocator, "transition-property", "ALL, INVALID, width, width", "all, INVALID, width, width", "all, INVALID, width, width");
    try check(testing.allocator, "transition-behavior", "normal, allow-discrete", "normal, allow-discrete", "normal, allow-discrete");
}

test "transition time lists preserve specified units and compute each duration" {
    try check(testing.allocator, "transition-duration", "500ms, calc(-1s)", "500ms, calc(-1s)", "0.5s, 0s");
    try check(testing.allocator, "transition-delay", "-500ms, 1s", "-500ms, 1s", "-0.5s, 1s");
}

test "transition easing shares the complete animation timing grammar" {
    try check(testing.allocator, "transition-timing-function", "steps(2, jump-none), step-end", "steps(2, jump-none), steps(1)", "steps(2, jump-none), steps(1)");
    try check(testing.allocator, "transition-timing-function", "linear(0, .5 25% 75%, 1)", "linear(0, 0.5 25% 75%, 1)", "linear(0 0%, 0.5 25%, 0.5 75%, 1 100%)");
}

test "transition shorthand expands all five lists in matching order" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "transition:allow-discrete 1s -3s top, opacity 2s linear");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    inline for (.{
        .{ "transition-property", "top, opacity" },
        .{ "transition-duration", "1s, 2s" },
        .{ "transition-delay", "-3s, 0s" },
        .{ "transition-timing-function", "ease, linear" },
        .{ "transition-behavior", "allow-discrete, normal" },
    }) |c| {
        out.clearRetainingCapacity();
        try block.getPropertyValue(c[0], &out);
        try testing.expectEqualStrings(c[1], out.items);
    }
}

test "transition lists reject none mixed with another property and negative literal durations" {
    inline for (.{
        .{ "transition-property", "none, top" }, .{ "transition", "none 1s, top 2s" },
        .{ "transition-duration", "-1s" },       .{ "transition", "-1s" },
        .{ "transition-behavior", "auto" },      .{ "transition", "top 1s 2s 3s" },
    }) |c| try check(testing.allocator, c[0], c[1], "", null);
}

test "transition list copies release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    try check(allocator, "transition", "1s -3s cubic-bezier(0, -2, 1, 3) top", "top 1s cubic-bezier(0, -2, 1, 3) -3s", null);
    try check(allocator, "transition-duration", "calc(500ms + .5s), 2s", "calc(1s), 2s", "1s, 2s");
}

test "transition shorthand follows browser omission for keyword-like property names" {
    try check(testing.allocator, "transition", "ease ease", "ease", null);
    try check(testing.allocator, "transition", "normal normal", "normal", null);
    // Q85: all three browsers omit the default component, even when
    // reparsing the shortened result changes the property/component roles.
    try check(testing.allocator, "transition", "ease linear", "linear", null);
    try check(testing.allocator, "transition", "linear ease", "ease linear", null);
    try check(testing.allocator, "transition", "normal allow-discrete", "allow-discrete", null);
    try check(testing.allocator, "transition", "all", "all", null);
    try check(testing.allocator, "transition", "all 1s", "1s", null);
    try check(testing.allocator, "transition-property", "CoLoR, -WEBKIT-APPEARANCE, UNKNOWN", "color, -webkit-appearance, UNKNOWN", "color, -webkit-appearance, UNKNOWN");
}

test "transition declared and computed zero-duration omission are distinct" {
    if (comptime !@hasField(css.properties.Shorthand, "transition")) return error.TransitionPropertyNotImplemented;
    // Q86: all three computed probes keep the duration before a delay;
    // declared output follows the Chrome/Safari majority.
    try checkTransitionSurfaces("transition:opacity 0s 1s", "opacity 1s", "opacity 0s 1s");
    try checkTransitionSurfaces("transition:initial;transition-delay:1s", "", "0s 1s");
    try checkTransitionSurfaces("transition:opacity 1s", "opacity 1s", "opacity 1s");
    try checkTransitionSurfaces("transition:opacity 0s", "opacity", "opacity");
}

fn checkTransitionSurfaces(text: []const u8, declared: []const u8, computed: []const u8) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("transition", &out);
    try testing.expectEqualStrings(declared, out.items);
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var assigned: [5]css.properties.Assigned = undefined;
    for (css.properties.Shorthand.transition.longhands(), &assigned) |longhand, *item| item.* = .{ .value = style.get(longhand) };
    out.clearRetainingCapacity();
    try testing.expect(try css.properties.serializeShorthand(.transition, &assigned, .computed, &out, testing.allocator));
    try testing.expectEqualStrings(computed, out.items);
}

test "transition declared mismatched lists and incomplete longhands follow browser serialization" {
    if (comptime !@hasField(css.properties.Shorthand, "transition")) return error.TransitionPropertyNotImplemented;
    inline for (.{
        .{ "transition-property:opacity,width;transition-duration:1s;transition-timing-function:ease;transition-delay:0s;transition-behavior:normal", "opacity 1s, width" },
        .{ "transition-property:linear;transition-timing-function:ease", "" },
        .{ "transition-property:allow-discrete;transition-behavior:normal", "" },
    }) |c| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, c[0]);
        defer block.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.getPropertyValue("transition", &out);
        try testing.expectEqualStrings(c[1], out.items);
    }
}

test "computed transition repeats short lists and truncates excess entries to property count" {
    if (comptime !@hasField(css.properties.Shorthand, "transition")) return error.TransitionPropertyNotImplemented;
    // Q89: repeat is the Chrome/Safari majority; excess-list truncation
    // follows Transitions 1 §2 in the three-way browser split.
    try checkTransitionSurfaces("transition-property:opacity,width;transition-duration:1s", "", "opacity 1s, width 1s");
    try checkTransitionSurfaces("transition-property:opacity;transition-duration:1s,2s", "", "opacity 1s");
    try checkTransitionSurfaces("transition-property:opacity,width,height;transition-duration:1s,2s;transition-delay:0s,.5s", "", "opacity 1s, width 2s 0.5s, height 1s");
    try checkTransitionSurfaces("transition-property:opacity,width;transition-duration:1s;transition-timing-function:ease;transition-delay:0s;transition-behavior:normal", "opacity 1s, width", "opacity 1s, width 1s");
}

test "transition keyword omission agrees on declared and computed surfaces" {
    if (comptime !@hasField(css.properties.Shorthand, "transition")) return error.TransitionPropertyNotImplemented;
    inline for (.{
        .{ "ease ease", "ease" },                       .{ "ease linear", "linear" },
        .{ "linear ease", "ease linear" },              .{ "normal normal", "normal" },
        .{ "normal allow-discrete", "allow-discrete" },
    }) |c| try checkTransitionSurfaces("transition:" ++ c[0], c[1], c[1]);
}
