//! Animations 1/2, Easing 2 and Scroll Animations 1; Q40/Q41/Q61 rulings.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(specified, out.items);
    if (computed) |expected| {
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        out.clearRetainingCapacity();
        const p = css.properties.lookup(name) orelse return error.MissingAnimationProperty;
        try style.serializeResolved(p.longhand, &out, testing.allocator);
        try testing.expectEqualStrings(expected, out.items);
    }
}

test "animation lists retain specified units and compute absolute time" {
    try check("animation-duration", "500ms, 3s", "500ms, 3s", "0.5s, 3s");
    try check("animation-delay", "-500ms, 1s", "-500ms, 1s", "-0.5s, 1s");
    try check("animation-duration", "auto", "auto", "0s");
    try check("animation-iteration-count", "infinite, 2.5, 0", "infinite, 2.5, 0", "infinite, 2.5, 0");
    for ([_][]const u8{ "-1s", "1", "1s,", "1s 2s" }) |bad| try check("animation-duration", bad, "", null);
    try check("animation-iteration-count", "-1", "", null);
}

test "animation names distinguish a none keyword from a quoted reserved name" {
    try check("animation-name", "NONE", "none", "none");
    try check("animation-name", "\"something\", \"multi word string\"", "something, multi\\ word\\ string", "something, multi\\ word\\ string");
    try check("animation-name", "\"none\", \"INITIAL\", foo", "\"none\", \"INITIAL\", foo", "\"none\", \"INITIAL\", foo");
    try check("animation-name", "default", "", null);
}

test "animation keyword lists keep their property specific grammar" {
    try check("animation-direction", "reverse, alternate, alternate-reverse, normal", "reverse, alternate, alternate-reverse, normal", "reverse, alternate, alternate-reverse, normal");
    try check("animation-fill-mode", "none, forwards, backwards, both", "none, forwards, backwards, both", "none, forwards, backwards, both");
    try check("animation-play-state", "paused, running", "paused, running", "paused, running");
    try check("animation-composition", "replace, add, accumulate", "replace, add, accumulate", "replace, add, accumulate");
    try check("animation-direction", "paused", "", null);
    try check("animation-composition", "normal", "", null);
}

test "easing steps and cubic bezier canonical forms follow the complete grammar" {
    try check("animation-timing-function", "step-start, step-end", "steps(1, start), steps(1)", "steps(1, start), steps(1)");
    try check("animation-timing-function", "steps(2, jump-none), steps(3, jump-end)", "steps(2, jump-none), steps(3)", "steps(2, jump-none), steps(3)");
    try check("animation-timing-function", "cubic-bezier(0, -2, 1, 3)", "cubic-bezier(0, -2, 1, 3)", "cubic-bezier(0, -2, 1, 3)");
    for ([_][]const u8{ "steps(0)", "steps(1, jump-none)", "steps(calc(0/0), jump-none)", "cubic-bezier(-0.1, 0, 1, 1)", "cubic-bezier(0, sibling-index(), 1, sign(2em - 20px))", "cubic-bezier(0, 0, 1.1, 1)" }) |bad| try check("animation-timing-function", bad, "", null);
}

test "easing calculation bounds follow browser majorities at the owning boundary" {
    // Q61 aligned C156/F158/S27: known out-of-range x and jump-none
    // reject; other calculated counts clamp to 1; NaN rejects.
    try check("animation-timing-function", "steps(calc(-10), start)", "steps(calc(-10), start)", "steps(1, start)");
    try check("animation-timing-function", "steps(calc(5 / 2), start)", "steps(calc(2.5), start)", "steps(3, start)");
    for ([_][]const u8{ "steps(calc(1), jump-none)", "steps(calc(0/0))", "cubic-bezier(calc(-2), calc(0.7 / 2), calc(1.5), calc(0))" }) |bad| try check("animation-timing-function", bad, "", null);
    // Blink CSSToStyleMap::MapAnimationTimingFunction clamps a late
    // jump-none result to two. Q61/D63; no shared AST clamp is changed.
    try check("animation-timing-function", "steps(calc(2 + sign(100em - 1px)))", "steps(calc(2 + sign(100em - 1px)))", "steps(3)");
    try check("animation-timing-function", "steps(calc(1 + sign(1em - 100px)), jump-none)", "steps(calc(1 + sign(1em - 100px)), jump-none)", "steps(2, jump-none)");
}

