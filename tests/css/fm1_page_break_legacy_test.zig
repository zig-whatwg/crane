//! CSS Break 3 §3.4 / Cascade 5 §3.1: legacy shorthand boundaries.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const properties = css.properties;
const Block = css.declarations.DeclarationBlock;
const Value = css.style_values.Value;
const Keyword = css.style_values.Keyword;

const Case = struct { name: []const u8, longhand: properties.Longhand };
const cases = [_]Case{
    .{ .name = "page-break-before", .longhand = .break_before },
    .{ .name = "page-break-after", .longhand = .break_after },
    .{ .name = "page-break-inside", .longhand = .break_inside },
};

fn shorthand(name: []const u8) !properties.Shorthand {
    const property = properties.lookup(name);
    try testing.expect(property != null);
    try testing.expect(property.? == .shorthand);
    return property.?.shorthand;
}

fn expectText(block: *const Block, expected: []const u8, allocator: Allocator) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings(expected, out.items);
    try testing.expect(std.mem.indexOf(u8, out.items, "page-break-") == null);
}

test "page-break properties are one-longhand shorthands and never computed longhands" {
    for (cases) |case| {
        const s = try shorthand(case.name);
        try testing.expectEqualSlices(properties.Longhand, &.{case.longhand}, s.longhands());
        for (std.meta.tags(properties.Longhand)) |longhand|
            try testing.expect(!std.mem.eql(u8, case.name, longhand.name()));
    }
}

fn forward(allocator: Allocator) !void {
    for (cases, 0..) |case, index| {
        _ = try shorthand(case.name);
        for ([_][]const u8{ "auto", "left", "right", "avoid", "always" }) |word| {
            if (index == 2 and !std.mem.eql(u8, word, "auto") and !std.mem.eql(u8, word, "avoid")) continue;
            const mapped = if (std.mem.eql(u8, word, "always")) "page" else word;
            var block = Block.init(allocator);
            defer block.deinit();
            try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.name, word, "important"));
            try h.specified(&block, case.name, word, allocator);
            try h.specified(&block, case.longhand.name(), mapped, allocator);
            try testing.expectEqual(@as(usize, 1), block.length());
            try testing.expectEqualStrings(case.longhand.name(), block.item(0).?);
            try testing.expect(block.getPropertyPriority(case.name));
            const text = try std.fmt.allocPrint(allocator, "{s}: {s} !important;", .{ case.longhand.name(), mapped });
            defer allocator.free(text);
            try expectText(&block, text, allocator);
            const style = try h.compute(allocator, &block, null);
            defer style.destroy();
            try h.expect(style, case.name, word, allocator);
            try h.expect(style, case.longhand.name(), mapped, allocator);
        }
    }
    // Token matching must use Syntax's decoded, ASCII-insensitive identifiers.
    try h.check(allocator, "page-break-before", "AlWaYs", "always", false);
    try h.check(allocator, "page-break-after", "\\61 lways/**/", "always", false);
}

fn parsedSource(allocator: Allocator) !void {
    for (cases) |case| {
        _ = try shorthand(case.name);
        const source = try std.fmt.allocPrint(allocator, "{s}: avoid !important;", .{case.name});
        var block = blk: {
            defer allocator.free(source);
            break :blk try Block.parse(.{ .allocator = allocator }, source);
        };
        defer block.deinit();
        try h.specified(&block, case.name, "avoid", allocator);
        try h.specified(&block, case.longhand.name(), "avoid", allocator);
        const expected = try std.fmt.allocPrint(allocator, "{s}: avoid !important;", .{case.longhand.name()});
        defer allocator.free(expected);
        try expectText(&block, expected, allocator);
    }
}

fn initial(allocator: Allocator) !void {
    var block = Block.init(allocator);
    defer block.deinit();
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    for (cases) |case| {
        _ = try shorthand(case.name);
        try h.specified(&block, case.name, "", allocator);
        try h.expect(style, case.name, "auto", allocator);
        try h.expect(style, case.longhand.name(), "auto", allocator);
    }
}

