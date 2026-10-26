//! UNRUN draft: Q177 PART 2, option A (pure legacy-name aliases).
//! Golden rule 2 evidence: main/tmp/analysis/integrator-probes-1024c/
//! RULINGS.md and results/q177-{chrome,firefox,safari}.json (2026-10-24).
//! Full copies and SHA256 provenance are in this packet's evidence/.
//! No legacy ellipse parser or alias-specific shorthand enum is expected.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const corners = [_][]const u8{
    "border-top-left-radius",
    "border-top-right-radius",
    "border-bottom-right-radius",
    "border-bottom-left-radius",
};
const names = [_][]const u8{ "border-radius", corners[0], corners[1], corners[2], corners[3] };
const aliases = [_][]const u8{
    "-webkit-border-radius",
    "-webkit-border-top-left-radius",
    "-webkit-border-top-right-radius",
    "-webkit-border-bottom-right-radius",
    "-webkit-border-bottom-left-radius",
};

fn property(name: []const u8) !css.properties.Property {
    return css.properties.lookup(name) orelse error.RadiusAliasNotImplemented;
}

fn text(block: *const css.declarations.DeclarationBlock, name: []const u8, expected: []const u8, allocator: Allocator) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn both(block: *const css.declarations.DeclarationBlock, index: usize, expected: []const u8, allocator: Allocator) !void {
    try text(block, names[index], expected, allocator);
    try text(block, aliases[index], expected, allocator);
}

fn enumeration(block: *const css.declarations.DeclarationBlock, index: usize) !void {
    try testing.expectEqual(@as(usize, if (index == 0) 4 else 1), block.length());
    if (index == 0) {
        for (corners, 0..) |name, i| try testing.expectEqualStrings(name, block.item(i).?);
    } else try testing.expectEqualStrings(names[index], block.item(0).?);
    try testing.expectEqual(@as(?[]const u8, null), block.item(block.length()));
}

test "ci1_border_radius pure aliases resolve all five names to canonical properties" {
    for (names, aliases) |name, alias| {
        try testing.expectEqual(try property(name), try property(alias));
        var uppercase: [64]u8 = undefined;
        try testing.expectEqual(try property(name), try property(std.ascii.upperString(&uppercase, alias)));
    }
}

fn cycle(allocator: Allocator, from: []const u8, through: []const u8) !void {
    _ = try property(from);
    _ = try property(through);
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, from, "1px 2px", ""));
    try enumeration(&block, 0);
    try both(&block, 0, "1px 2px", allocator);
    for (corners, [_][]const u8{ "1px", "2px", "1px", "2px" }, 1..) |_, expected, i| try both(&block, i, expected, allocator);
    var value: std.ArrayList(u8) = .empty;
    defer value.deinit(allocator);
    try block.getPropertyValue(through, &value);
    try testing.expectEqualStrings("1px 2px", value.items);
    var replay = css.declarations.DeclarationBlock.init(allocator);
    defer replay.deinit();
    try testing.expect(try replay.setProperty(.{ .allocator = allocator }, through, value.items, ""));
    try enumeration(&replay, 0);
    for (corners, [_][]const u8{ "1px", "2px", "1px", "2px" }, 1..) |_, expected, i| try both(&replay, i, expected, allocator);
}

test "ci1_border_radius pure alias all OOM standard setter alias getter alias setter preserves alternating corners" {
    try testing.checkAllAllocationFailures(testing.allocator, cycle, .{ "border-radius", "-webkit-border-radius" });
}

test "ci1_border_radius pure alias all OOM alias setter standard getter standard setter preserves alternating corners" {
    try testing.checkAllAllocationFailures(testing.allocator, cycle, .{ "-webkit-border-radius", "border-radius" });
}

fn parsing(allocator: Allocator, index: usize, input: []const u8, expected: []const u8) !void {
    _ = try property(aliases[index]);
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, aliases[index], input, ""));
    try enumeration(&block, index);
    try both(&block, index, expected, allocator);
    // Parsing through either name must yield the same typed assignments.
    var standard = css.declarations.DeclarationBlock.init(allocator);
    defer standard.deinit();
    try testing.expect(try standard.setProperty(.{ .allocator = allocator }, names[index], input, ""));
    for (0..block.length()) |i| {
        const name = block.item(i).?;
        const l = (try property(name)).longhand;
        try testing.expect(block.get(l).?.value.value.eql(standard.get(l).?.value.value));
    }
}

