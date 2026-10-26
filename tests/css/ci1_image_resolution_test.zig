//! Images4 §6.1 / Values4 §7.4, under the Q146 spec rulings.
//! Negative literals are invalid; serialization uses canonical component order.
//! Snap rounding is a recorded FOLLOW-UP because the prose and example conflict.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Case = struct { input: []const u8, expected: []const u8 };

fn requireProperty() !void {
    if (css.properties.lookup("image-resolution") == null) return error.ImageResolutionNotImplemented;
}
fn specified(allocator: Allocator, case: Case) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "image-resolution", case.input, ""));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("image-resolution", &out);
    try testing.expectEqualStrings(case.expected, out.items);
}

test "image resolution validates the whole grammar and serializes canonical component order" {
    try requireProperty(); // Keep the missing-feature RED outside the OOM loop.
    for ([_]Case{
        .{ .input = "1dpi", .expected = "1dpi" },
        .{ .input = "2dpcm from-image", .expected = "from-image 2dpcm" },
        .{ .input = "3dppx from-image snap", .expected = "from-image 3dppx snap" },
        .{ .input = "4dpi snap", .expected = "4dpi snap" },
        .{ .input = "from-image", .expected = "from-image" },
        .{ .input = "from-image 5dpcm", .expected = "from-image 5dpcm" },
        .{ .input = "from-image 6dppx snap", .expected = "from-image 6dppx snap" },
        .{ .input = "from-image snap", .expected = "from-image snap" },
        .{ .input = "snap 7.5dpi", .expected = "7.5dpi snap" },
        .{ .input = "snap from-image", .expected = "from-image snap" },
        .{ .input = "snap from-image 0dppx", .expected = "from-image 0dppx snap" },
        .{ .input = "0dpi", .expected = "0dpi" },
        .{ .input = "-0dpi", .expected = "0dpi" },
        .{ .input = "calc(1dppx + 96dpi)", .expected = "calc(2dppx)" },
        .{ .input = "calc(-1dppx)", .expected = "calc(-1dppx)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, specified, .{case});
    for ([_][]const u8{ "inherit", "initial", "unset", "revert", "revert-layer" }) |keyword|
        try testing.checkAllAllocationFailures(testing.allocator, specified, .{Case{ .input = keyword, .expected = keyword }});
}

fn invalid(allocator: Allocator, input: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(!try block.setProperty(.{ .allocator = allocator }, "image-resolution", input, ""));
}

test "image resolution rejects negatives malformed groups and foreign dimensions" {
    try requireProperty();
    for ([_][]const u8{
        "",                     "auto",                  "none",                  "snap",       "100%",           "0",          "2",                       "1px",     "-1dpi",             "snap -8dpcm from-image",
        "3dpi snap from-image", "from-image snap 4dppx", "from-image from-image", "1dpi 2dppx", "snap snap 1dpi", "1dpi, 2dpi", "from-image 1dpi unknown", "calc(1)", "calc(1dpi + 1deg)", "calc(1dppx + 1%)",
    }) |input| try testing.checkAllAllocationFailures(testing.allocator, invalid, .{input});
}

fn computed(allocator: Allocator, case: Case) !void {
    const property = css.properties.lookup("image-resolution").?;
    const style = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "image-resolution", case.input, ""));
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings(case.expected, out.items);
}

test "image resolution computes canonical dppx and preserves snap without invented rounding" {
    try requireProperty();
    for ([_]Case{
        .{ .input = "96dpi", .expected = "1dppx" },
        .{ .input = "1x", .expected = "1dppx" },
        .{ .input = "0dpcm", .expected = "0dppx" },
        .{ .input = "from-image", .expected = "from-image" },
        .{ .input = "snap from-image", .expected = "from-image snap" },
        .{ .input = "300dpi snap", .expected = "3.125dppx snap" },
        .{ .input = "snap 72dpi from-image", .expected = "from-image 0.75dppx snap" },
        .{ .input = "calc(1dppx + 96dpi)", .expected = "2dppx" },
        .{ .input = "calc(-1dppx)", .expected = "0dppx" },
        .{ .input = "from-image calc(1dppx * sign(1em - 10px)) snap", .expected = "from-image 1dppx snap" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computed, .{case});
}

fn initialAndInheritance(allocator: Allocator, explicit: bool) !void {
    const property = css.properties.lookup("image-resolution").?;
    const initial = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{});
    defer initial.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try initial.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings("1dppx", out.items);
    const child = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px;image-resolution:from-image calc(1dppx * sign(1em - 10px)) snap");
        defer block.deinit();
        try testing.expect(block.get(property.longhand) != null);
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        var descendant = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, if (explicit) "font-size:5px;image-resolution:inherit" else "font-size:5px");
        defer descendant.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &descendant, .source = .{ .origin = .author } }});
    };
    defer child.destroy();
    out.clearRetainingCapacity();
    try child.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings("from-image 1dppx snap", out.items);
}

