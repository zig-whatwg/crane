//! UNRUN preparation: owned parser output, cascade, inherited computed values
//! and serialization are exercised under every std.testing allocation failure.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn lookup(name: []const u8) !css.properties.Property {
    return css.properties.lookup(name) orelse error.BorderRadiusNotImplemented;
}

fn parseOwned(allocator: Allocator, text: []const u8, expected: bool) !void {
    const radius = try lookup("border-radius");
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(allocator);
    }
    try testing.expectEqual(expected, try css.properties.parseDeclaration(.{ .allocator = allocator }, radius, text, &assignments));
    try testing.expectEqual(@as(usize, if (expected) 4 else 0), assignments.items.len);
    for (assignments.items) |a| {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try css.properties.serializeAssigned(a.longhand, a.value, &out, allocator);
        try testing.expect(out.items.len != 0);
    }
}

test "ci1_border_radius all OOM releases owned parse results and invalid tails" {
    const cases = .{
        .{ "calc(1em + 2px) 2% 3px / min(1em, 2px) 4%", true },
        .{ "calc(1em + 2px) / calc(2em + 1px) 4% 5px 6px 7px", false },
        .{ "calc(1em + 2px) /", false },
        .{ "calc(1em + 2px) 2% 3px 4px 5px", false },
    };
    inline for (cases) |case| try testing.checkAllAllocationFailures(testing.allocator, parseOwned, .{ case[0], case[1] });
}

fn inheritedOwnership(allocator: Allocator) !void {
    const corner = (try lookup("border-top-left-radius")).longhand;
    _ = try lookup("border-radius");
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px;border-radius:calc(1em + 2px) 5% / 25% calc(2px + 1em)");
    var owns_block = true;
    defer if (owns_block) block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    var owns_parent = true;
    defer if (owns_parent) parent.destroy();
    var inherit = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:10px;border-radius:inherit");
    var owns_inherit = true;
    defer if (owns_inherit) inherit.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherit, .source = .{ .origin = .author } }});
    defer child.destroy();
    const defaulted = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer defaulted.destroy();
    block.deinit();
    owns_block = false;
    inherit.deinit();
    owns_inherit = false;
    parent.destroy();
    owns_parent = false;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(corner, &out, allocator);
    try testing.expectEqualStrings("42px 25%", out.items);
    out.clearRetainingCapacity();
    try child.serializeResolved((try lookup("border-top-right-radius")).longhand, &out, allocator);
    try testing.expectEqualStrings("5% 42px", out.items);
    out.clearRetainingCapacity();
    try defaulted.serializeResolved(corner, &out, allocator);
    try testing.expectEqualStrings("0px", out.items);
}

test "ci1_border_radius all OOM child owns inherited pair after source and parent release" {
    try testing.checkAllAllocationFailures(testing.allocator, inheritedOwnership, .{});
}

fn extendedLiteral(allocator: Allocator, name: []const u8, text: []const u8, valid: bool) !void {
    const p = try lookup(name);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(allocator);
    }
    try testing.expectEqual(valid, try css.properties.parseDeclaration(.{ .allocator = allocator }, p, text, &assignments));
    if (valid) {
        try testing.expect(assignments.items.len != 0);
        for (assignments.items) |a| {
            // Acceptance has no dependency on an installed font metric.
            // Q97: the aggregate must forward both flags unchanged.
            try testing.expect(a.value.value.needsUnavailableMetrics(false));
            try testing.expect(!a.value.value.needsUnavailableMetrics(true));
        }
    } else try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

test "ci1_border_radius shared scalar literal seam on existing padding and clip path" {
    // Existing padding is the public nonnegative-scalar control. These
    // public clip-path paths reach f's shape_components.length before the
    // new radius family exists; no private import or future tag is needed.
    const cases = .{
        .{ "padding-left", "1cap", true },
        .{ "clip-path", "inset(0 round calc(1cap))", true },
        .{ "clip-path", "inset(0 round 1cap)", true },
        .{ "clip-path", "inset(0 round 1rcap / 2ic)", true },
        .{ "clip-path", "inset(0 round -1cap)", false },
    };
    inline for (cases) |case| try testing.checkAllAllocationFailures(testing.allocator, extendedLiteral, .{ case[0], case[1], case[2] });
}

test "ci1_border_radius radius accepts extended literal units without inventing metrics" {
    const cases = .{
        .{ "border-radius", "1cap / 2ric", true },
        .{ "border-top-left-radius", "1rcap 2ic", true },
        .{ "border-radius", "-1cap", false },
    };
    inline for (cases) |case| try testing.checkAllAllocationFailures(testing.allocator, extendedLiteral, .{ case[0], case[1], case[2] });
}

fn unavailableFallback(allocator: Allocator) !void {
    const p = (try lookup("border-top-left-radius")).longhand;
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "border-radius:3px / 4px");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "border-radius:calc(1cap) / calc(2cap)");
    defer high.deinit();
    try testing.expect(high.get(p) != null);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &low, .source = .{ .origin = .user } },
        .{ .block = &high, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(p, &out, allocator);
    // Proposed aggregate grammar remains outside the existing geometry
    // allowlist. This pins unchanged Q97 fallback, not made-up cap pixels.
    try testing.expectEqualStrings("3px 4px", out.items);
}

test "ci1_border_radius all OOM metric unavailable candidate retains existing fallback" {
    try testing.checkAllAllocationFailures(testing.allocator, unavailableFallback, .{});
}

const DependencyCase = struct {
    text: []const u8,
    tree: bool = false,
    random: bool = false,
};

fn dependencies(allocator: Allocator, case: DependencyCase) !void {
    const p = (try lookup("border-top-left-radius")).longhand;
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "border-top-left-radius", case.text, ""));
        const value = (block.get(p) orelse return error.ExpectedRadius).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(case.tree, value.needsTreeCounts());
    try testing.expectEqual(case.random, value.needsRandomBase());
    try testing.expect(!value.needsUnavailableMetrics(false));
    try testing.expectEqual(@as(usize, 0), value.resourceUrls().len);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(p, value, &out, allocator);
    try testing.expect(out.items.len != 0);
}

test "ci1_border_radius all OOM dependencies survive either pair axis and default stays false" {
    for ([_]DependencyCase{
        .{ .text = "0" },
        .{ .text = "1em 2%" },
        .{ .text = "calc(sibling-index() * 1px) 2px", .tree = true },
        .{ .text = "2px calc(sibling-count() * 1px)", .tree = true },
        .{ .text = "random(1px, 2px) 3px", .random = true },
        .{ .text = "3px random(1px, 2px)", .random = true },
        .{ .text = "random(fixed .5, 1px, 2px)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{case});
}
