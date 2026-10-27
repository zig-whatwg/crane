//! CSS Typed OM 1 §§4.3.2–3 and 6.4, using CSS Values' existing units.
const std = @import("std");
const math = @import("../math_values.zig");
const values = @import("../style_values.zig");

/// Create a type, steps 1–9. Integrator browser probe (Chrome 156 / Safari
/// 27, 2026-10-27): dimensions match ASCII case-insensitively and store the
/// lowercase unit, including x; CSS escapes are invalid in both. NUMBER,
/// PERCENT and % split, so the spec's exact "number" / "percent" wins.
/// This converts an IDL unit name; it does not parse CSS token input.
pub fn parseUnit(name: []const u8) ?math.Unit {
    if (std.mem.eql(u8, name, "number")) return .number;
    if (std.mem.eql(u8, name, "percent")) return .percent;
    inline for (@typeInfo(math.Unit).@"enum".fields) |field| {
        const unit: math.Unit = @enumFromInt(field.value);
        if (comptime unit != .number and unit != .percent) {
            if (std.ascii.eqlIgnoreCase(name, field.name)) return unit;
        }
    }
    return null;
}

/// §6.4 steps 1–5, with no property's optional min/max restrictions.
/// The caller owns the returned CSSOM string.
pub fn serialize(allocator: std.mem.Allocator, number: math.Numeric) std.mem.Allocator.Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try values.appendNumber(number.value, &out, allocator);
    try out.appendSlice(allocator, number.unit.name());
    return out.toOwnedSlice(allocator);
}
