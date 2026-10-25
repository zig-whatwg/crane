//! Filter Effects1 §6.1–6.3 and Masking1 §8.3–8.5 component math.
//! Filter computed expectations include upstream filter-computed.html cases;
//! mask percentages remain percentages because their basis is image geometry.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Case = struct { name: []const u8, input: []const u8, expected: []const u8, specified: ?[]const u8 = null };

fn computed(allocator: Allocator, case: Case) !void {
    const property = css.properties.lookup(case.name) orelse return error.ExpectedProperty;
    const style = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px;color:red");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.name, case.input, ""));
        if (case.specified) |expected| {
            var text: std.ArrayList(u8) = .empty;
            defer text.deinit(allocator);
            try block.getPropertyValue(case.name, &text);
            try testing.expectEqualStrings(expected, text.items);
        }
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings(case.expected, out.items);
}

fn scalarFunction(allocator: Allocator, name: []const u8, clamps: bool) !void {
    for ([_]struct { expression: []const u8, result: []const u8 }{
        .{ .expression = "calc(300%)", .result = if (clamps) "1" else "3" },
        .{ .expression = "calc(3)", .result = if (clamps) "1" else "3" },
        .{ .expression = "calc(-10%)", .result = "0" },
        .{ .expression = "calc(-10)", .result = "0" },
        .{ .expression = "calc(50%)", .result = "0.5" },
    }) |case| {
        const input = try std.fmt.allocPrint(allocator, "{s}({s})", .{ name, case.expression });
        defer allocator.free(input);
        const expected = try std.fmt.allocPrint(allocator, "{s}({s})", .{ name, case.result });
        defer allocator.free(expected);
        try computed(allocator, .{ .name = "filter", .input = input, .expected = expected, .specified = input });
    }
}

test "filter math converts percentages and clamps only the outer numeric result" {
    for ([_][]const u8{ "brightness", "contrast", "saturate" }) |name|
        try testing.checkAllAllocationFailures(testing.allocator, scalarFunction, .{ name, false });
    for ([_][]const u8{ "grayscale", "invert", "opacity", "sepia" }) |name|
        try testing.checkAllAllocationFailures(testing.allocator, scalarFunction, .{ name, true });
}

test "filter length and angle math uses computed units without reducing whole turns" {
    for ([_]Case{
        .{ .name = "filter", .input = "blur(calc(100px))", .expected = "blur(100px)", .specified = "blur(calc(100px))" },
        .{ .name = "filter", .input = "blur(calc(1em - 10px))", .expected = "blur(30px)" },
        .{ .name = "filter", .input = "blur(calc(-10px))", .expected = "blur(0px)" },
        .{ .name = "filter", .input = "hue-rotate(calc(1turn + 90deg))", .expected = "hue-rotate(450deg)" },
        .{ .name = "filter", .input = "hue-rotate(calc(-0.25turn))", .expected = "hue-rotate(-90deg)" },
        .{ .name = "filter", .input = "drop-shadow(calc(-1em) calc(2px) calc(-1px))", .expected = "drop-shadow(rgb(255, 0, 0) -40px 2px 0px)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computed, .{case});
}

test "mask border math preserves slice percentages and computes only absolute lengths" {
    for ([_]Case{
        .{ .name = "mask-border-slice", .input = "calc(10 + 20) calc(20%) fill", .expected = "30 20% fill", .specified = "calc(30) calc(20%) fill" },
        .{ .name = "mask-border-slice", .input = "calc(-20%)", .expected = "0%" },
        .{ .name = "mask-border-width", .input = "calc(2) calc(10% + 1em)", .expected = "2 calc(10% + 40px)" },
        .{ .name = "mask-border-width", .input = "calc(-2) calc(-1em)", .expected = "0 0px" },
        .{ .name = "mask-border-outset", .input = "calc(2) calc(1em)", .expected = "2 40px" },
        .{ .name = "mask-border-outset", .input = "calc(-1em)", .expected = "0px" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computed, .{case});
}

fn dependencies(allocator: Allocator, name: []const u8, input: []const u8, tree: bool, random: bool, metrics: bool) !void {
    return dependencyModes(allocator, name, input, tree, random, metrics, metrics);
}

fn dependencyModes(allocator: Allocator, name: []const u8, input: []const u8, tree: bool, random: bool, metrics: bool, geometry_metrics: bool) !void {
    const property = css.properties.lookup(name) orelse return error.ExpectedProperty;
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, name, input, ""));
        const value = (block.get(property.longhand) orelse return error.ExpectedAssignment).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(tree, value.needsTreeCounts());
    try testing.expectEqual(random, value.needsRandomBase());
    try testing.expectEqual(metrics, value.needsUnavailableMetrics(false));
    try testing.expectEqual(geometry_metrics, value.needsUnavailableMetrics(true));
}

test "filter and mask border math retain all dependency queries after declaration release" {
    for ([_][]const u8{ "mask-border-slice", "mask-border-width", "mask-border-outset" }) |name| {
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ name, "calc(sibling-index())", true, false, false });
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ name, "random(1, 2)", false, true, false });
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ name, "random(fixed 0.5, 1, 2)", false, false, false });
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ name, "calc(sign(1cap - 1px))", false, false, true });
    }
    for ([_][]const u8{ "brightness(calc(sibling-index()))", "hue-rotate(calc(sibling-index() * 30deg))", "blur(calc(sibling-index() * 1px))", "drop-shadow(0px calc(sibling-index() * 1px))" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "filter", input, true, false, false });
    for ([_][]const u8{ "brightness(random(1, 2))", "hue-rotate(random(10deg, 20deg))", "blur(random(1px, 2px))", "drop-shadow(0px random(1px, 2px))" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "filter", input, false, true, false });
    for ([_][]const u8{ "brightness(random(fixed 0.5, 1, 2))", "hue-rotate(random(fixed 0.5, 10deg, 20deg))", "blur(random(fixed 0.5, 1px, 2px))" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "filter", input, false, false, false });
    for ([_][]const u8{ "brightness(calc(sign(1cap - 1px)))", "hue-rotate(calc(sign(1cap - 1px) * 1deg))" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "filter", input, false, false, true });
    // Q151: main's interim geometry mode permits an unresolved LENGTH,
    // whereas a scalar/angle containing a metric dependency stays unavailable.
    for ([_][]const u8{ "blur(calc(1cap))", "drop-shadow(0px calc(1cap))" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencyModes, .{ "filter", input, false, false, true, false });
}

