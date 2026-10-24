//! A numeric component of a compound property. Literal units remain specified;
//! calculations use the shared CSS Values 4 tree and own exactly one reference.
//! Used by animation/easing and their related list-valued property grammars.
const std = @import("std");
const math = @import("math_values.zig");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const Allocator = std.mem.Allocator;

pub const Number = union(enum) {
    literal: math.Numeric,
    calculation: *math.Expression,

    pub fn scalar(value: f64) Number {
        return .{ .literal = .{ .value = value, .unit = .number } };
    }
    pub fn percent(value: f64) Number {
        return .{ .literal = .{ .value = value, .unit = .percent } };
    }
    pub fn ref(self: Number) void {
        if (self == .calculation) self.calculation.ref();
    }
    pub fn unref(self: Number) void {
        if (self == .calculation) self.calculation.unref();
    }
    pub fn eql(a: Number, b: Number) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .literal => |n| n.unit == b.literal.unit and
                (@as(u64, @bitCast(n.value)) == @as(u64, @bitCast(b.literal.value)) or
                    (std.math.isNan(n.value) and std.math.isNan(b.literal.value))),
            .calculation => |e| e.eql(b.calculation),
        };
    }
    pub fn needsUnavailableMetrics(self: Number, geometry_length: bool) bool {
        return self == .calculation and self.calculation.needsUnavailableMetrics(geometry_length);
    }
    pub fn needsTreeCounts(self: Number) bool {
        return self == .calculation and self.calculation.needsTreeCounts();
    }

    pub fn needsRandomBase(self: Number) bool {
        return self == .calculation and self.calculation.needsRandomBase();
    }
    pub fn known(self: Number) ?math.Numeric {
        return switch (self) {
            .literal => |n| if (n.unit == .number or n.unit == .percent) n else null,
            .calculation => |e| e.knownNumber(),
        };
    }
    pub fn compute(self: Number, allocator: Allocator, context: math.Context) Allocator.Error!Number {
        if (self == .calculation) {
            const expression = try self.calculation.compute(allocator, context);
            if (expression.computedNumber()) |n| {
                expression.unref();
                return .{ .literal = n };
            }
            return .{ .calculation = expression };
        }
        var n = context.resolve(self.literal);
        if (std.math.isNan(n.value)) n.value = 0;
        n.value = std.math.clamp(n.value, -std.math.floatMax(f64), std.math.floatMax(f64));
        if (n.value == 0) n.value = 0;
        return .{ .literal = n };
    }
    pub fn serialize(self: Number, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .calculation => |e| try e.serialize(out, allocator),
            .literal => |n| {
                try values.appendNumber(n.value, out, allocator);
                try out.appendSlice(allocator, n.unit.name());
            },
        }
    }

    /// Values 4 §10.9: calculations have their own type/range checks.
    /// Outside a function, reject an out-of-range or non-integer literal.
    pub fn consume(options: properties.ParseOptions, stream: *properties.Stream, grammar: math.Grammar, unitless_zero: bool) Allocator.Error!?Number {
        const token = stream.peek();
        if (math.isFunction(token)) {
            const value = try properties.mathValue(options, stream, grammar) orelse return null;
            return .{ .calculation = value.calculation };
        }
        const n = token.numeric_value orelse return null;
        var unit: math.Unit = switch (token.token_type) {
            .number => .number,
            .percentage => .percent,
            .dimension => math.Unit.parse(token.unit orelse return null) orelse return null,
            else => return null,
        };
        if (unitless_zero and unit == .number and n == 0 and (grammar.kind == .length or grammar.kind == .length_percentage)) unit = .px;
        const valid = switch (grammar.kind) {
            .number, .integer => unit == .number,
            .number_percentage => unit == .number or unit == .percent,
            .percentage => unit == .percent,
            .length => unit.base() == .length,
            .length_percentage => unit.base() == .length or unit == .percent,
            .length_percentage_number => unit.base() == .length or unit == .percent or unit == .number,
            .angle => unit.base() == .angle,
            .angle_percentage => unit.base() == .angle or unit == .percent,
            .time => unit.base() == .time,
            .resolution => unit.base() == .resolution,
            .flex => unit == .fr,
        };
        if (!valid or n < grammar.minimum or n > grammar.maximum or (grammar.kind == .integer and !token.is_integer)) return null;
        _ = stream.next();
        // Relative dimensions use the same tree/capability rule as scalar
        // properties; the compound owner supplies its computation context.
        const relative_length = unit.base() == .length and switch (unit) {
            .px, .cm, .mm, .q, .in, .pt, .pc => false,
            else => true,
        };
        if (relative_length) {
            const expression = try math.dimension(options.allocator, .{ .value = n, .unit = unit }, grammar) orelse return null;
            return .{ .calculation = expression };
        }
        return .{ .literal = .{ .value = n, .unit = unit } };
    }
};