test "image resolution initial and implicit or explicit inheritance own their computed values" {
    try requireProperty();
    try testing.checkAllAllocationFailures(testing.allocator, initialAndInheritance, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, initialAndInheritance, .{true});
}

fn dependencies(allocator: Allocator, input: []const u8, tree: bool, random: bool, metrics: bool) !void {
    const property = css.properties.lookup("image-resolution").?;
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "image-resolution", input, ""));
        const value = block.get(property.longhand).?.value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(tree, value.needsTreeCounts());
    try testing.expectEqual(random, value.needsRandomBase());
    try testing.expectEqual(metrics, value.needsUnavailableMetrics(false));
    try testing.expectEqual(metrics, value.needsUnavailableMetrics(true));
}

test "image resolution retains real tree random and font metric dependencies" {
    try requireProperty();
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "from-image calc(sibling-index() * 1dppx) snap", true, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "random(1dppx, 2dppx)", false, true, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "random(fixed 0.5, 1dppx, 2dppx)", false, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "calc(1dppx * sign(1cap - 10px))", false, false, true });
}

const Counts = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque) css.math_values.TreeCounts {
        const self: *Counts = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .{ .index = 3, .count = 7 };
    }
};
fn source(allocator: Allocator, allowed: bool) !void {
    const property = css.properties.lookup("image-resolution").?;
    var counts: Counts = .{};
    const style = blk: {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px;image-resolution:calc(1dppx * (sibling-index() + sign(1em - 10px)))");
        defer user.deinit();
        try testing.expect(user.get(property.longhand) != null);
        var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "image-resolution:revert");
        defer author.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .tree_counts = .{ .context = &counts, .get = Counts.get } }, &.{
            .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
            .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
        });
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings(if (allowed) "4dppx" else "1dppx", out.items);
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
    try testing.expect(!style.get(property.longhand).needsTreeCounts());
}

test "image resolution uses the winning source after revert and releases source metadata" {
    try requireProperty();
    try testing.checkAllAllocationFailures(testing.allocator, source, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, source, .{true});
}

fn fallback(allocator: Allocator, input: []const u8, expected: []const u8) !void {
    const property = css.properties.lookup("image-resolution").?;
    const style = blk: {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "image-resolution:2dppx");
        defer user.deinit();
        var author = css.declarations.DeclarationBlock.init(allocator);
        defer author.deinit();
        try testing.expect(try author.setProperty(.{ .allocator = allocator }, "image-resolution", input, ""));
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
            .{ .block = &user, .source = .{ .origin = .user } },
            .{ .block = &author, .source = .{ .origin = .author } },
        });
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "image resolution falls back for unavailable random or metrics but computes fixed random" {
    try requireProperty();
    try testing.checkAllAllocationFailures(testing.allocator, fallback, .{ "random(1dppx, 2dppx)", "2dppx" });
    try testing.checkAllAllocationFailures(testing.allocator, fallback, .{ "calc(1dppx * sign(1cap - 10px))", "2dppx" });
    try testing.checkAllAllocationFailures(testing.allocator, fallback, .{ "random(fixed 0.5, 1dppx, 2dppx)", "1.5dppx" });
}