test "filter extended length literals follow the same dependency modes as math" {
    // Q151 literal controls also expose the separate parser gap asked in Q152.
    for ([_][]const u8{ "blur(1cap)", "drop-shadow(0px 1cap)" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencyModes, .{ "filter", input, false, false, true, false });
}

fn literalFallback(allocator: Allocator, input: []const u8, fallback: []const u8) !void {
    const style = blk: {
        // Q154: CSSOM replaces a prior property in one block. Keep an earlier
        // candidate in its own block; the distinct blur(2px) catches defaulting.
        var earlier = css.declarations.DeclarationBlock.init(allocator);
        defer earlier.deinit();
        try testing.expect(try earlier.setProperty(.{ .allocator = allocator }, "filter", fallback, ""));
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "filter", input, ""));
        var specified: std.ArrayList(u8) = .empty;
        defer specified.deinit(allocator);
        try block.getPropertyValue("filter", &specified);
        try testing.expectEqualStrings(input, specified.items);
        // Q152 / Q17: accept the valid length, then let the single unavailable
        // check select the previous candidate instead of inventing cap height.
        try testing.expect(block.get(.filter).?.value.value.needsUnavailableMetrics(false));
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
            .{ .block = &earlier, .source = .{ .origin = .author, .order = 0 } },
            .{ .block = &block, .source = .{ .origin = .author, .order = 1 } },
        });
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.filter, &out, allocator);
    try testing.expectEqualStrings(fallback, out.items);
}

test "filter extended length literals preserve specified units and fall back without metrics" {
    // Filter Effects1 §6.1: signed shadow offsets and nonnegative radii are
    // Values4 lengths. Q152 requires the literal's ordinary CSSOM spelling.
    for ([_][]const u8{ "blur(1cap)", "drop-shadow(-1cap 1cap 1cap)" }) |input| {
        for ([_][]const u8{ "none", "blur(2px)" }) |fallback|
            try testing.checkAllAllocationFailures(testing.allocator, literalFallback, .{ input, fallback });
    }
}

fn invalidLiteral(allocator: Allocator, input: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    // CSSOM setProperty steps5–6: a rejected value keeps the supported control.
    const control = "blur(1cap)";
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "filter", control, ""));
    try testing.expect(!try block.setProperty(.{ .allocator = allocator }, "filter", input, ""));
    var specified: std.ArrayList(u8) = .empty;
    defer specified.deinit(allocator);
    try block.getPropertyValue("filter", &specified);
    try testing.expectEqualStrings(control, specified.items);
}