test "parsed legacy declarations own their source and unset legacy computed values are auto" {
    try parsedSource(testing.allocator);
    try initial(testing.allocator);
}

test "legacy shorthand flag defaults false outside exactly three page-break properties" {
    for (cases) |case| _ = try shorthand(case.name);
    if (comptime @hasDecl(properties.Shorthand, "isLegacyShorthand")) {
        var count: usize = 0;
        for (std.meta.tags(properties.Shorthand)) |s| {
            const expected = std.mem.eql(u8, s.name(), "page-break-before") or
                std.mem.eql(u8, s.name(), "page-break-after") or
                std.mem.eql(u8, s.name(), "page-break-inside");
            try testing.expectEqual(expected, s.isLegacyShorthand());
            if (s.isLegacyShorthand()) count += 1;
        }
        try testing.expectEqual(@as(usize, 3), count);
    } else return error.MissingLegacyShorthandFlag;
}

test "legacy values expand, reconstruct and compute through ordinary shorthand APIs" {
    try forward(testing.allocator);
}

fn invalid(allocator: Allocator) !void {
    for (cases, 0..) |case, index| {
        _ = try shorthand(case.name);
        for ([_][]const u8{ "page", "column", "all", "recto", "verso", "avoid-page", "avoid-column", "auto avoid", "always auto", "auto initial", "none", "1", "\"auto\"" }) |word| {
            var block = Block.init(allocator);
            defer block.deinit();
            try testing.expect(!try block.setProperty(.{ .allocator = allocator }, case.name, word, ""));
            try testing.expectEqual(@as(usize, 0), block.length());
            try h.specified(&block, case.name, "", allocator);
            try h.specified(&block, case.longhand.name(), "", allocator);
        }
        if (index == 2) {
            for ([_][]const u8{ "left", "right", "always" }) |word|
                try h.check(allocator, case.name, word, "", false);
        }
    }
}

test "modern break values and extra tokens are invalid on legacy shorthands" {
    try invalid(testing.allocator);
}

fn reverse(allocator: Allocator) !void {
    for (cases, 0..) |case, index| {
        const s = try shorthand(case.name);
        // Test the public serializer in both modes, including unreachable
        // inside states: a false result must append nothing to existing output.
        for ([_]Keyword{ .auto, .left, .right, .avoid, .page, .column, .all, .recto, .verso, .avoid_page, .avoid_column, .always }) |keyword| {
            const expected: []const u8 = switch (keyword) {
                .auto, .avoid => keyword.name(),
                .left, .right => if (index < 2) keyword.name() else "",
                .page => if (index < 2) "always" else "",
                else => "",
            };
            const assigned = [_]properties.Assigned{.{ .value = Value.kw(keyword) }};
            inline for (.{ properties.ShorthandMode.specified, properties.ShorthandMode.computed }) |mode| {
                var out: std.ArrayList(u8) = .empty;
                defer out.deinit(allocator);
                try out.appendSlice(allocator, "prefix:");
                try testing.expectEqual(expected.len > 0, try properties.serializeShorthand(s, &assigned, mode, &out, allocator));
                try testing.expectEqualStrings("prefix:", out.items[0..7]);
                try testing.expectEqualStrings(expected, out.items[7..]);
            }
            // CSSOM readback for every value accepted by the real longhand.
            if (index == 2 and keyword != .auto and keyword != .avoid and keyword != .avoid_page and keyword != .avoid_column) continue;
            var block = Block.init(allocator);
            defer block.deinit();
            try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.longhand.name(), keyword.name(), ""));
            try h.specified(&block, case.name, expected, allocator);
            const style = try h.compute(allocator, &block, null);
            defer style.destroy();
            try h.expect(style, case.name, expected, allocator);
        }
        const unrepresentable = [_]properties.Assigned{.{ .value = .{ .integer = 1 } }};
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try testing.expect(!try properties.serializeShorthand(s, &unrepresentable, .specified, &out, allocator));
        try testing.expectEqual(@as(usize, 0), out.items.len);
    }
}

test "legacy reverse mapping is identical for specified and computed values" {
    try reverse(testing.allocator);
}

