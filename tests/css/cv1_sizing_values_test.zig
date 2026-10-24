//! CSS Sizing3/4 and Logical1 §4.1 prerequisites for anchor-size().
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const names = [_][]const u8{
    "width",       "height",     "min-width",       "min-height",     "max-width",       "max-height",
    "inline-size", "block-size", "min-inline-size", "min-block-size", "max-inline-size", "max-block-size",
};

fn check(name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    _ = css.properties.lookup(name) orelse return error.MissingSizingProperty;
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(specified, out.items);
    if (computed) |wanted| {
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        out.clearRetainingCapacity();
        try style.serializeResolved(css.properties.lookup(name).?.longhand, &out, testing.allocator);
        try testing.expectEqualStrings(wanted, out.items);
    }
}

test "all sizing longhands parse compute and serialize their shared value grammar" {
    for (names) |name| {
        const maximum = std.mem.startsWith(u8, name, "max-");
        const initial = if (maximum) "none" else "auto";
        try check(name, initial, initial, initial);
        try check(name, if (maximum) "auto" else "none", "", null);
        for ([_][]const u8{ "min-content", "max-content", "fit-content", "stretch" }) |keyword| try check(name, keyword, keyword, keyword);
        try check(name, "0", "0px", "0px");
        try check(name, "25%", "25%", "25%");
        try check(name, "2em", "2em", "32px");
        try check(name, "calc(10% + 2em)", "calc(10% + 2em)", "calc(10% + 32px)");
        try check(name, "anchor-size(--foo width, 2em)", "anchor-size(--foo width, 2em)", null);
        try check(name, "fit-content(2em)", "fit-content(2em)", "fit-content(32px)");
        try check(name, "fit-content(calc(10% - 2em))", "fit-content(calc(10% - 2em))", "fit-content(calc(10% - 32px))");
        for ([_][]const u8{ "-1px", "-1%", "fit-content()", "fit-content(-1px)", "fit-content(1px, 2px)", "fit-content(auto)", "calc-size(auto, size)", "anchor(top)" }) |invalid| try check(name, invalid, "", null);
    }
}

test "logical sizes compete with physical sizes using the element writing mode" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "writing-mode:vertical-rl; width:10px;block-size:20px;height:30px;inline-size:40px;min-width:1px;min-block-size:2px;max-inline-size:80px;max-height:90px");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    for ([_][]const u8{ "width", "block-size", "height", "inline-size", "min-width", "min-block-size", "max-height", "max-inline-size" }, [_][]const u8{ "20px", "20px", "40px", "40px", "2px", "2px", "90px", "90px" }) |name, expected| {
        const p = css.properties.lookup(name) orelse return error.MissingSizingProperty;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try style.serializeResolved(p.longhand, &out, testing.allocator);
        try testing.expectEqualStrings(expected, out.items);
    }
}

test "sizing wrappers release arguments on every partial allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "max-width:fit-content(calc(10% + 2em));min-inline-size:anchor-size(--foo, 20px)");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("max-width", &out);
    try testing.expectEqualStrings("fit-content(calc(10% + 2em))", out.items);
}

test "same block cascade order includes declarations mapped to one physical slot" {
    const inputs = [_][]const u8{
        "margin-left:1px;margin-inline-start:2px",
        "margin-inline-start:2px;margin-left:3px",
        "margin-left:4px!important;margin-inline-start:2px",
        "margin-left:4px!important;margin-inline-start:5px!important",
    };
    for (inputs, [_][]const u8{ "2px", "3px", "4px", "5px" }) |input, expected| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, input);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try style.serializeResolved(.margin_left, &out, testing.allocator);
        try testing.expectEqualStrings(expected, out.items);
    }
}
