//! Nested math must keep its unavailable-metric requirement at aggregate edges.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Value = css.style_values.Value;

fn heldMetricValue() !Value {
    const parsed = (try css.math_values.parse(testing.allocator, "calc(1cap)", .{ .kind = .length_percentage })) orelse return error.MissingMath;
    return .{ .calculation = parsed.expression };
}

test "image aggregates forward metric requirements from all component positions" {
    const scalar = try heldMetricValue();
    defer scalar.release();
    try testing.expect(scalar.needsUnavailableMetrics(false));
    try testing.expect(!scalar.needsUnavailableMetrics(true));
    const Size = std.meta.Child(@FieldType(Value, "image_size"));
    const Quad = std.meta.Child(@FieldType(Value, "image_quad"));
    const Position = std.meta.Child(@FieldType(Value, "image_position"));
    const Layers = std.meta.Child(@FieldType(Value, "layers"));
    const Indent = std.meta.Child(@FieldType(Value, "indent"));
    for (0..4) |index| {
        var sides = @as([4]Value, @splat(Value.px(0)));
        sides[index] = scalar;
        const quad: Value = .{ .image_quad = try Quad.create(testing.allocator, sides, false) };
        defer quad.release();
        try testing.expect(quad.needsUnavailableMetrics(false));
        try testing.expect(!quad.needsUnavailableMetrics(true));
    }
    for (0..2) |index| {
        var axes = @as([2]Value, @splat(Value.px(0)));
        axes[index] = scalar;
        const size: Value = .{ .image_size = try Size.create(testing.allocator, axes) };
        defer size.release();
        try testing.expect(size.needsUnavailableMetrics(false));
        const position: Value = .{ .image_position = try Position.create(testing.allocator, .{
            .{ .edge = null, .offset = axes[0] }, .{ .edge = null, .offset = axes[1] },
        }, false) };
        defer position.release();
        try testing.expect(position.needsUnavailableMetrics(false));
        const layers: Value = .{ .layers = try Layers.create(testing.allocator, .mask_size, &.{ Value.kw(.auto), size }) };
        defer layers.release();
        try testing.expect(layers.needsUnavailableMetrics(false));
        try testing.expect(!layers.needsUnavailableMetrics(true));
    }
    const indent: Value = .{ .indent = try Indent.create(testing.allocator, scalar, .{ .hanging = true }) };
    defer indent.release();
    try testing.expect(indent.needsUnavailableMetrics(false));
}

test "filter shadow lengths keep metric dependencies beside their Color" {
    const scalar = try heldMetricValue();
    defer scalar.release();
    const Filter = std.meta.Child(@FieldType(Value, "filter"));
    for (0..3) |index| {
        var lengths = @as([3]Value, @splat(Value.px(0)));
        lengths[index] = scalar;
        const filter: Value = .{ .filter = try Filter.create(testing.allocator, &.{.{ .function = .{
            .kind = .drop_shadow,
            .argument = .{ .shadow = .{ .color = null, .lengths = lengths, .count = 3 } },
        } }}) };
        defer filter.release();
        try testing.expect(filter.needsUnavailableMetrics(false));
        try testing.expect(!filter.needsUnavailableMetrics(true));
    }
}