test "filter extended length literals reject negative radii and other dimensions" {
    // Q152 / Filter Effects1 §6.1: only the first two shadow lengths are signed.
    for ([_][]const u8{ "blur(-1cap)", "drop-shadow(0px 0px -1cap)", "blur(1deg)", "blur(1%)", "drop-shadow(0px 1deg)", "blur(1furlong)" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, invalidLiteral, .{input});
}

const Counts = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque) css.math_values.TreeCounts {
        const self: *Counts = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .{ .index = 3, .count = 7 };
    }
};
fn inherited(allocator: Allocator, name: []const u8, input: []const u8, allowed: bool, expected: []const u8) !void {
    const property = css.properties.lookup(name).?;
    var counts: Counts = .{};
    const child = blk: {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px");
        defer user.deinit();
        try testing.expect(try user.setProperty(.{ .allocator = allocator }, name, input, ""));
        var author = css.declarations.DeclarationBlock.init(allocator);
        defer author.deinit();
        try testing.expect(try author.setProperty(.{ .allocator = allocator }, name, "revert", ""));
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .tree_counts = .{ .context = &counts, .get = Counts.get } }, &.{
            .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
            .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
        });
        defer parent.destroy();
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:5px");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, name, "inherit", ""));
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author, .tree_count_allowed = !allowed } }});
    };
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
    try testing.expect(!child.get(property.longhand).needsTreeCounts());
}

test "filter and mask border math capture the winning source and computed inheritance" {
    for ([_]bool{ false, true }) |allowed| {
        try testing.checkAllAllocationFailures(testing.allocator, inherited, .{ "filter", "brightness(calc(sibling-index() + sign(1em - 10px)))", allowed, if (allowed) "brightness(4)" else "brightness(1)" });
        for ([_][]const u8{ "mask-border-slice", "mask-border-width", "mask-border-outset" }) |name|
            try testing.checkAllAllocationFailures(testing.allocator, inherited, .{ name, "calc(sibling-index() + sign(1em - 10px))", allowed, if (allowed) "4" else "1" });
    }
}

fn invalid(allocator: Allocator, name: []const u8, input: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(!try block.setProperty(.{ .allocator = allocator }, name, input, ""));
}

test "filter and mask border math reject dimensions outside each component grammar" {
    for ([_][]const u8{ "blur(calc(1%))", "blur(calc(1))", "hue-rotate(calc(1px))", "brightness(calc(1px))", "drop-shadow(calc(1%) 2px)" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, invalid, .{ "filter", input });
    for ([_][]const u8{ "calc(1px)", "calc(1 + 10%)" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, invalid, .{ "mask-border-slice", input });
    try testing.checkAllAllocationFailures(testing.allocator, invalid, .{ "mask-border-width", "calc(1 + 1px)" });
    try testing.checkAllAllocationFailures(testing.allocator, invalid, .{ "mask-border-outset", "calc(10%)" });
}

fn randomFallback(allocator: Allocator, name: []const u8, fallback: []const u8, fixed: bool) !void {
    const input = if (std.mem.eql(u8, name, "filter"))
        (if (fixed) "brightness(random(fixed 0.5, 1, 2))" else "brightness(random(1, 2))")
    else
        (if (fixed) "random(fixed 0.5, 1, 2)" else "random(1, 2)");
    const expected = if (!fixed) fallback else if (std.mem.eql(u8, name, "filter")) "brightness(1.5)" else "1.5";
    const property = css.properties.lookup(name).?;
    const style = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, name, fallback, ""));
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, name, input, ""));
        try testing.expectEqual(!fixed, block.get(property.longhand).?.value.value.needsRandomBase());
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "filter and mask border unavailable random falls back while fixed random computes" {
    for ([_]bool{ false, true }) |fixed| {
        try testing.checkAllAllocationFailures(testing.allocator, randomFallback, .{ "filter", "none", fixed });
        try testing.checkAllAllocationFailures(testing.allocator, randomFallback, .{ "mask-border-slice", "0", fixed });
        try testing.checkAllAllocationFailures(testing.allocator, randomFallback, .{ "mask-border-width", "auto", fixed });
        try testing.checkAllAllocationFailures(testing.allocator, randomFallback, .{ "mask-border-outset", "0", fixed });
    }
}
