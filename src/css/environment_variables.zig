//! CSS Environment Variables 1: the UA-defined names and value token text.
//!
//! https://drafts.csswg.org/css-env-1/#environment
//! https://w3c.github.io/virtual-keyboard/#keyboard-inset-variables
//! https://wicg.github.io/window-controls-overlay/#titlebar-area-env-variables
//!
//! This pure layer accepts decoded names and already-parsed indices. The host
//! supplies values through the platform protocol; the substitution engine owns
//! env() grammar, fallback selection and invalid-at-computed-value-time handling.

const std = @import("std");

/// Standardized variables; every value is a CSS-pixel length except the
/// unitless preferred text scale. Platform enum tags are converted by name,
/// never by their numeric representation.
pub const Variable = enum {
    safe_area_inset_top,
    safe_area_inset_right,
    safe_area_inset_bottom,
    safe_area_inset_left,
    safe_area_max_inset_top,
    safe_area_max_inset_right,
    safe_area_max_inset_bottom,
    safe_area_max_inset_left,
    keyboard_inset_top,
    keyboard_inset_right,
    keyboard_inset_bottom,
    keyboard_inset_left,
    keyboard_inset_width,
    keyboard_inset_height,
    titlebar_area_x,
    titlebar_area_y,
    titlebar_area_width,
    titlebar_area_height,
    viewport_segment_width,
    viewport_segment_height,
    viewport_segment_top,
    viewport_segment_right,
    viewport_segment_bottom,
    viewport_segment_left,
    preferred_text_scale,

    /// CSS Env 1 section 2: only viewport segment variables have dimensions.
    pub fn dimensions(self: Variable) u2 {
        return switch (self) {
            .viewport_segment_width,
            .viewport_segment_height,
            .viewport_segment_top,
            .viewport_segment_right,
            .viewport_segment_bottom,
            .viewport_segment_left,
            => 2,
            else => 0,
        };
    }
};

/// A recognized variable with the correct number of indices. Scalars have
/// x=y=0. Whether a segment exists is determined by the host, not this record.
pub const Query = struct {
    variable: Variable,
    x: u32 = 0,
    y: u32 = 0,
};

const names = std.StaticStringMap(Variable).initComptime(blk: {
    // Zig 0.17: @typeInfo is struct-of-arrays; rebuild the old field list.
    const fields = zig017_fields: {
        const zig017_info = @typeInfo(Variable).@"enum";
        var zig017_out: [zig017_info.field_names.len]struct { name: [:0]const u8, value: comptime_int } = undefined;
        for (zig017_info.field_names, zig017_info.field_values, 0..) |zig017_n, zig017_v, zig017_i| zig017_out[zig017_i] = .{ .name = zig017_n, .value = zig017_v };
        break :zig017_fields zig017_out;
    };
    var entries: [fields.len]struct { []const u8, Variable } = undefined;
    for (fields, 0..) |field, i| {
        var spelling: [field.name.len]u8 = undefined;
        for (field.name, 0..) |c, j| spelling[j] = if (c == '_') '-' else c;
        const name = spelling;
        entries[i] = .{ &name, @enumFromInt(field.value) };
    }
    break :blk entries;
});

/// CSS Env 1 section 3, substitution step 1: recognize the exact name and
/// require the variable's arity. No ASCII case folding or CSS token parsing.
/// Unknown names and wrong arities leave the caller to apply its fallback.
pub fn query(name: []const u8, indices: []const u32) ?Query {
    const variable = names.get(name) orelse return null;
    if (indices.len != variable.dimensions()) return null;
    return .{
        .variable = variable,
        .x = if (indices.len == 2) indices[0] else 0,
        .y = if (indices.len == 2) indices[1] else 0,
    };
}

/// Make the host value's CSS tokens, owned by the caller. A non-finite host
/// value cannot be represented as a CSS number/dimension token and gives no
/// value. A defined zero remains a value. OOM is propagated, not absence.
///
/// Preserve numeric precision here: these tokens may still participate in
/// calc() after substitution; CSSOM computed-value rounding happens later.
pub fn serialize(allocator: std.mem.Allocator, variable: Variable, value: f64) std.mem.Allocator.Error!?[]u8 {
    if (!std.math.isFinite(value)) return null;
    const number: f64 = if (value == 0) 0 else value;
    return try std.fmt.allocPrint(allocator, "{d}{s}", .{
        number,
        if (variable == .preferred_text_scale) @as([]const u8, "") else "px",
    });
}
