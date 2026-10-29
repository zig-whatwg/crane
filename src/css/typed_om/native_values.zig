//! Reified opaque values retain the parsed/computed representation, not a
//! second parse of its serialization. Typed OM §§5.1–5.2 and 6.0.
const std = @import("std");
const properties = @import("../properties.zig");
const values = @import("../style_values.zig");
const math = @import("../math_values.zig");
const numeric = @import("numeric.zig");
const Allocator = std.mem.Allocator;

pub const Opaque = struct {
    allocator: Allocator,
    property: properties.Property,
    assignments: []properties.Assignment,
    computed: bool,
    /// A component of an animation list retains the whole immutable list.
    animation_index: ?usize = null,

    pub fn init(allocator: Allocator, property: properties.Property, assignments: []const properties.Assignment, computed: bool, animation_index: ?usize) Allocator.Error!Opaque {
        const copy = try allocator.dupe(properties.Assignment, assignments);
        for (copy) |assignment| assignment.value.retain();
        return .{ .allocator = allocator, .property = property, .assignments = copy, .computed = computed, .animation_index = animation_index };
    }

    pub fn deinit(self: *Opaque) void {
        for (self.assignments) |assignment| assignment.value.release();
        self.allocator.free(self.assignments);
    }

    pub fn serialize(self: Opaque, allocator: Allocator) Allocator.Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        switch (self.property) {
            .longhand => |l| {
                const assigned = self.assignments[0].value;
                if (self.animation_index) |index| {
                    try assigned.value.animation_list.items.items[index].serialize(l, &out, allocator);
                } else if (self.computed and assigned == .value) {
                    if (assigned.value == .color) {
                        try assigned.value.color.serializeComputed(&out, allocator);
                    } else try @import("../resolved_urls.zig").serialize(l, assigned.value, &out, allocator);
                } else try properties.serializeAssigned(l, assigned, &out, allocator);
            },
            .shorthand => |s| {
                var assigned: [properties.max_assignments]properties.Assigned = undefined;
                for (s.longhands(), 0..) |longhand, index| {
                    var found = false;
                    for (self.assignments) |assignment| if (assignment.longhand == longhand) {
                        assigned[index] = assignment.value;
                        found = true;
                        break;
                    };
                    if (!found) return allocator.dupe(u8, "");
                }
                if (!try properties.serializeShorthand(s, assigned[0..s.longhands().len], if (self.computed) .computed else .specified, &out, allocator)) return allocator.dupe(u8, "");
            },
        }
        return out.toOwnedSlice(allocator);
    }
};

/// Plain numeric leaf fields are already parsed. In particular no unitless
/// length exception, property range check, or CSS tokenizer is involved.
pub fn numericLeaf(longhand: properties.Longhand, value: values.Value) ?math.Numeric {
    return switch (value) {
        .length => |length| .{ .value = length.value, .unit = if (length.unit == .percent) .percent else numeric.parseUnit(@tagName(length.unit)).? },
        .number => |number| .{
            .value = number,
            .unit = switch (longhand) {
                // The allocation-free initial sentinels use seconds too.
                .animation_delay, .animation_duration, .transition_delay, .transition_duration => .s,
                else => .number,
            },
        },
        .integer => |integer| .{ .value = @floatFromInt(integer), .unit = .number },
        else => null,
    };
}

pub fn sameProperty(a: properties.Property, b: properties.Property) bool {
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
    return switch (a) {
        .longhand => |l| l == b.longhand,
        .shorthand => |s| s == b.shorthand,
    };
}
