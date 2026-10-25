//! Typed scalar and radius components shared by the basic shapes.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub fn keyword(stream: *properties.Stream, text: []const u8) bool {
    const t = stream.peek();
    if (t.token_type != .ident or !tokenizer.nameEql(t.value, text)) return false;
    _ = stream.next();
    return true;
}

pub fn length(options: properties.ParseOptions, stream: *properties.Stream, negative: bool, percent: bool) Allocator.Error!?Value {
    // Borrow the scalar grammar, not margin's legacy unitless-length quirk.
    var strict = options;
    strict.quirks = false;
    if (@import("math_values.zig").isFunction(stream.peek())) {
        // Values4 §10: the component's range clamps the outer math result.
        return properties.mathValue(strict, stream, .{
            .kind = if (percent) .length_percentage else .length,
            .minimum = if (negative) -std.math.inf(f64) else 0,
        });
    }
    const mark = stream.*;
    const v = (try properties.parseLonghand(strict, .margin_left, stream)) orelse {
        stream.* = mark;
        return null;
    };
    if (v != .length or (!percent and v.length.unit == .percent) or (!negative and v.length.value < 0)) {
        v.release();
        stream.* = mark;
        return null;
    }
    return v;
}

pub const Quad = [4]Value;
pub const Radius = [2]Quad;

/// CSS Backgrounds3 §4.1: four horizontal and four vertical nonnegative radii.
pub fn radius(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Radius {
    var result: Radius = undefined;
    result[0] = (try quad(options, stream, false)) orelse return null;
    var transferred = false;
    defer if (!transferred) releaseQuad(result[0]);
    const t = stream.peek();
    if (t.token_type == .delim and std.mem.eql(u8, t.value, "/")) {
        _ = stream.next();
        result[1] = (try quad(options, stream, false)) orelse return null;
    } else {
        result[1] = result[0];
        for (result[1]) |v| v.retain();
    }
    transferred = true;
    return result;
}

/// Expand the one-to-four-value production. Each returned entry is owned.
pub fn quad(options: properties.ParseOptions, stream: *properties.Stream, negative: bool) Allocator.Error!?Quad {
    var result: Quad = undefined;
    var count: usize = 0;
    errdefer for (result[0..count]) |v| v.release();
    while (count < 4) : (count += 1) result[count] = (try length(options, stream, negative, true)) orelse break;
    if (count == 0) return null;
    while (count < 4) : (count += 1) {
        result[count] = result[if (count == 3) 1 else 0];
        result[count].retain();
    }
    return result;
}

pub fn releaseQuad(q: Quad) void {
    for (q) |v| v.release();
}
pub fn retainQuad(q: Quad) void {
    for (q) |v| v.retain();
}
pub fn zero(v: Value) bool {
    return v == .length and v.length.value == 0;
}
pub fn quadEql(a: Quad, b: Quad) bool {
    for (a, b) |x, y| if (!x.eql(y)) return false;
    return true;
}
pub fn serializeQuad(q: Quad, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    var count: usize = 4;
    if (q[1].eql(q[3])) {
        count = 3;
        if (q[0].eql(q[2])) {
            count = 2;
            if (q[0].eql(q[1])) count = 1;
        }
    }
    for (q[0..count], 0..) |v, i| {
        if (i > 0) try out.append(allocator, ' ');
        try properties.serializeValue(.margin_left, v, out, allocator);
    }
}
pub fn serializeRadius(r: Radius, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    var any_nonzero = false;
    for (r) |q| for (q) |v| {
        if (!zero(v)) {
            any_nonzero = true;
        }
    };
    if (!any_nonzero) return;
    try out.appendSlice(allocator, " round ");
    try serializeQuad(r[0], out, allocator);
    if (!quadEql(r[0], r[1])) {
        try out.appendSlice(allocator, " / ");
        try serializeQuad(r[1], out, allocator);
    }
}

/// A computed sum of a percentage and a length. Rectangle conversion
/// produces this even when the authored value contains no CSS math.
pub const Linear = struct {
    percentage: f64 = 0,
    px: f64 = 0,
    has_percent: bool = false,
    has_px: bool = false,

    pub fn from(v: Value) Linear {
        std.debug.assert(v == .length);
        return if (v.length.unit == .percent) .{ .percentage = v.length.value, .has_percent = true } else .{ .px = v.length.value, .has_px = true };
    }
    pub fn sub(self: *Linear, other: Linear) void {
        self.percentage -= other.percentage;
        self.px -= other.px;
        self.has_percent = self.has_percent or other.has_percent;
        self.has_px = self.has_px or other.has_px;
    }
    pub fn eql(self: Linear, other: Linear) bool {
        if (self.percentage != other.percentage or self.px != other.px) return false;
        return (self.has_percent or self.percentage != 0) == (other.has_percent or other.percentage != 0);
    }
    pub fn serialize(self: Linear, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self.px == 0 and self.has_percent) return values.appendLength(.percent(self.percentage), out, allocator);
        if (self.percentage == 0 and !self.has_percent) return values.appendLength(.px(self.px), out, allocator);
        try out.appendSlice(allocator, "calc(");
        try values.appendLength(.percent(self.percentage), out, allocator);
        try out.appendSlice(allocator, if (self.px < 0) " - " else " + ");
        try values.appendLength(.px(@abs(self.px)), out, allocator);
        try out.append(allocator, ')');
    }
};
