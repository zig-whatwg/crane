//! An element's computed style (CSS Cascade 5 section 4.4): one computed
//! value per supported longhand, and the resolved value getComputedStyle
//! serializes (CSSOM section 9).
//!
//! A logical longhand holds the value of the physical longhand it maps to
//! for this element's writing mode and direction, so that every supported
//! longhand reads directly.
//!
//! Resolved values without layout (stated; design section 6.3): CSSOM
//! makes the resolved value of width, height, the margins and the paddings
//! the USED value whenever the element has a box, and that needs layout.
//! With no layout host Crane answers the computed value - an absolute
//! length is its own used value; `auto` and percentages are answered as
//! computed, where a browser would answer the layout's number.
//!
//! Spec: https://drafts.csswg.org/css-cascade-5/#computed
//! Spec: https://drafts.csswg.org/cssom-1/#resolved-values

const std = @import("std");
const Allocator = std.mem.Allocator;
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const color_scheme = @import("color_scheme.zig");

const Longhand = properties.Longhand;
const Value = values.Value;
const Color = values.Color;

pub const ComputedStyle = struct {
    allocator: Allocator,
    values: [Longhand.count]Value,
    /// CSS Color Adjustment 1 2.2, the element color scheme: what its system
    /// colors were resolved against.
    used_color_scheme: color_scheme.Scheme = .light,

    /// A style whose every value is its longhand's initial value, computed
    /// (the root's parent; an element no rule styles).
    pub fn initial(allocator: Allocator) Allocator.Error!*ComputedStyle {
        const self = try allocator.create(ComputedStyle);
        self.* = .{ .allocator = allocator, .values = initial_values };
        return self;
    }

    pub fn destroy(self: *ComputedStyle) void {
        for (self.values) |v| v.release();
        self.allocator.destroy(self);
    }

    pub fn get(self: *const ComputedStyle, l: Longhand) Value {
        return self.values[@intFromEnum(l)];
    }

    pub fn keyword(self: *const ComputedStyle, l: Longhand) values.Keyword {
        const v = self.get(l);
        return if (v == .keyword) v.keyword else .none;
    }

    pub fn display(self: *const ComputedStyle) values.Display {
        return self.get(.display).display;
    }

    pub fn textTransform(self: *const ComputedStyle) values.TextTransform {
        const v = self.get(.text_transform);
        return if (v == .text_transform) v.text_transform else .{};
    }

    /// The used color of a color property: currentcolor is the element's
    /// `color` (CSS Color 4 6.4).
    pub fn usedColor(self: *const ComputedStyle, l: Longhand) values.RgbaColor {
        const v = self.get(l);
        const c = if (v == .color) v.color else Color.black;
        return c.absolute() orelse (self.get(.color).color.absolute() orelse values.RgbaColor.black);
    }

    /// Owned used color for CSSOM. Resolve against this element without
    /// reducing the result to an 8-bit physical destination.
    pub fn resolvedColor(self: *const ComputedStyle, l: Longhand, allocator: Allocator) Allocator.Error!Color {
        const value = self.get(l);
        const color = if (value == .color) value.color else Color.current;
        return color.resolveComputed(allocator, .{ .scheme = self.used_color_scheme, .current = self.get(.color).color });
    }

    /// CSSOM section 9: the resolved value of `l`, serialized into `out`.
    pub fn serializeResolved(self: *const ComputedStyle, l: Longhand, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        const v = self.get(l);
        // CSS Text4 §8.2's legacy resolved value: every computed zero is normal.
        if (l == .caret_color) return @import("ui_values.zig").serializeCaretResolved(v, .{ .scheme = self.used_color_scheme, .current = self.get(.color).color }, out, allocator);
        if (v == .color) {
            const color = try self.resolvedColor(l, allocator);
            defer color.release();
            return color.serializeComputed(out, allocator);
        }
        switch (properties.Longhand.info(l).grammar) {
            // "line-height: the resolved value is normal if the computed
            // value is normal, or the used value otherwise." A number's
            // used value is that many times the font size.
            .line_height => if (v == .number) {
                const size = self.get(.font_size).length.value;
                try values.appendNumber(v.number * size, out, allocator);
                return out.appendSlice(allocator, "px");
            },
            else => {},
        }
        try properties.serializeValue(l, v, out, allocator);
    }
};

/// Every longhand's initial value, as computed.
pub const initial_values: [Longhand.count]Value = blk: {
    @setEvalBranchQuota(100_000);
    var out: [Longhand.count]Value = undefined;
    for (0..Longhand.count) |i| {
        const l: Longhand = @enumFromInt(i);
        out[i] = initialComputed(l);
    }
    break :blk out;
};

/// A longhand's initial value, computed: the keyword lengths of borders
/// and font-size made absolute, and a border width with style none zero.
pub fn initialComputed(l: Longhand) Value {
    return switch (l) {
        .justify_items => .{ .alignment = .{ .position = .normal } },
        // The initial border-style is none, so the initial border-width
        // computes to 0 (CSS Backgrounds 3 "border-width" computed value).
        .border_top_width, .border_right_width, .border_bottom_width, .border_left_width, .border_block_start_width, .border_block_end_width, .border_inline_start_width, .border_inline_end_width => Value.px(0),
        .outline_width => Value.px(3),
        .font_size => Value.px(16),
        .font_weight => .{ .number = 400 },
        // CanvasText with no element to take a color scheme from: the UA
        // default's (light). The cascade resolves it per element.
        .color => .{ .color = .{ .rgba = values.RgbaColor.black } },
        else => l.info().initial,
    };
}

test "initial values compute" {
    const style = try ComputedStyle.initial(std.testing.allocator);
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try style.serializeResolved(.display, &out, std.testing.allocator);
    try std.testing.expectEqualStrings("inline", out.items);
    out.clearRetainingCapacity();
    try style.serializeResolved(.border_top_color, &out, std.testing.allocator);
    try std.testing.expectEqualStrings("rgb(0, 0, 0)", out.items);
    out.clearRetainingCapacity();
    try style.serializeResolved(.background_color, &out, std.testing.allocator);
    try std.testing.expectEqualStrings("rgba(0, 0, 0, 0)", out.items);
    out.clearRetainingCapacity();
    try style.serializeResolved(.border_left_width, &out, std.testing.allocator);
    try std.testing.expectEqualStrings("0px", out.items);
    out.clearRetainingCapacity();
    try style.serializeResolved(.font_family, &out, std.testing.allocator);
    try std.testing.expectEqualStrings("serif", out.items);
}
