//! Q114: image-set resolution expressions stay owned until computation;
//! selection consumes resolved candidates only. Images4 §2.4 and the exact
//! image-set-parsing.html:78–133 specified-value examples are pinned below.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Case = struct { property: []const u8 = "background-image", input: []const u8, expected: []const u8 };

fn specified(allocator: std.mem.Allocator, case: Case) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.property, case.input, ""));
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try block.getPropertyValue(case.property, &output);
    try testing.expectEqualStrings(case.expected, output.items);
}

test "image-set typed resolution math preserves every pinned specified example" {
    for ([_]Case{
        .{ .input = "image-set(url(\"example.png\") 1x)", .expected = "image-set(url(\"example.png\") 1x)" },
        .{ .input = "image-set(url(\"example.png\") calc(2x * 3))", .expected = "image-set(url(\"example.png\") calc(6dppx))" },
        .{ .input = "image-set(url(\"example.png\") 1dppx)", .expected = "image-set(url(\"example.png\") 1dppx)" },
        .{ .input = "image-set(url(\"example.png\") calc(1dppx * 1))", .expected = "image-set(url(\"example.png\") calc(1dppx))" },
        .{ .input = "image-set(url(\"example.png\") 1dpi)", .expected = "image-set(url(\"example.png\") 1dpi)" },
        .{ .input = "image-set(url(\"example.png\") calc(96dpi * 2))", .expected = "image-set(url(\"example.png\") calc(2dppx))" },
        .{ .input = "image-set(url(\"example.png\") 1dpcm)", .expected = "image-set(url(\"example.png\") 1dpcm)" },
        .{ .input = "image-set(url(\"example.png\") calc(1dpcm * 96/2.54))", .expected = "image-set(url(\"example.png\") calc(1dppx))" },
        .{ .input = "image-set(url(\"example.png\") 1x, url(\"example.png\") 2dppx, \"example.png\" 250dpi, \"example.png\" 1dpcm)", .expected = "image-set(url(\"example.png\") 1x, url(\"example.png\") 2dppx, url(\"example.png\") 250dpi, url(\"example.png\") 1dpcm)" },
        .{ .property = "content", .input = "image-set(url(\"example.png\") 1dpi)", .expected = "image-set(url(\"example.png\") 1dpi)" },
        .{ .property = "content", .input = "image-set(url(\"example.png\") calc(1 * 96dpi))", .expected = "image-set(url(\"example.png\") calc(1dppx))" },
        .{ .input = "image-set(url(\"example.png\") calc(1dppx * sibling-index()))", .expected = "image-set(url(\"example.png\") calc(1dppx * sibling-index()))" },
        .{ .input = "image-set(url(\"example.png\") calc(1dppx * sign(1em - 10px)))", .expected = "image-set(url(\"example.png\") calc(1dppx * sign(1em - 10px)))" },
        .{ .input = "image-set(url(\"example.png\") calc(1dppx * sign(10px)))", .expected = "image-set(url(\"example.png\") calc(1dppx))" },
    }) |case| {
        try testing.checkAllAllocationFailures(testing.allocator, specified, .{case});
        const prefixed = try std.fmt.allocPrint(testing.allocator, "-webkit-{s}", .{case.input});
        defer testing.allocator.free(prefixed);
        try testing.checkAllAllocationFailures(testing.allocator, specified, .{Case{ .property = case.property, .input = prefixed, .expected = case.expected }});
    }
}