test "ci1_border_radius pure alias all OOM all five parsers share standard grammar and specified getters" {
    for ([_][2][]const u8{
        .{ "0", "0px" },
        .{ "1px", "1px" },
        .{ "1px 2px", "1px 2px" },
        .{ "1px 2px 3px", "1px 2px 3px" },
        .{ "1px 2px 3px 4px", "1px 2px 3px 4px" },
        .{ "1px / 2px", "1px / 2px" },
        .{ "1px 2px / 3px 4px", "1px 2px / 3px 4px" },
        .{ "1px 2px 1px / 1px 2px", "1px 2px" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, parsing, .{ @as(usize, 0), case[0], case[1] });
    for (1..names.len) |i| for ([_][2][]const u8{
        .{ "0", "0px" },
        .{ "1px 2px", "1px 2px" },
        .{ "2em 2em", "2em" },
        .{ "10% 20%", "10% 20%" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, parsing, .{ i, case[0], case[1] });
}

fn invalid(allocator: Allocator, index: usize, input: []const u8) !void {
    var out: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (out.items) |assignment| assignment.value.release();
        out.deinit(allocator);
    }
    const options = css.properties.ParseOptions{ .allocator = allocator };
    // Pin the parser result independently from forgiving CSSOM setters.
    try testing.expect(try css.properties.parseDeclaration(options, try property("margin-left"), "7px", &out));
    try testing.expect(!try css.properties.parseDeclaration(options, try property(aliases[index]), input, &out));
    try testing.expectEqual(@as(usize, 1), out.items.len);
    try testing.expectEqualStrings("margin-left", out.items[0].longhand.name());
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(options, aliases[index], "7px", "important"));
    try testing.expect(!try block.setProperty(options, aliases[index], input, ""));
    try both(&block, index, "7px", allocator);
    try testing.expect(block.getPropertyPriority(names[index]));
    try enumeration(&block, index);
}

test "ci1_border_radius pure alias all OOM invalid grammar preserves owned output and prior declaration" {
    for (0..names.len) |i| for ([_][]const u8{ "-1px", "auto", "1px /", "calc(1px + 2deg)", "calc(1em + 2px) rubbish" }) |bad|
        try testing.checkAllAllocationFailures(testing.allocator, invalid, .{ i, bad });
    for (1..names.len) |i| for ([_][]const u8{ "1px / 2px", "1px 2px 3px" }) |bad|
        try testing.checkAllAllocationFailures(testing.allocator, invalid, .{ i, bad });
}

fn wide(allocator: Allocator, index: usize, keyword: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, aliases[index], keyword, "important"));
    try enumeration(&block, index);
    try both(&block, index, keyword, allocator);
    try testing.expect(block.getPropertyPriority(names[index]));
    try testing.expect(block.getPropertyPriority(aliases[index]));
    if (index == 0) for (1..names.len) |i| {
        try both(&block, i, keyword, allocator);
        try testing.expect(block.getPropertyPriority(aliases[i]));
    };
}

test "ci1_border_radius pure alias all OOM all five CSS wide values priorities and canonical enumeration" {
    for (0..names.len) |i| for ([_][]const u8{ "initial", "inherit", "unset", "revert", "revert-layer" }) |keyword|
        try testing.checkAllAllocationFailures(testing.allocator, wide, .{ i, keyword });
}

fn resolved(style: *const css.computed_style.ComputedStyle, index: usize, expected: []const u8, allocator: Allocator) !void {
    const p = try property(aliases[index]);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    switch (p) {
        .longhand => |l| try style.serializeResolved(l, &out, allocator),
        .shorthand => |s| {
            var assigned: [4]css.properties.Assigned = undefined;
            for (s.longhands(), 0..) |l, i| assigned[i] = .{ .value = style.get(l) };
            try testing.expect(try css.properties.serializeShorthand(s, &assigned, .computed, &out, allocator));
        },
    }
    try testing.expectEqualStrings(expected, out.items);
}

fn computed(allocator: Allocator, index: usize) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "font-size", "20px", ""));
    const input = if (index == 0) "calc(0.5em + 10px) 2em / 10% 20%" else "calc(0.5em + 10px) 10%";
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, aliases[index], input, ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try resolved(style, index, if (index == 0) "20px 40px / 10% 20%" else "20px 10%", allocator);
    const initial = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{});
    defer initial.destroy();
    for (0..names.len) |i| try resolved(initial, i, "0px", allocator);
}

test "ci1_border_radius pure alias all OOM all five computed getters resolve lengths preserve percentages and expose zero initial" {
    for (0..names.len) |i| try testing.checkAllAllocationFailures(testing.allocator, computed, .{i});
}

fn inherited(allocator: Allocator, index: usize) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:20px;border-radius:calc(1em + 2px) 2em / 10% 20%");
    var owns_block = true;
    defer if (owns_block) block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    var owns_parent = true;
    defer if (owns_parent) parent.destroy();
    var inheritance = css.declarations.DeclarationBlock.init(allocator);
    defer inheritance.deinit();
    try testing.expect(try inheritance.setProperty(.{ .allocator = allocator }, "font-size", "10px", ""));
    try testing.expect(try inheritance.setProperty(.{ .allocator = allocator }, aliases[index], "inherit", ""));
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inheritance, .source = .{ .origin = .author } }});
    defer child.destroy();
    const defaulted = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer defaulted.destroy();
    block.deinit();
    owns_block = false;
    parent.destroy();
    owns_parent = false;
    try resolved(child, index, if (index == 0) "22px 40px / 10% 20%" else if (index == 1 or index == 3) "22px 10%" else "40px 20%", allocator);
    for (0..names.len) |i| try resolved(defaulted, i, "0px", allocator);
}

test "ci1_border_radius pure alias all OOM all five inherit computed pairs after source and parent release" {
    for (0..names.len) |i| try testing.checkAllAllocationFailures(testing.allocator, inherited, .{i});
}
