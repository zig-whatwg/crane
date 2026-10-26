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
const custom_properties = @import("custom_properties.zig");

const Longhand = properties.Longhand;
const Value = values.Value;
const Color = values.Color;

pub const ComputedStyle = struct {
    allocator: Allocator,
    values: [Longhand.count]Value,
    /// CSS Color Adjustment 1 2.2, the element color scheme: what its system
    /// colors were resolved against.
    used_color_scheme: color_scheme.Scheme = .light,
    /// Grid 2 §9 / Display 4 §2.5: copied box ancestry facts, never a parent
    /// style pointer. display:contents forwards its nearest principal box;
    /// display:none suppresses all descendant boxes.
    box_context: enum { suppressed, grid, other } = .other,
    subgrid_ineligible: bool = false,
    /// CSS Variables 1 §2: the element's custom properties, computed; shared
    /// by reference with the parent's when this cascade changed none (one
    /// reference held). Null: none has a value.
    custom: ?*custom_properties.CustomProperties = null,

    /// A style whose every value is its longhand's initial value, computed
    /// (the root's parent; an element no rule styles).
    pub fn initial(allocator: Allocator) Allocator.Error!*ComputedStyle {
        const self = try allocator.create(ComputedStyle);
        self.* = .{ .allocator = allocator, .values = initial_values };
        return self;
    }

    pub fn destroy(self: *ComputedStyle) void {
        for (self.values) |v| v.release();
        if (self.custom) |c| c.release();
        self.allocator.destroy(self);
    }

    /// The computed value of custom property `name` (case-sensitive), or
    /// null for the guaranteed-invalid value (absent included). Borrowed.
    pub fn customValue(self: *const ComputedStyle, name: []const u8) ?*const custom_properties.Text {
        const record = self.custom orelse return null;
        return record.get(name);
    }

    /// The custom properties with a value, in code-point order (CSSOM
    /// getComputedStyle lists them after the longhands; integrator Q3).
    /// Borrowed names; the slice is the caller's.
    pub fn customNames(self: *const ComputedStyle, allocator: Allocator) Allocator.Error![]const []const u8 {
        const record = self.custom orelse return &.{};
        return record.names(allocator);
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

    /// Backgrounds 3 §3.3: whether `l` is a border width (physical or
    /// logical) whose same-side border style is none or hidden. Its computed
    /// value keeps the length; its resolved value, and a shorthand built from
    /// resolved values, is zero. A logical slot holds its mapped side's value,
    /// and so does the logical style beside it.
    pub fn undrawnBorderWidth(self: *const ComputedStyle, l: Longhand) bool {
        const side_style: Longhand = switch (l) {
            .border_top_width => .border_top_style,
            .border_right_width => .border_right_style,
            .border_bottom_width => .border_bottom_style,
            .border_left_width => .border_left_style,
            .border_block_start_width => .border_block_start_style,
            .border_block_end_width => .border_block_end_style,
            .border_inline_start_width => .border_inline_start_style,
            .border_inline_end_width => .border_inline_end_style,
            else => return false,
        };
        const k = self.keyword(side_style);
        return k == .none or k == .hidden;
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

    /// Owned image aggregate for CSSOM §6.7.2: resolve currentcolor for this
    /// receiver while preserving the inherited computed image (Color4 §15.5).
    pub fn resolvedImageValue(self: *const ComputedStyle, l: Longhand, allocator: Allocator) Allocator.Error!Value {
        return @import("image_values.zig").resolveCurrentColors(allocator, l, self.get(l), .{
            .scheme = self.used_color_scheme,
            .current = self.get(.color).color,
        });
    }

    /// CSSOM section 9: the resolved value of `l`, serialized into `out`.
    pub fn serializeResolved(self: *const ComputedStyle, l: Longhand, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        const v = self.get(l);
        // Grid 2 §§7.2.6, 9: only the resolved value of an ineligible
        // subgrid becomes none. The computed track object is unchanged.
        if ((l == .grid_template_columns or l == .grid_template_rows) and self.subgrid_ineligible and v == .grid_tracks and v.grid_tracks.subgrid)
            return out.appendSlice(allocator, "none");
        // CSS Text4 §8.2's legacy resolved value: every computed zero is normal.
        if (l == .letter_spacing and v == .length and v.length.value == 0)
            return out.appendSlice(allocator, "normal");
        if (l == .animation_duration) return @import("animation_values.zig").serializeDurationResolved(v, self.get(.animation_timeline), out, allocator);
        if (l == .caret_color) return @import("ui_values.zig").serializeCaretResolved(v, .{ .scheme = self.used_color_scheme, .current = self.get(.color).color }, out, allocator);
        // Backgrounds 3 §3.3: a side whose style is none or hidden keeps its
        // computed width (inherit passes it on) but resolves to zero.
        if (self.undrawnBorderWidth(l)) return out.appendSlice(allocator, "0px");
        if (v == .color) {
            const color = try self.resolvedColor(l, allocator);
            defer color.release();
            return color.serializeComputed(out, allocator);
        }
        // Q119/Q120: resolved size lists repeat against this receiver's images.
        if (l == .background_size) return @import("background_values.zig").serializeComputedSize(v, @import("image_layers.zig").count(self.get(.background_image)), out, allocator);
        if (v == .image or v == .layers or v == .content) {
            const resolved = try self.resolvedImageValue(l, allocator);
            defer resolved.release();
            return @import("resolved_urls.zig").serialize(l, resolved, out, allocator);
        }
        switch (properties.Longhand.info(l).grammar) {
            .paint => return @import("svg_paint.zig").serializeResolved(v, self.get(.color).color, out, allocator),
            .filter => if (v == .filter) return v.filter.serializeResolved(self.get(.color).color, out, allocator),
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
        try @import("resolved_urls.zig").serialize(l, v, out, allocator);
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
/// and font-size made absolute.
pub fn initialComputed(l: Longhand) Value {
    return switch (l) {
        .justify_items => .{ .alignment = .{ .position = .normal } },
        // Backgrounds 3 §3.3: initial `medium`, computed as an absolute
        // length whatever the style (the browsers' medium is 3px); only the
        // resolved value of an undrawn side is zero (serializeResolved).
        .border_top_width, .border_right_width, .border_bottom_width, .border_left_width, .border_block_start_width, .border_block_end_width, .border_inline_start_width, .border_inline_end_width => Value.px(3),
        .outline_width => Value.px(3),
        .font_size => Value.px(16),
        .font_weight => .{ .number = 400 },
        // CSS Fonts 4 §2.3: font-width's initial normal computes to 100%.
        .font_width => .{ .length = values.Length.percent(100) },
        .letter_spacing => Value.px(0),
        .word_spacing => Value.px(0),
        // CanvasText with no element to take a color scheme from: the UA
        // default's (light). The cascade resolves it per element.
        .color => .{ .color = .{ .rgba = values.RgbaColor.black } },
        .background_color => .{ .color = .{ .rgba = values.RgbaColor.transparent } },
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
