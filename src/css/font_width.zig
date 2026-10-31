//! CSS Fonts4 §2.3: font-width keywords map to unresolved percentages.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Keyword = enum {
    ultra_condensed,
    extra_condensed,
    condensed,
    semi_condensed,
    normal,
    semi_expanded,
    expanded,
    extra_expanded,
    ultra_expanded,

    pub fn name(self: Keyword) []const u8 {
        return switch (self) {
            .ultra_condensed => "ultra-condensed",
            .extra_condensed => "extra-condensed",
            .semi_condensed => "semi-condensed",
            .semi_expanded => "semi-expanded",
            .extra_expanded => "extra-expanded",
            .ultra_expanded => "ultra-expanded",
            inline else => |k| @tagName(k),
        };
    }
    pub fn percentage(self: Keyword) f64 {
        return switch (self) {
            .ultra_condensed => 50,
            .extra_condensed => 62.5,
            .condensed => 75,
            .semi_condensed => 87.5,
            .normal => 100,
            .semi_expanded => 112.5,
            .expanded => 125,
            .extra_expanded => 150,
            .ultra_expanded => 200,
        };
    }
    pub fn parse(stream: *properties.Stream) ?Keyword {
        const token = stream.peek();
        if (token.token_type != .ident) return null;
        inline for (@typeInfo(Keyword).@"enum".field_values) |field_value| {
            const k: Keyword = @enumFromInt(field_value);
            if (tokens.nameEql(token.value, k.name())) {
                _ = stream.next();
                return k;
            }
        }
        return null;
    }
    pub fn fromPercentage(n: f64) ?Keyword {
        inline for (@typeInfo(Keyword).@"enum".field_values) |field_value| {
            const k: Keyword = @enumFromInt(field_value);
            if (n == k.percentage()) return k;
        }
        return null;
    }
};

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (Keyword.parse(stream)) |k| return .{ .font_width_keyword = k };
    const token = stream.peek();
    if (math.isFunction(token)) return properties.mathValue(options, stream, .{ .kind = .percentage, .minimum = 0 });
    if (token.token_type != .percentage) return null;
    const n = token.numeric_value orelse return null;
    if (!std.math.isFinite(n) or n < 0) return null;
    _ = stream.next();
    return .{ .length = .percent(n) };
}

/// The shared calculation step has already resolved a scalar calculation.
/// Percentages do not take the font-size as a percentage basis (§2.3).
pub fn compute(v: Value) Value {
    return switch (v) {
        .font_width_keyword => |k| .{ .length = .percent(k.percentage()) },
        .keyword => .{ .length = .percent(100) },
        else => blk: {
            v.retain();
            break :blk v;
        },
    };
}

/// Font's grammar can express only the legacy keyword widths (§2.7).
pub fn shorthandKeyword(v: Value) ?Keyword {
    return switch (v) {
        .font_width_keyword => |k| k,
        .keyword => |k| if (k == .normal) .normal else null,
        .length => |l| if (l.unit == .percent) Keyword.fromPercentage(l.value) else null,
        else => null,
    };
}
