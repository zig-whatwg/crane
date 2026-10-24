//! CSS Values4 §7.1 angles used by image and shape components.
const std = @import("std");
const properties = @import("properties.zig");
const tokenizer = @import("tokenizer.zig");
const values = @import("style_values.zig");

pub const Angle = struct {
    number: f64,
    unit: enum { deg, grad, rad, turn },
    pub fn degrees(self: Angle) f64 {
        return self.number * switch (self.unit) {
            .deg => @as(f64, 1),
            .grad => 0.9,
            .rad => 180.0 / std.math.pi,
            .turn => 360,
        };
    }
    pub fn serialize(self: Angle, out: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        try values.appendNumber(self.number, out, allocator);
        try out.appendSlice(allocator, @tagName(self.unit));
    }
};

pub fn parse(stream: *properties.Stream, allow_zero: bool) ?Angle {
    const t = stream.peek();
    const n = t.numeric_value orelse return null;
    if (allow_zero and t.token_type == .number and n == 0) {
        _ = stream.next();
        return .{ .number = 0, .unit = .deg };
    }
    if (t.token_type != .dimension) return null;
    const unit = t.unit orelse return null;
    inline for (.{ "deg", "grad", "rad", "turn" }) |name| {
        if (tokenizer.nameEql(unit, name)) {
            _ = stream.next();
            return .{ .number = n, .unit = @field(@FieldType(Angle, "unit"), name) };
        }
    }
    return null;
}
