//! Masking §8.3–8.5 / Backgrounds §6: four typed border-image components.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const parts = @import("shape_components.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
pub const Grammar = enum { slice, width, outset };

pub const Quad = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    sides: [4]Value,
    fill: bool = false,

    pub fn create(allocator: Allocator, sides: [4]Value, fill: bool) Allocator.Error!*Quad {
        const self = try allocator.create(Quad);
        self.* = .{ .allocator = allocator, .sides = sides, .fill = fill };
        for (sides) |v| v.retain();
        return self;
    }
    pub fn ref(self: *Quad) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Quad) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.sides) |v| v.release();
        self.allocator.destroy(self);
    }
    pub fn needsUnavailableMetrics(self: *const Quad, geometry_length: bool) bool {
        for (self.sides) |value| if (value.needsUnavailableMetrics(geometry_length)) return true;
        return false;
    }

    pub fn needsTreeCounts(self: *const Quad) bool {
        for (self.sides) |value| if (value.needsTreeCounts()) return true;
        return false;
    }

    pub fn needsRandomBase(self: *const Quad) bool {
        for (self.sides) |value| if (value.needsRandomBase()) return true;
        return false;
    }

    pub fn eql(self: *const Quad, other: *const Quad) bool {
        if (self == other) return true;
        if (self.fill != other.fill) return false;
        for (self.sides, other.sides) |a, b| if (!a.eql(b)) return false;
        return true;
    }
    pub fn serialize(self: *const Quad, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try parts.serializeQuad(self.sides, out, allocator);
        if (self.fill) try out.appendSlice(allocator, " fill");
    }
    pub fn compute(self: *const Quad, allocator: Allocator, context: anytype) Allocator.Error!*Quad {
        var sides: [4]Value = undefined;
        var count: usize = 0;
        defer for (sides[0..count]) |v| v.release();
        while (count < 4) : (count += 1) {
            const v = self.sides[count];
            if (v == .length) sides[count] = try context.length(v) else {
                v.retain();
                sides[count] = v;
            }
        }
        return create(allocator, sides, self.fill);
    }
};

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream, grammar: Grammar) Allocator.Error!?Value {
    var sides: [4]Value = undefined;
    var count: usize = 0;
    defer for (sides[0..count]) |v| v.release();
    var fill = grammar == .slice and parts.keyword(stream, "fill");
    while (count < 4) : (count += 1) sides[count] = (try component(options, stream, grammar)) orelse break;
    if (count == 0) return null;
    if (grammar == .slice and !fill) fill = parts.keyword(stream, "fill");
    const expanded = [4]Value{ sides[0], sides[if (count > 1) 1 else 0], sides[if (count > 2) 2 else 0], sides[if (count > 3) 3 else if (count > 1) 1 else 0] };
    return .{ .image_quad = try Quad.create(options.allocator, expanded, fill) };
}
fn component(options: properties.ParseOptions, stream: *properties.Stream, grammar: Grammar) Allocator.Error!?Value {
    const t = stream.peek();
    if (t.token_type == .number or (grammar == .slice and t.token_type == .percentage)) {
        const n = t.numeric_value orelse return null;
        if (!std.math.isFinite(n) or n < 0) return null;
        _ = stream.next();
        return if (t.token_type == .number) .{ .number = n } else .{ .length = .percent(n) };
    }
    if (grammar == .slice) return null;
    if (grammar == .width and parts.keyword(stream, "auto")) return Value.kw(.auto);
    return parts.length(options, stream, false, grammar == .width);
}
