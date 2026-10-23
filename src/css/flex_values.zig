//! CSS Flexbox 1 §§7.1–7.2.3: flexibility values, independent of flex layout.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const Number = @import("numeric_values.zig").Number;
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Stream = properties.Stream;

pub fn consumeFactor(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const start = stream.*;
    const number = try Number.consume(options, stream, .{ .kind = .number, .minimum = 0 }, false) orelse {
        stream.* = start;
        return null;
    };
    return switch (number) {
        .literal => |n| .{ .number = n.value },
        .calculation => |expression| .{ .calculation = expression },
    };
}

fn consumeBasis(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const start = stream.*;
    const value = try properties.parseLonghand(options, .flex_basis, stream);
    if (value == null) stream.* = start;
    return value;
}

pub fn consumeShorthand(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    var components: [3]Value = .{ .{ .number = 1 }, .{ .number = 1 }, .{ .length = values.Length.percent(0) } };
    defer for (components) |value| value.release();
    const first = stream.peek();
    if (first.token_type == .ident and @import("tokenizer.zig").nameEql(first.value, "none")) {
        _ = stream.next();
        components = .{ .{ .number = 0 }, .{ .number = 0 }, Value.kw(.auto) };
    } else if (try consumeFactor(options, stream)) |grow| {
        components[0] = grow;
        // §7.1: the two flex factors are a single, ordered component.
        if (try consumeFactor(options, stream)) |shrink| components[1] = shrink;
        if (try consumeBasis(options, stream)) |basis| components[2] = basis;
        // Q79: browsers unanimously use 0% for the omitted basis, while
        // explicit third unitless zero is parsed by flex-basis as 0px.
    } else if (try consumeBasis(options, stream)) |basis| {
        components[2] = basis;
        if (try consumeFactor(options, stream)) |grow| {
            components[0] = grow;
            if (try consumeFactor(options, stream)) |shrink| components[1] = shrink;
        }
    } else return false;
    if (!stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, components.len);
    for (properties.Shorthand.flex.longhands(), components) |longhand, value| {
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = value } });
    }
    return true;
}

pub fn serializeShorthand(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    // Flexbox 1 §7.1: serialize all three components in grow/shrink/basis order.
    for (properties.Shorthand.flex.longhands(), assigned, 0..) |longhand, value, index| {
        if (index != 0) try out.append(allocator, ' ');
        try properties.serializeValue(longhand, value.value, out, allocator);
    }
    return true;
}