fn wideAndPending(allocator: Allocator) !void {
    for (cases) |case| {
        _ = try shorthand(case.name);
        for (std.meta.tags(css.style_values.CssWide)) |wide| {
            var block = Block.init(allocator);
            defer block.deinit();
            try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.name, wide.name(), ""));
            try h.specified(&block, case.name, wide.name(), allocator);
            try h.specified(&block, case.longhand.name(), wide.name(), allocator);
            const expected = try std.fmt.allocPrint(allocator, "{s}: {s};", .{ case.longhand.name(), wide.name() });
            defer allocator.free(expected);
            try expectText(&block, expected, allocator);
        }
        {
            var set_block = Block.init(allocator);
            defer set_block.deinit();
            try testing.expect(try set_block.setProperty(.{ .allocator = allocator }, case.name, "var(--v)", ""));
            try h.specified(&set_block, case.name, "var(--v)", allocator);
            try h.specified(&set_block, case.longhand.name(), "", allocator);
            const expected = try std.fmt.allocPrint(allocator, "{s}: ;", .{case.longhand.name()});
            defer allocator.free(expected);
            try expectText(&set_block, expected, allocator);
        }
        // Parse from an owned source, destroy it, then read the pending owner.
        const source = try std.fmt.allocPrint(allocator, "{s}: var(--v);", .{case.name});
        var block = blk: {
            defer allocator.free(source);
            break :blk try Block.parse(.{ .allocator = allocator }, source);
        };
        defer block.deinit();
        try h.specified(&block, case.name, "var(--v)", allocator);
        try h.specified(&block, case.longhand.name(), "", allocator);
        const empty_longhand = try std.fmt.allocPrint(allocator, "{s}: ;", .{case.longhand.name()});
        defer allocator.free(empty_longhand);
        try expectText(&block, empty_longhand, allocator);
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "--v", "avoid", ""));
        const style = try h.compute(allocator, &block, null);
        defer style.destroy();
        try h.expect(style, case.name, "avoid", allocator);
        try h.expect(style, case.longhand.name(), "avoid", allocator);
        // A pending declaration authored on the longhand cannot reconstruct
        // the shorthand. This distinguishes a shorthand from a name alias.
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.longhand.name(), "var(--w)", ""));
        try h.specified(&block, case.name, "", allocator);
        try h.specified(&block, case.longhand.name(), "var(--w)", allocator);
    }
}

test "all CSS-wide keywords and real variable substitution keep existing shorthand behavior" {
    try wideAndPending(testing.allocator);
}

fn replacement(allocator: Allocator) !void {
    for (cases) |case| {
        _ = try shorthand(case.name);
        var block = Block.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.name, "avoid", ""));
        // Invalid assignment cannot erase a valid preceding assignment.
        try testing.expect(!try block.setProperty(.{ .allocator = allocator }, case.name, "column", ""));
        try h.specified(&block, case.name, "avoid", allocator);
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.longhand.name(), "auto", "important"));
        try h.specified(&block, case.name, "auto", allocator);
        try testing.expect(block.getPropertyPriority(case.name));
        var removed: std.ArrayList(u8) = .empty;
        defer removed.deinit(allocator);
        try testing.expect(try block.removeProperty(case.name, &removed));
        try testing.expectEqualStrings("auto", removed.items);
        try testing.expectEqual(@as(usize, 0), block.length());
    }
}

test "legacy assignments preserve invalid replacement, importance and removal contracts" {
    try replacement(testing.allocator);
}

test "legacy shorthand allocated paths release every injected allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, forward, .{});
    try testing.checkAllAllocationFailures(testing.allocator, parsedSource, .{});
    try testing.checkAllAllocationFailures(testing.allocator, initial, .{});
    try testing.checkAllAllocationFailures(testing.allocator, invalid, .{});
    try testing.checkAllAllocationFailures(testing.allocator, reverse, .{});
    try testing.checkAllAllocationFailures(testing.allocator, wideAndPending, .{});
    try testing.checkAllAllocationFailures(testing.allocator, replacement, .{});
}