const Checks = if (@hasDecl(css, "image_values")) struct {
    const images = css.image_values;
    const marker: u8 = 0;
    fn supports(_: *const anyopaque, _: []const u8) bool {
        return true;
    }

    fn parse(allocator: std.mem.Allocator, input: []const u8) !css.style_values.Value {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "list-style-image", input, ""));
        const result = (block.get(.list_style_image) orelse return error.ExpectedImage).value.value;
        result.retain();
        return result;
    }

    fn selection(allocator: std.mem.Allocator) !void {
        const support = images.TypeSupport{ .context = &marker, .supports = supports };
        // A usable literal comes first: returning that option would mask the
        // pending descriptor instead of rejecting this uncomputed set.
        const pending = try parse(allocator, "image-set(url(first) 1x, url(pending) calc(3dppx))");
        defer pending.release();
        const choices = images.view(pending).?.image_set.candidates;
        try testing.expectEqual(@as(?f64, 1), choices[0].resolutionDppx());
        try testing.expect(choices[1].resolutionDppx() == null);
        try testing.expect(choices[1].resolution_value != null);
        try testing.expect(images.select(choices, 1, support) == null);

        const literal = try parse(allocator, "image-set(url(default), url(explicit) 1x, url(zero) 0x, url(high) 3x)");
        defer literal.release();
        const candidates = images.view(literal).?.image_set.candidates;
        for (candidates, [_]f64{ 1, 1, 0, 3 }, 0..) |candidate, expected, index| {
            try testing.expect(candidate.resolution_value == null);
            try testing.expectEqual(@as(?f64, expected), candidate.resolutionDppx());
            try testing.expectEqual(index != 0, candidate.resolution_explicit);
        }
        try testing.expectEqual(@as(?usize, 0), images.select(candidates, 1, support));
        try testing.expectEqual(@as(?usize, 3), images.select(candidates, 2, support));
    }

    fn dependencies(allocator: std.mem.Allocator, descriptor: []const u8, tree: bool, random: bool, metrics: bool) !void {
        const input = try std.fmt.allocPrint(allocator, "image-set(url(a) {s})", .{descriptor});
        defer allocator.free(input);
        const value = try parse(allocator, input);
        defer value.release();
        try testing.expectEqual(tree, value.needsTreeCounts());
        try testing.expectEqual(random, value.needsRandomBase());
        try testing.expectEqual(metrics, value.needsUnavailableMetrics(false));
        // A resolution is not a geometry length even in a geometry context.
        try testing.expectEqual(metrics, value.needsUnavailableMetrics(true));
    }

    const Counts = struct {
        calls: usize = 0,
        fn get(raw: *anyopaque) css.math_values.TreeCounts {
            const self: *Counts = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .index = 3, .count = 7 };
        }
    };

    fn computed(allocator: std.mem.Allocator, allowed: bool) !void {
        var counts: Counts = .{};
        const child = blk: {
            var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px;list-style-image:image-set(url(tree) calc(1dppx * sibling-index()), url(font) calc(1dppx * sign(1em - 10px)), url(fixed) random(fixed 0.5, 2dppx, 4dppx))");
            defer user.deinit();
            try testing.expect(user.get(.list_style_image) != null);
            var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "list-style-image:revert");
            defer author.deinit();
            const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .tree_counts = .{ .context = &counts, .get = Counts.get } }, &.{
                .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
                .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
            });
            defer parent.destroy();
            var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:5px;list-style-image:inherit");
            defer inherited.deinit();
            break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherited, .source = .{ .origin = .author, .tree_scope = .{ .serial = 1234 }, .tree_count_allowed = !allowed } }});
        };
        defer child.destroy();
        const set = images.view(child.get(.list_style_image)).?.image_set;
        for (set.candidates, [_]f64{ if (allowed) 3 else 0, 1, 3 }) |candidate, wanted| {
            try testing.expect(candidate.resolution_value == null);
            try testing.expectEqual(@as(?f64, wanted), candidate.resolutionDppx());
        }
        try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
        try testing.expectEqual(@as(?usize, if (allowed) 0 else 2), images.select(set.candidates, 2, .{ .context = &marker, .supports = supports }));
    }
} else struct {};

test "selection rejects a pending resolution set and preserves literal default zero semantics" {
    if (comptime !@hasDecl(css, "image_values")) return error.TypedImagesNotImplemented;
    if (comptime !@hasDecl(css.image_values.Candidate, "resolutionDppx")) return error.ResolutionAccessorNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.selection, .{});
}

test "typed resolution descriptors forward tree random and font metric dependencies" {
    if (comptime !@hasDecl(css, "image_values")) return error.TypedImagesNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.dependencies, .{ "calc(1dppx * sibling-index())", true, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, Checks.dependencies, .{ "random(1dppx, 2dppx)", false, true, false });
    try testing.checkAllAllocationFailures(testing.allocator, Checks.dependencies, .{ "random(fixed 0.5, 1dppx, 2dppx)", false, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, Checks.dependencies, .{ "calc(1dppx * sign(1cap - 10px))", false, false, true });
}

test "every computed resolution is numeric and survives winning-source declaration and parent release" {
    if (comptime !@hasDecl(css, "image_values")) return error.TypedImagesNotImplemented;
    if (comptime !@hasDecl(css.image_values.Candidate, "resolutionDppx")) return error.ResolutionAccessorNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.computed, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, Checks.computed, .{true});
}
