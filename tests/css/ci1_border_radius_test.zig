//! UNRUN preparation: public APIs only; missing lookup is a runtime RED.
//! CSS Backgrounds3 §4.1; CSSOM §6.7; no used radii or geometry.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Assignment = css.properties.Assignment;

const corners = [_][]const u8{
    "border-top-left-radius",
    "border-top-right-radius",
    "border-bottom-right-radius",
    "border-bottom-left-radius",
};

fn property(name: []const u8) !css.properties.Property {
    return css.properties.lookup(name) orelse error.BorderRadiusNotImplemented;
}

fn expectText(block: *const css.declarations.DeclarationBlock, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(block.allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn expectParsed(allocator: Allocator, name: []const u8, text: []const u8, valid: bool) !void {
    var out: std.ArrayList(Assignment) = .empty;
    defer {
        for (out.items) |a| a.value.release();
        out.deinit(allocator);
    }
    try testing.expectEqual(valid, try css.properties.parseDeclaration(.{ .allocator = allocator }, try property(name), text, &out));
    if (!valid) try testing.expectEqual(@as(usize, 0), out.items.len);
}

test "ci1_border_radius all four longhands and shorthand are recognized" {
    const sh = try property("border-radius");
    try testing.expect(sh == .shorthand);
    try testing.expectEqual(@as(usize, 4), sh.shorthand.longhands().len);
    for (corners, sh.shorthand.longhands()) |name, l| {
        const p = try property(name);
        try testing.expect(p == .longhand);
        try testing.expectEqual(p.longhand, l);
        try testing.expect(!p.longhand.inherited());
    }
}

test "ci1_border_radius every horizontal and vertical arity expands independently" {
    // Expected corner pairs are the spec's TL TR BR BL order, independent
    // of the parser's internal representation and shorthand compression.
    const horizontal = [_][]const u8{ "1px", "1px 2px", "1px 2px 3px", "1px 2px 3px 4px" };
    const vertical = [_][]const u8{ "5%", "5% 6%", "5% 6% 7%", "5% 6% 7% 8%" };
    const hx = [_][4]u8{ .{ 1, 1, 1, 1 }, .{ 1, 2, 1, 2 }, .{ 1, 2, 3, 2 }, .{ 1, 2, 3, 4 } };
    const vy = [_][4]u8{ .{ 5, 5, 5, 5 }, .{ 5, 6, 5, 6 }, .{ 5, 6, 7, 6 }, .{ 5, 6, 7, 8 } };
    _ = try property("border-radius");
    for (horizontal, 0..) |h, hi| for (vertical, 0..) |v, vi| {
        const input = try std.fmt.allocPrint(testing.allocator, "border-radius:{s} / {s}", .{ h, v });
        defer testing.allocator.free(input);
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, input);
        defer block.deinit();
        try testing.expectEqual(@as(usize, 4), block.entries.items.len);
        for (corners, 0..) |name, i| {
            const expected = try std.fmt.allocPrint(testing.allocator, "{d}px {d}%", .{ hx[hi][i], vy[vi][i] });
            defer testing.allocator.free(expected);
            try expectText(&block, name, expected);
        }
    };
}

test "ci1_border_radius no slash copies axes and canonical serialization compresses" {
    const cases = [_][2][]const u8{
        .{ "1px 1px 1px 1px / 1px 1px", "1px" },
        .{ "1px 2px 1px 2px / 1px 2px 1px 2px", "1px 2px" },
        .{ "1px 2px 3px 2px / 1px 2px 3px 2px", "1px 2px 3px" },
        .{ "1px 2px 3px 4px / 1px 2px 3px 4px", "1px 2px 3px 4px" },
        .{ "1px 2px 1px 2px / 5% 6% 7% 6%", "1px 2px / 5% 6% 7%" },
        .{ "0", "0px" },
    };
    _ = try property("border-radius");
    for (cases) |case| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "border-radius", case[0], ""));
        try expectText(&block, "border-radius", case[1]);
        if (std.mem.eql(u8, case[1], "1px 2px")) {
            for (corners, [_][]const u8{ "1px", "2px", "1px", "2px" }) |name, expected| try expectText(&block, name, expected);
        }
    }
    for (corners) |name| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, name, "2em 2em", ""));
        try expectText(&block, name, "2em");
    }
}

