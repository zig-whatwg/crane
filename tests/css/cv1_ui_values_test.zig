//! CSS UI 4 §§3,4,5.2,6.3,7.1; Forms 1 field-sizing; Q46 browser rulings.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    const allocator = testing.allocator;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    try testing.expectEqualStrings(specified, text.items);
    if (computed) |expected| {
        _ = try block.setProperty(.{ .allocator = allocator }, "color", "blue", "");
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        text.clearRetainingCapacity();
        const property = css.properties.lookup(name) orelse return error.MissingUIProperty;
        try style.serializeResolved(property.longhand, &text, allocator);
        try testing.expectEqualStrings(expected, text.items);
    }
}

test "UI keywords parse compute and reject unrelated words" {
    const groups = .{
        .{ "box-sizing", &[_][]const u8{ "content-box", "border-box" } },
        .{ "field-sizing", &[_][]const u8{ "fixed", "content" } },
        .{ "resize", &[_][]const u8{ "none", "both", "horizontal", "vertical", "block", "inline" } },
        .{ "caret-shape", &[_][]const u8{ "auto", "bar", "block", "underscore" } },
        .{ "caret-animation", &[_][]const u8{ "auto", "manual" } },
        .{ "interactivity", &[_][]const u8{ "auto", "inert" } },
    };
    inline for (groups) |group| {
        for (group[1]) |keyword| try check(group[0], keyword, keyword, keyword);
        try check(group[0], "unknown", "", null);
        try check(group[0], "auto auto", "", null);
    }
}

test "outline width snaps independently of none style and offset stays signed" {
    try check("outline-width", "2.5px", "2.5px", "2px");
    try check("outline-width", "0.25px", "0.25px", "1px");
    try check("outline-width", "10px", "10px", "10px");
    try check("outline-width", "calc(2em - 40px)", "calc(2em - 40px)", "0px");
    try check("outline-width", "thin", "thin", "1px");
    try check("outline-width", "medium", "medium", "3px");
    try check("outline-width", "thick", "thick", "5px");
    try check("outline-offset", "-2.5px", "-2.5px", "-2.5px");
    try check("outline-offset", "calc(2em - 40px)", "calc(2em - 40px)", "-8px");
    for ([_][]const u8{ "-1px", "1%", "auto" }) |bad| try check("outline-width", bad, "", null);
    try check("outline-offset", "inset", "", null); // Q46: draft text not merged.
    try check("outline-color", "auto", "", null); // Q46: incomplete lag evidence.
    try check("outline-color", "invert", "", null);
    try check("outline-style", "hidden", "", null);
}

test "outline shorthand follows the newer width style color canonical order" {
    // CSSWG PR10611, dcd82364ddef; Safari ships the newer ordering (Q46).
    try check("outline", "red solid 2px", "2px solid red", null);
    try check("outline", "dashed thin", "thin dashed", null);
    try check("outline", "none", "none", null);
    try check("outline", "auto", "auto", null);
    try check("outline", "2px hidden red", "", null);
    try check("outline", "2px 3px solid", "", null);
    try check("outline", "red blue", "", null);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "outline-offset:4px;outline:red solid 2px");
    defer block.deinit();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try block.getPropertyValue("outline-offset", &text);
    try testing.expectEqualStrings("4px", text.items);
}

test "caret colors retain two specified values and resolve automatic colors" {
    try check("caret-color", "auto", "auto", "rgb(0, 0, 255)");
    try check("caret-color", "currentColor", "currentcolor", "rgb(0, 0, 255)");
    try check("caret-color", "red auto", "red auto", "rgb(255, 0, 0)");
    try check("caret-color", "auto auto", "auto auto", "rgb(0, 0, 255)");
    try check("caret-color", "auto red", "auto red", "rgb(0, 0, 255) rgb(255, 0, 0)");
    try check("caret-color", "currentColor currentColor", "currentcolor currentcolor", "rgb(0, 0, 255) rgb(0, 0, 255)");
    try check("caret-color", "red transparent", "red transparent", "rgb(255, 0, 0) rgba(0, 0, 0, 0)");
    for ([_][]const u8{ "none", "red blue green", "red, blue", "1px" }) |bad| try check("caret-color", bad, "", null);
    try check("accent-color", "auto", "auto", "auto");
    try check("accent-color", "currentColor", "currentcolor", "rgb(0, 0, 255)");
    try check("accent-color", "red", "red", "rgb(255, 0, 0)");
    try check("accent-color", "red blue", "", null);
}

test "UI inherited values and noninherited controls use the property definitions" {
    var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "caret-color:red;caret-shape:block;caret-animation:manual;accent-color:blue;interactivity:inert;resize:both;box-sizing:border-box;field-sizing:content;outline:2px solid red");
    defer parent_block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{});
    defer child.destroy();
    const expected = .{
        .{ "caret-color", "rgb(255, 0, 0)" },  .{ "caret-shape", "block" },   .{ "caret-animation", "manual" },
        .{ "accent-color", "rgb(0, 0, 255)" }, .{ "interactivity", "inert" }, .{ "resize", "none" },
        .{ "box-sizing", "content-box" },      .{ "field-sizing", "fixed" },  .{ "outline-style", "none" },
    };
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    inline for (expected) |pair| {
        text.clearRetainingCapacity();
        const property = css.properties.lookup(pair[0]) orelse return error.MissingUIProperty;
        try child.serializeResolved(property.longhand, &text, testing.allocator);
        try testing.expectEqualStrings(pair[1], text.items);
    }
}

test "caret auto and currentcolor remain symbolic through inheritance" {
    // UI 4 §5.2.1 / Color 4 §6.4; Q59 distinguishes internal computed
    // values from the resolved strings returned by getComputedStyle.
    for ([_][]const u8{ "auto", "currentcolor", "auto currentcolor", "currentcolor auto" }) |input| {
        var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color:blue");
        defer parent_block.deinit();
        _ = try parent_block.setProperty(.{ .allocator = testing.allocator }, "caret-color", input, "");
        const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color:red");
        defer child_block.deinit();
        const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
        defer child.destroy();
        const property = css.properties.lookup("caret-color") orelse return error.MissingUIProperty;
        const value = child.get(property.longhand);
        if (std.mem.eql(u8, input, "auto")) try testing.expect(value.isKeyword(.auto));
        if (std.mem.eql(u8, input, "currentcolor")) try testing.expect(value == .color and value.color == .current);
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(testing.allocator);
        try child.serializeResolved(property.longhand, &text, testing.allocator);
        try testing.expectEqualStrings(if (std.mem.eql(u8, input, "auto currentcolor")) "rgb(255, 0, 0) rgb(255, 0, 0)" else "rgb(255, 0, 0)", text.items);
    }
}

test "UI aggregate colors and shorthands release partial ownership on allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "caret-color:red blue;outline:calc(1em + 2px) solid green;accent-color:purple");
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "caret-color", "yellow transparent", "");
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue("caret-color", &text);
    try testing.expectEqualStrings("yellow transparent", text.items);
}

test "UI accent color precedes the other CSSOM longhands" {
    try testing.expectEqualStrings("accent-color", css.properties.lexicographic[0].name());
}
