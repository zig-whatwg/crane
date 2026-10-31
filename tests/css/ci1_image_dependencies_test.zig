//! Main's typed Color dependencies survive the public owned Image API.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Case = struct {
    declaration: []const u8,
    tree: bool = false,
    random: bool = false,
    metric: bool = false,
};

const Checks = if (@hasDecl(css, "image_values")) struct {
    const images = css.image_values;
    const Value = css.style_values.Value;

    fn expect(value: Value, case: Case) !void {
        try testing.expectEqual(case.tree, value.needsTreeCounts());
        try testing.expectEqual(case.random, value.needsRandomBase());
        try testing.expectEqual(case.metric, value.needsUnavailableMetrics(false));
        try testing.expectEqual(case.metric, value.needsUnavailableMetrics(true));
    }

    // pub: the tests below ask @hasDecl(Checks, ...), which Zig 0.17 answers for pub
    // declarations only (0.16 also for this file's own).
    pub fn run(allocator: Allocator, case: Case) !void {
        const color = blk: {
            var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, case.declaration);
            defer block.deinit();
            const value = (block.get(.color) orelse return error.ExpectedTypedColor).value.value;
            try testing.expect(value == .color);
            value.color.retain();
            break :blk value.color;
        };
        defer color.release();
        // Image.create owns a copy after the real declaration and parse scope
        // are destroyed. The test supplies no fabricated random parse key.
        const image: Value = .{ .image = try images.Image.create(allocator, .{ .solid_color = color }) };
        defer image.release();
        try expect(image, case);
        const fixed: Value = .{ .image = try images.Image.create(allocator, .{ .solid_color = css.style_values.Color.transparent }) };
        defer fixed.release();
        try expect(fixed, .{ .declaration = "" });
        for (0..2) |index| {
            var pair = [_]Value{ fixed, fixed };
            pair[index] = image;
            const choice: Value = .{ .image = try images.Image.create(allocator, .{ .light_dark = pair }) };
            defer choice.release();
            try expect(choice, case);
            const cross: Value = .{ .image = try images.Image.create(allocator, .{ .cross_fade = .{ .inputs = pair, .weight = 0.5 } }) };
            defer cross.release();
            try expect(cross, case);
            const set: Value = .{ .image = try images.Image.create(allocator, .{ .image_set = .{ .candidates = &.{
                .{ .image = fixed },
                .{ .image = cross, .resolution_dppx = 2, .resolution = .{ .number = 2 }, .resolution_explicit = true },
            } } }) };
            defer set.release();
            try expect(set, case);
        }
    }

    pub fn negative(allocator: Allocator) !void {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "background-image:image-set(url(a) 1x,url(b) 2x);" ++
            "content:light-dark(url(a),url(b));cursor:light-dark(url(a),url(b)),pointer");
        defer block.deinit();
        for ([_]css.properties.Longhand{ .background_image, .content, .cursor }) |longhand| {
            const value = (block.get(longhand) orelse return error.ExpectedImageDeclaration).value.value;
            try expect(value, .{ .declaration = "" });
        }
    }
} else struct {};

test "typed image composites retain real Color tree random and metric dependencies" {
    if (comptime !@hasDecl(Checks, "run")) return error.TypedImagesNotImplemented;
    for ([_]Case{
        .{ .declaration = "color:rgb(calc(sibling-index() * 20) 0 0)", .tree = true },
        .{ .declaration = "color:rgb(random(0, 200) 0 0)", .random = true },
        .{ .declaration = "color:rgb(random(fixed .5, 0, 200) 0 0)" },
        .{ .declaration = "color:rgb(calc(1cap / 1px) 0 0)", .metric = true },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, Checks.run, .{case});
}

test "literal and URL image content and cursor choices request no dependency" {
    if (comptime !@hasDecl(Checks, "negative")) return error.TypedImagesNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.negative, .{});
}
