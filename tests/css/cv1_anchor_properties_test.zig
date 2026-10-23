//! Non-geometric CSS Anchor Position 1 property grammars and computed values.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingAnchorProperty;
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
        switch (property) {
            .longhand => |l| try style.serializeResolved(l, &out, testing.allocator),
            .shorthand => |s| {
                var assigned: [css.properties.max_assignments]css.properties.Assigned = undefined;
                for (s.longhands(), 0..) |l, i| assigned[i] = .{ .value = style.get(l) };
                _ = try css.properties.serializeShorthand(s, assigned[0..s.longhands().len], .computed, &out, testing.allocator);
            },
        }
        try testing.expectEqualStrings(wanted, out.items);
    }
}

test "anchor names and scopes are decoded case sensitive comma lists" {
    for ([_][]const u8{ "anchor-name", "anchor-scope" }) |name| {
        try check(name, "none", "none", "none");
        try check(name, "--foo, --Foo, --f\\6f o", "--foo, --Foo, --foo", "--foo, --Foo, --foo");
        try check(name, "--", "--", "--");
        for ([_][]const u8{ "foo", "--foo --bar", "--foo,", ", --foo", "--foo, none", "none, --foo" }) |invalid| try check(name, invalid, "", null);
    }
    try check("anchor-scope", "ALL", "all", "all");
    try check("anchor-name", "all", "", null);
}

test "position area canonical axes and computed logical short forms" {
    const cases = [_][3][]const u8{
        .{ "none", "none", "none" },                                                                                       .{ "top left", "left top", "left top" },
        .{ "top center", "center top", "center top" },                                                                     .{ "span-all top", "top", "top" },
        .{ "start start", "start", "start" },                                                                              .{ "inline-end block-start", "block-start inline-end", "start end" },
        .{ "inline-start center", "center inline-start", "center start" },                                                 .{ "span-all self-block-start", "self-block-start", "self-block-start" },
        .{ "self-start span-all", "self-start span-all", "self-block-start" },                                             .{ "span-all start", "span-all start", "inline-start" },
        .{ "span-self-inline-end self-block-start", "self-block-start span-self-inline-end", "self-start span-self-end" },
    };
    for (cases) |c| try check("position-area", c[0], c[1], c[2]);
    for ([_][]const u8{ "top top", "left right", "left start", "self-start start", "inline-start block-start left", "none none", "top none", "block-start self-inline-start" }) |invalid| try check("position-area", invalid, "", null);
}

test "position try preserves tactic order and contiguous grammar components" {
    try check("position-try-fallbacks", "none", "none", "none");
    try check("position-try-fallbacks", "flip-start flip-inline --foo, top left", "--foo flip-start flip-inline, left top", "--foo flip-start flip-inline, left top");
    try check("position-try-fallbacks", "flip-start flip-inline flip-y flip-block flip-x", "flip-start flip-inline flip-y flip-block flip-x", "flip-start flip-inline flip-y flip-block flip-x");
    for ([_][]const u8{ "none, --foo", "--foo --bar", "flip-inline --foo flip-block", "flip-block flip-block", "left --foo", "--foo,", "--foo left" }) |invalid| try check("position-try-fallbacks", invalid, "", null);
    try check("position-try", "normal --foo", "--foo", "--foo");
    try check("position-try", "most-width --foo, flip-x", "most-width --foo, flip-x", "most-width --foo, flip-x");
    for ([_][]const u8{ "most-width", "none normal", "--foo most-height", "normal --foo, most-width --bar" }) |invalid| try check("position-try", invalid, "", null);
    for ([_][]const u8{ "normal", "most-width", "most-height", "most-block-size", "most-inline-size" }) |value| try check("position-try-order", value, value, value);
}

test "anchor property parsing releases all partial lists on allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: std.mem.Allocator) !void {
    _ = css.properties.lookup("anchor-name") orelse return error.MissingAnchorProperty;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "anchor-name:--a,--b;anchor-scope:--f\\6f o;position-try:most-width --a flip-start flip-y, block-start inline-end");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
}

test "position anchor is independent of position and keeps the normal initial value" {
    for ([_][]const u8{ "normal", "none", "auto", "match-parent", "--Foo" }) |value| try check("position-anchor", value, value, value);
    for ([_][]const u8{ "foo", "--foo --bar", "--foo, --bar", "10%", "10px" }) |invalid| try check("position-anchor", invalid, "", null);
    const p = css.properties.lookup("position-anchor") orelse return error.MissingAnchorProperty;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "position-anchor:--foo;position:absolute");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("position-anchor", &out);
    try testing.expectEqualStrings("--foo", out.items);
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{});
    defer child.destroy();
    out.clearRetainingCapacity();
    try child.serializeResolved(p.longhand, &out, testing.allocator);
    try testing.expectEqualStrings("normal", out.items);
}