test "ci1_border_radius invalid whole declaration leaves preceding assignments intact" {
    var out: std.ArrayList(Assignment) = .empty;
    defer {
        for (out.items) |a| a.value.release();
        out.deinit(testing.allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, try property("margin-left"), "7px", &out));
    const radius = try property("border-radius");
    for ([_][]const u8{
        "",
        "-1px",
        "1px -2%",
        "auto",
        "none",
        "1px /",
        "/ 1px",
        "1px // 2px",
        "1px 2px 3px 4px 5px",
        "1px / 1px 2px 3px 4px 5px",
        "1px, 2px",
        "1px 2",
        "inherit 1px",
        "1px !important",
        "calc(1px + 1deg)",
    }) |bad| {
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, radius, bad, &out));
        try testing.expectEqual(@as(usize, 1), out.items.len);
        try testing.expectEqualStrings("margin-left", out.items[0].longhand.name());
        try testing.expect(out.items[0].value.value.eql(css.style_values.Value.px(7)));
    }
    for (corners) |name| {
        try expectParsed(testing.allocator, name, "1px 2px 3px", false);
        try expectParsed(testing.allocator, name, "1px / 2px", false);
        try expectParsed(testing.allocator, name, "-1%", false);
    }
}

test "ci1_border_radius typed math accepted while negative literals are rejected" {
    for ([_][]const u8{ "0", "0%", "1in", "1em", "1rem", "1px / 2%", "calc(-10px)", "min(1em, 20px) / max(0px, 2%)" }) |good|
        try expectParsed(testing.allocator, "border-radius", good, true);
    for (corners) |name| try expectParsed(testing.allocator, name, "calc(10% + 2em) 40%", true);
}

test "ci1_border_radius computed values resolve lengths keep percentages and clamp math" {
    const cases = [_][3][]const u8{
        .{ "5em", "200px", "200px" },
        .{ "1in / 50%", "96px 50%", "96px / 50%" },
        .{ "calc(-0.5em + 10px)", "0px", "0px" },
        .{ "calc(0.5em + 10px) / 40%", "30px 40%", "30px / 40%" },
        .{ "calc(10px + 10%)", "calc(10% + 10px)", "calc(10% + 10px)" },
        .{ "calc(20px + 0%)", "calc(0% + 20px)", "calc(0% + 20px)" },
        .{ "9999px / 200%", "9999px 200%", "9999px / 200%" },
        .{ "0px / 10px", "0px 10px", "0px / 10px" },
        .{ "0% / 0px", "0% 0px", "0% / 0px" },
    };
    _ = try property("border-radius");
    for (cases) |case| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "font-size", "40px", ""));
        try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "border-radius", case[0], ""));
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        for (corners) |name| {
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(testing.allocator);
            try style.serializeResolved((try property(name)).longhand, &out, testing.allocator);
            try testing.expectEqualStrings(case[1], out.items);
        }
        var assigned: [4]css.properties.Assigned = undefined;
        for (corners, 0..) |name, i| assigned[i] = .{ .value = style.get((try property(name)).longhand) };
        var shorthand: std.ArrayList(u8) = .empty;
        defer shorthand.deinit(testing.allocator);
        try testing.expect(try css.properties.serializeShorthand((try property("border-radius")).shorthand, &assigned, .computed, &shorthand, testing.allocator));
        try testing.expectEqualStrings(case[2], shorthand.items);
    }
}

test "ci1_border_radius shorthand CSS wide and priority checks use all four corners" {
    _ = try property("border-radius");
    for ([_][]const u8{ "initial", "inherit", "unset", "revert", "revert-layer" }) |keyword| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "border-radius", keyword, "important"));
        try testing.expectEqual(@as(usize, 4), block.entries.items.len);
        try expectText(&block, "border-radius", keyword);
        for (corners) |name| {
            try expectText(&block, name, keyword);
            try testing.expect(block.getPropertyPriority(name));
        }
    }
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "border-radius:3px!important");
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, corners[0], "4px", ""));
    try expectText(&block, "border-radius", "");
    try testing.expect(!block.getPropertyPriority("border-radius"));
    try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, "border-radius", "1px /", ""));
    try expectText(&block, corners[0], "4px");
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(testing.allocator);
    try testing.expect(try block.removeProperty(corners[1], &removed));
    try expectText(&block, "border-radius", "");
}

test "ci1_border_radius border shorthand resets images and preserves every radius" {
    _ = try property("border-radius");
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "border-radius:1px 2px 3px 4px / 5px;border-image-source:url(old.png);border:solid red");
    defer block.deinit();
    try expectText(&block, "border-radius", "1px 2px 3px 4px / 5px");
    try expectText(&block, "border-image-source", "none");
    try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "all", "initial", ""));
    for (corners) |name| try expectText(&block, name, "initial");
}

test "ci1_border_radius pair equality covers vertical axis and equivalent omitted axis" {
    _ = try property(corners[0]);
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    const options = css.properties.ParseOptions{ .allocator = testing.allocator };
    try testing.expect(try block.setProperty(options, corners[0], "2px", ""));
    try testing.expect(!try block.setProperty(options, corners[0], "2px 2px", ""));
    try testing.expect(try block.setProperty(options, corners[0], "2px 3px", ""));
    try expectText(&block, corners[0], "2px 3px");
}
