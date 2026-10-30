//! Typed OM §2/§3 list structure over Crane's native property models.
const std = @import("std");
const properties = @import("../properties.zig");
const values = @import("../style_values.zig");
const animation = @import("../animation_values.zig");
const layers = @import("../image_layers.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Kind = enum { single, animation, layers };

pub fn kind(property: properties.Property) Kind {
    if (property == .shorthand) return .single;
    const longhand = property.longhand;
    if (longhand.info().grammar == .animation_list) return .animation;
    for (@import("../background_values.zig").longhands[0..8]) |layer| if (layer == longhand) return .layers;
    for (@import("../mask_values.zig").longhands[0..8]) |layer| if (layer == longhand) return .layers;
    // Q68/Q69: shadows, try-fallbacks, anchor-name and anchor-scope
    // remain whole values in both shippers; append must reject them.
    return .single;
}

/// Inputs are grammar-validated, BORROWED values. Return one owned value.
pub fn concat(allocator: Allocator, longhand: properties.Longhand, input: []const Value) (Allocator.Error || error{Invalid})!Value {
    if (input.len == 0) return error.Invalid;
    switch (kind(.{ .longhand = longhand })) {
        .single => return error.Invalid,
        .animation => return .{ .animation_list = try animation.List.concat(allocator, longhand, input) orelse return error.Invalid },
        .layers => {
            var items: std.ArrayList(Value) = .empty;
            defer items.deinit(allocator);
            for (input) |value| {
                if (value == .layers) try items.appendSlice(allocator, value.layers.items) else try items.append(allocator, value);
            }
            if (items.items.len == 1) {
                items.items[0].retain();
                return items.items[0];
            }
            return .{ .layers = try layers.Layers.create(allocator, longhand, items.items) };
        },
    }
}
