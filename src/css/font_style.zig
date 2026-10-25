//! CSS Fonts4 §2.4: oblique angles keep their specified units until compute.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math = @import("math_values.zig");
const tokens = @import("tokenizer.zig");
const angles = @import("image_angle.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Oblique = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    argument: union(enum) { angle: angles.Angle, calculation: *math.Expression },

    /// Retains a borrowed calculation, if present, after allocation succeeds.
    pub fn create(allocator: Allocator, argument: @FieldType(Oblique, "argument")) Allocator.Error!*Oblique {
        const result = try allocator.create(Oblique);
        result.* = .{ .allocator = allocator, .argument = argument };
        if (argument == .calculation) argument.calculation.ref();
        return result;
    }

    pub fn ref(self: *Oblique) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *Oblique) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.argument == .calculation) self.argument.calculation.unref();
        self.allocator.destroy(self);
    }

    pub fn eql(self: *const Oblique, other: *const Oblique) bool {
        if (self == other) return true;
        if (std.meta.activeTag(self.argument) != std.meta.activeTag(other.argument)) return false;
        return switch (self.argument) {
            .angle => |a| a.number == other.argument.angle.number and a.unit == other.argument.angle.unit,
            .calculation => |e| e.eql(other.argument.calculation),
        };
    }

    pub fn serialize(self: *const Oblique, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try out.appendSlice(allocator, "oblique ");
        switch (self.argument) {
            .angle => |a| {
                try values.appendNumber(a.number, out, allocator);
                try out.appendSlice(allocator, @tagName(a.unit));
            },
            .calculation => |expression| try expression.serialize(out, allocator),
        }
    }

    pub fn compute(self: *const Oblique, allocator: Allocator, context: math.Context) Allocator.Error!Value {
        const computed_degrees = switch (self.argument) {
            .angle => |a| a.degrees(),
            .calculation => |expression| blk: {
                const computed = try expression.compute(allocator, context);
                defer computed.unref();
                const number = computed.computedNumber() orelse {
                    // The candidate predicate filters unavailable metrics.
                    // Preserve any remaining typed expression; never invent.
                    return .{ .font_oblique = try create(allocator, .{ .calculation = computed }) };
                };
                std.debug.assert(number.unit == .deg);
                break :blk number.value;
            },
        };
        if (computed_degrees == 0) return Value.kw(.normal);
        return .{ .font_oblique = try create(allocator, .{ .angle = .{ .number = std.math.clamp(computed_degrees, -90, 90), .unit = .deg } }) };
    }

    pub fn needsUnavailableMetrics(self: *const Oblique) bool {
        return self.argument == .calculation and self.argument.calculation.needsUnavailableMetrics(false);
    }

    /// Values 5 §10: the angle keeps its expression's tree dependencies.
    pub fn needsTreeCounts(self: *const Oblique) bool {
        return self.argument == .calculation and self.argument.calculation.needsTreeCounts();
    }

    /// A literal or fixed-random angle needs no ambient random base.
    pub fn needsRandomBase(self: *const Oblique) bool {
        return self.argument == .calculation and self.argument.calculation.needsRandomBase();
    }

    /// Borrowed computed font-request input, with the default angle handled
    /// by the caller's plain `oblique` keyword branch.
    pub fn degrees(self: *const Oblique) ?f64 {
        return switch (self.argument) {
            .angle => |a| a.degrees(),
            .calculation => |e| if (e.computedNumber()) |n| (if (n.unit == .deg) n.value else null) else null,
        };
    }
};

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    const token = stream.next();
    if (token.token_type != .ident) return null;
    if (tokens.nameEql(token.value, "normal")) return Value.kw(.normal);
    if (tokens.nameEql(token.value, "italic")) return Value.kw(.italic);
    // Q26: no shipping browser accepts the newer left/right keywords.
    if (!tokens.nameEql(token.value, "oblique")) return null;
    if (math.isFunction(stream.peek())) {
        // An optional angle may instead be the following font-size in font.
        // Failed angle parsing leaves the stream untouched for that grammar.
        const value = (try properties.mathValue(options, stream, .{ .kind = .angle, .minimum = -90, .maximum = 90 })) orelse return Value.kw(.oblique);
        defer value.release();
        return .{ .font_oblique = try Oblique.create(options.allocator, .{ .calculation = value.calculation }) };
    }
    const angle = angles.parse(stream, false) orelse return Value.kw(.oblique);
    const degrees = angle.degrees();
    if (!std.math.isFinite(degrees) or degrees < -90 or degrees > 90) return null;
    if (degrees == 0) return Value.kw(.normal);
    return .{ .font_oblique = try Oblique.create(options.allocator, .{ .angle = angle }) };
}