test "linear easing preserves specified stops and computes expanded positions" {
    // Q41: Safari's specified serialization; all engines' computed fixup.
    try check("animation-timing-function", "linear(0, 0.5 25% 75%, 1)", "linear(0, 0.5 25% 75%, 1)", "linear(0 0%, 0.5 25%, 0.5 75%, 1 100%)");
    try check("animation-timing-function", "linear(0, 0 40%, 1, 0.5, 1)", "linear(0, 0 40%, 1, 0.5, 1)", "linear(0 0%, 0 40%, 1 60%, 0.5 80%, 1 100%)");
    try check("animation-timing-function", "linear(calc(0/0), 1)", "linear(0 0%, 1 100%)", "linear(0 0%, 1 100%)");
    for ([_][]const u8{ "linear()", "linear(0)", "linear(0 0% 100%)", "linear(0% 1 50%)" }) |bad| try check("animation-timing-function", bad, "", null);
    // Q70: C/F reject element-dependent stops; Safari alone accepts them.
    for ([_][]const u8{ "linear(sign(1em - 1px), 1)", "linear(0 calc(sign(1em - 1px) * 10%), 1)", "linear(0, calc(sibling-index() / 10), 1)" }) |bad|
        try check("animation-timing-function", bad, "", null);
}

test "animation shorthand expands each item and resets timeline and ranges" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "animation-composition:add;animation-timeline:--old;animation-range:entry;animation:anim paused both reverse 4 1s -3s cubic-bezier(0, -2, 1, 3)");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    const expected = .{
        .{ "animation-duration", "1s" },                               .{ "animation-delay", "-3s" },          .{ "animation-name", "anim" },
        .{ "animation-timing-function", "cubic-bezier(0, -2, 1, 3)" }, .{ "animation-iteration-count", "4" },  .{ "animation-direction", "reverse" },
        .{ "animation-fill-mode", "both" },                            .{ "animation-play-state", "paused" },  .{ "animation-timeline", "auto" },
        .{ "animation-composition", "add" },                           .{ "animation-range-start", "normal" }, .{ "animation-range-end", "normal" },
    };
    inline for (expected) |pair| {
        out.clearRetainingCapacity();
        try block.getPropertyValue(pair[0], &out);
        try testing.expectEqualStrings(pair[1], out.items);
    }
}

test "animation range shorthands omit only semantically default endpoints" {
    try check("animation-range", "entry 0% entry 100%", "entry", null);
    try check("animation-range", "0% 100%", "0%", null);
    try check("animation-range", "100px normal", "100px", null);
    try check("animation-range", "entry normal", "entry normal", null);
    try check("animation-range", "entry calc(10% - 10%) entry calc(50% + 50%)", "entry calc(0%) entry calc(100%)", null);
    try check("animation-range-start", "entry 2em", "entry 2em", "entry 32px");
}

test "animation lists and nested easing release every allocation on failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "animation-name:one,\"multi word\";animation-duration:calc(1s + 500ms),2s;animation-timing-function:linear(0,0.5 25% 75%,1),steps(4)");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("animation-name", &out);
    try testing.expectEqualStrings("one, multi\\ word", out.items);
}

test "animation duration resolves auto only with a single automatic timeline" {
    for ([_][]const u8{ "auto", "auto, auto", "--named", "none", "scroll()", "view()" }, 0..) |timeline, i| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "animation-duration", "auto, 500ms", "");
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "animation-timeline", timeline, "");
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try css.properties.serializeValue(.animation_duration, style.get(.animation_duration), &out, testing.allocator);
        try testing.expectEqualStrings("auto, 0.5s", out.items);
        out.clearRetainingCapacity();
        try style.serializeResolved(.animation_duration, &out, testing.allocator);
        try testing.expectEqualStrings(if (i == 0) "0s, 0.5s" else "auto, 0.5s", out.items);
    }
}

test "animation timeline functions preserve groups and compute their insets" {
    try check("animation-timeline", "scroll(y root), scroll(nearest block)", "scroll(root y), scroll()", "scroll(root y), scroll()");
    try check("animation-timeline", "view(2em calc(1% + 1em) inline)", "view(inline 2em calc(1% + 1em))", "view(inline 32px calc(1% + 16px))");
    try check("animation-timeline", "view(y auto auto)", "view(y)", "view(y)");
    for ([_][]const u8{ "scroll(x y)", "scroll(root self)", "view(1px y 2px)", "view(1px, 2px)", "foo", "--", "auto," }) |bad|
        try check("animation-timeline", bad, "", null);
    try check("animation", "-1s", "", null);
}
