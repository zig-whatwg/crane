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
    inline for (@typeInfo(math.Unit).@"enum".field_names, @typeInfo(math.Unit).@"enum".field_values) |field_name, field_value| {
        const unit: math.Unit = @fromBackingInt(@intCast(field_value));
        if (comptime unit != .number and unit != .percent) {
            if (std.ascii.eqlIgnoreCase(name, field_name)) return unit;
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

const Type = math.Type;
const Base = math.Base;
pub const Error = error{Invalid};

/// Apply a percentage hint, steps 1–4, with Q84's wrapping WebIDL long exponents.
fn applyHint(value: Type, hint: Base) Error!Type {
    var result = value;
    if (hint != .percent) {
        const h = @backingInt(hint);
        const p = @backingInt(Base.percent);
        result.powers[h] +%= result.powers[p];
        result.powers[p] = 0;
    }
    result.hint = hint;
    return result;
}

fn harmonize(a: *Type, b: *Type) Error!void {
    if (a.hint) |hint| {
        if (b.hint) |other| {
            if (hint != other) return error.Invalid;
        } else b.* = try applyHint(b.*, hint);
    } else if (b.hint) |hint| a.* = try applyHint(a.*, hint);
}

/// Add two types, steps 1–3. Unlike property parsing, a context-free value
/// can have an unhinted percentage; search every non-percent base type.
pub fn addTypes(lhs: Type, rhs: Type) Error!Type {
    var a = lhs;
    var b = rhs;
    try harmonize(&a, &b);
    if (std.mem.eql(i32, &a.powers, &b.powers)) return a;
    const p = @backingInt(Base.percent);
    if (a.powers[p] == 0 and b.powers[p] == 0) return error.Invalid;
    var has_other = false;
    for (a.powers[0..p], b.powers[0..p]) |x, y| has_other = has_other or x != 0 or y != 0;
    if (!has_other) return error.Invalid;
    for (0..p) |index| {
        const hint: Base = @fromBackingInt(@intCast(index));
        const x = applyHint(a, hint) catch continue;
        const y = applyHint(b, hint) catch continue;
        if (std.mem.eql(i32, &x.powers, &y.powers)) return x;
    }
    return error.Invalid;
}

/// Multiply two types, steps 1–5; Q84 wraps exponent overflow, never traps.
pub fn multiplyTypes(lhs: Type, rhs: Type) Error!Type {
    var a = lhs;
    var b = rhs;
    try harmonize(&a, &b);
    for (&a.powers, b.powers) |*power, other| power.* +%= other;
    return a;
}

/// Invert a type, steps 1–3. Q84 wraps the minimum exponent back to itself.
pub fn invertType(value: Type) Error!Type {
    var result = value;
    for (&result.powers) |*power| power.* = 0 -% power.*;
    return result;
}
