//! The CSS properties Crane supports: each longhand's name, whether it is
//! inherited, its initial value and its grammar; each shorthand's
//! longhands and grammar; and the serialization of their values. A property
//! that is not here is not a "supported CSS property" (CSSOM 6.6.1):
//! getPropertyValue answers "", it is not enumerated, CSS.supports is false.
//!
//! The set (tmp/plans/style-design.md section 6.1) is what the 0.1
//! worklist reads plus what HTML's UA style sheet and innerText need.
//! Value grammars follow each property's definition table:
//!
//! - CSS Display 4: display, visibility
//! - CSS Positioned Layout 3: position, top/right/bottom/left, inset-*, z-index
//! - CSS 2.1 9.5.1 / CSS Logical 1: float
//! - CSS Writing Modes 4: direction, unicode-bidi, writing-mode
//! - CSS Color 4: color, opacity; CSS Backgrounds 3: background-*, border-*
//! - CSS Box 4 / Sizing 3: margin-*, padding-*, width, height
//! - CSS Fonts 4: font-family, font-size, font-style, font-weight
//! - CSS Inline 3 / CSS 2.1: line-height
//! - CSS Text 4: white-space-collapse, text-wrap-mode, white-space, text-transform
//! - CSS Overflow 3: overflow-x, overflow-y, overflow
//! - CSS UI 4: appearance
//! - CSS Cascade 5: all
//!
//! Stated deviations: math functions (calc() and friends) and var() make a
//! declaration invalid until the numeric-expression capability lands
//! (design section 6.1); an <image> other than none/url() is kept as
//! written, unresolved; system colors resolve to the light palette at parse
//! time (color-scheme is a later batch).
//!
//! Spec: https://drafts.csswg.org/css-cascade-5/#shorthand
//! Spec: https://drafts.csswg.org/cssom-1/#serializing-css-values

const std = @import("std");
const Allocator = std.mem.Allocator;
const tokenizer_mod = @import("tokenizer.zig");
const Tokenizer = tokenizer_mod.Tokenizer;
const Token = tokenizer_mod.Token;
const values = @import("style_values.zig");
const color_mod = @import("values/color.zig");
const length_mod = @import("values/length.zig");
const ParserContext = @import("context.zig").ParserContext;

const Value = values.Value;
const Keyword = values.Keyword;
const Length = values.Length;
const LengthUnit = values.LengthUnit;
const Color = values.Color;
const Display = values.Display;
const SharedText = values.SharedText;

// ============================================================================
// The longhands
// ============================================================================

/// Every supported longhand. Logical longhands are here too: they hold
/// declarations, and the cascade maps them onto physical ones.
pub const Longhand = enum(u8) {
    appearance,
    background_color,
    background_image,
    border_block_end_color,
    border_block_end_style,
    border_block_end_width,
    border_block_start_color,
    border_block_start_style,
    border_block_start_width,
    border_bottom_color,
    border_bottom_style,
    border_bottom_width,
    border_inline_end_color,
    border_inline_end_style,
    border_inline_end_width,
    border_inline_start_color,
    border_inline_start_style,
    border_inline_start_width,
    border_left_color,
    border_left_style,
    border_left_width,
    border_right_color,
    border_right_style,
    border_right_width,
    border_top_color,
    border_top_style,
    border_top_width,
    bottom,
    color,
    direction,
    display,
    float,
    font_family,
    font_size,
    font_style,
    font_weight,
    height,
    inset_block_end,
    inset_block_start,
    inset_inline_end,
    inset_inline_start,
    left,
    line_height,
    margin_block_end,
    margin_block_start,
    margin_bottom,
    margin_inline_end,
    margin_inline_start,
    margin_left,
    margin_right,
    margin_top,
    opacity,
    overflow_x,
    overflow_y,
    padding_block_end,
    padding_block_start,
    padding_bottom,
    padding_inline_end,
    padding_inline_start,
    padding_left,
    padding_right,
    padding_top,
    position,
    right,
    text_transform,
    text_wrap_mode,
    top,
    unicode_bidi,
    visibility,
    white_space_collapse,
    width,
    writing_mode,
    z_index,

    pub const count = @typeInfo(Longhand).@"enum".fields.len;

    /// The property name.
    pub fn name(self: Longhand) []const u8 {
        return switch (self) {
            inline else => |l| comptime dashedName(@tagName(l)),
        };
    }

    pub fn info(self: Longhand) *const Info {
        return &infos[@intFromEnum(self)];
    }

    pub fn inherited(self: Longhand) bool {
        return self.info().inherited;
    }

    /// The physical group and side a logical longhand maps onto (CSS
    /// Logical 1), or null for a physical one.
    pub fn logical(self: Longhand) ?Logical {
        return self.info().logical;
    }
};

/// The longhands in lexicographic order of their names (CSSOM 7.2 step 5),
/// which the enum's declaration order already is.
pub const lexicographic: [Longhand.count]Longhand = blk: {
    @setEvalBranchQuota(100_000);
    var out: [Longhand.count]Longhand = undefined;
    for (0..Longhand.count) |i| out[i] = @enumFromInt(i);
    for (1..Longhand.count) |i| {
        if (!std.mem.lessThan(u8, out[i - 1].name(), out[i].name()))
            @compileError("Longhand must be declared in lexicographic order: " ++ out[i].name());
    }
    break :blk out;
};

fn dashedName(comptime tag: []const u8) []const u8 {
    @setEvalBranchQuota(10_000);
    comptime var out: [tag.len]u8 = undefined;
    for (tag, 0..) |c, i| out[i] = if (c == '_') '-' else c;
    const final = out;
    return &final;
}

/// A logical longhand's mapping: its group and its abstract side.
pub const Logical = struct {
    group: Group,
    side: Side,

    pub const Group = enum { margin, padding, inset, border_width, border_style, border_color };
    pub const Side = enum { block_start, block_end, inline_start, inline_end };
};

pub const PhysicalSide = enum { top, right, bottom, left };

/// CSS Writing Modes 4 section 6.4 / CSS Logical 1 section 3: the physical
/// side an abstract side is, for a writing mode and direction.
pub fn physicalSide(side: Logical.Side, writing_mode: Keyword, direction: Keyword) PhysicalSide {
    const rtl = direction == .rtl;
    return switch (writing_mode) {
        .vertical_rl, .sideways_rl => switch (side) {
            .block_start => .right,
            .block_end => .left,
            .inline_start => if (rtl) .bottom else .top,
            .inline_end => if (rtl) .top else .bottom,
        },
        .vertical_lr => switch (side) {
            .block_start => .left,
            .block_end => .right,
            .inline_start => if (rtl) .bottom else .top,
            .inline_end => if (rtl) .top else .bottom,
        },
        .sideways_lr => switch (side) {
            .block_start => .left,
            .block_end => .right,
            .inline_start => if (rtl) .top else .bottom,
            .inline_end => if (rtl) .bottom else .top,
        },
        else => switch (side) {
            .block_start => .top,
            .block_end => .bottom,
            .inline_start => if (rtl) .right else .left,
            .inline_end => if (rtl) .left else .right,
        },
    };
}

/// The physical longhand of `group` on `side`.
pub fn physicalLonghand(group: Logical.Group, side: PhysicalSide) Longhand {
    return switch (group) {
        .margin => switch (side) {
            .top => .margin_top,
            .right => .margin_right,
            .bottom => .margin_bottom,
            .left => .margin_left,
        },
        .padding => switch (side) {
            .top => .padding_top,
            .right => .padding_right,
            .bottom => .padding_bottom,
            .left => .padding_left,
        },
        .inset => switch (side) {
            .top => .top,
            .right => .right,
            .bottom => .bottom,
            .left => .left,
        },
        .border_width => switch (side) {
            .top => .border_top_width,
            .right => .border_right_width,
            .bottom => .border_bottom_width,
            .left => .border_left_width,
        },
        .border_style => switch (side) {
            .top => .border_top_style,
            .right => .border_right_style,
            .bottom => .border_bottom_style,
            .left => .border_left_style,
        },
        .border_color => switch (side) {
            .top => .border_top_color,
            .right => .border_right_color,
            .bottom => .border_bottom_color,
            .left => .border_left_color,
        },
    };
}

/// A longhand's grammar.
pub const Grammar = enum {
    keywords,
    /// <length-percentage> | auto (margins, insets)
    length_percentage_auto,
    /// <length-percentage [0,inf]> (padding)
    length_percentage_nonneg,
    /// auto | <length-percentage [0,inf]> | min-content | max-content | fit-content
    size,
    line_width,
    color,
    image,
    display,
    font_family,
    font_size,
    font_weight,
    line_height,
    opacity,
    z_index,
};

pub const Info = struct {
    longhand: Longhand,
    inherited: bool,
    initial: Value,
    grammar: Grammar,
    keywords: []const Keyword = &.{},
    logical: ?Logical = null,
    /// Quirks mode's unitless length (Quirks 3.2) applies.
    quirky_length: bool = false,
    /// Quirks mode's hashless hex color (Quirks 3.1) applies.
    quirky_color: bool = false,
};

const border_styles = [_]Keyword{ .none, .hidden, .dotted, .dashed, .solid, .double, .groove, .ridge, .inset, .outset };

const infos: [Longhand.count]Info = blk: {
    @setEvalBranchQuota(100_000);
    var out: [Longhand.count]Info = undefined;
    var set: [Longhand.count]bool = .{false} ** Longhand.count;
    const zero = Value.px(0);
    const medium_width = Value.kw(.medium);
    const defs = [_]Info{
        .{ .longhand = .appearance, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &.{ .none, .auto, .base, .base_select, .searchfield, .textarea, .checkbox, .radio, .menulist, .listbox, .meter, .progress_bar, .button, .textfield, .menulist_button } },
        .{ .longhand = .background_color, .inherited = false, .initial = .{ .color = Color.transparent }, .grammar = .color, .quirky_color = true },
        .{ .longhand = .background_image, .inherited = false, .initial = Value.kw(.none), .grammar = .image },
        .{ .longhand = .border_block_end_color, .inherited = false, .initial = .{ .color = .current }, .grammar = .color, .logical = .{ .group = .border_color, .side = .block_end } },
        .{ .longhand = .border_block_end_style, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &border_styles, .logical = .{ .group = .border_style, .side = .block_end } },
        .{ .longhand = .border_block_end_width, .inherited = false, .initial = medium_width, .grammar = .line_width, .logical = .{ .group = .border_width, .side = .block_end } },
        .{ .longhand = .border_block_start_color, .inherited = false, .initial = .{ .color = .current }, .grammar = .color, .logical = .{ .group = .border_color, .side = .block_start } },
        .{ .longhand = .border_block_start_style, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &border_styles, .logical = .{ .group = .border_style, .side = .block_start } },
        .{ .longhand = .border_block_start_width, .inherited = false, .initial = medium_width, .grammar = .line_width, .logical = .{ .group = .border_width, .side = .block_start } },
        .{ .longhand = .border_bottom_color, .inherited = false, .initial = .{ .color = .current }, .grammar = .color, .quirky_color = true },
        .{ .longhand = .border_bottom_style, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &border_styles },
        .{ .longhand = .border_bottom_width, .inherited = false, .initial = medium_width, .grammar = .line_width, .quirky_length = true },
        .{ .longhand = .border_inline_end_color, .inherited = false, .initial = .{ .color = .current }, .grammar = .color, .logical = .{ .group = .border_color, .side = .inline_end } },
        .{ .longhand = .border_inline_end_style, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &border_styles, .logical = .{ .group = .border_style, .side = .inline_end } },
        .{ .longhand = .border_inline_end_width, .inherited = false, .initial = medium_width, .grammar = .line_width, .logical = .{ .group = .border_width, .side = .inline_end } },
        .{ .longhand = .border_inline_start_color, .inherited = false, .initial = .{ .color = .current }, .grammar = .color, .logical = .{ .group = .border_color, .side = .inline_start } },
        .{ .longhand = .border_inline_start_style, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &border_styles, .logical = .{ .group = .border_style, .side = .inline_start } },
        .{ .longhand = .border_inline_start_width, .inherited = false, .initial = medium_width, .grammar = .line_width, .logical = .{ .group = .border_width, .side = .inline_start } },
        .{ .longhand = .border_left_color, .inherited = false, .initial = .{ .color = .current }, .grammar = .color, .quirky_color = true },
        .{ .longhand = .border_left_style, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &border_styles },
        .{ .longhand = .border_left_width, .inherited = false, .initial = medium_width, .grammar = .line_width, .quirky_length = true },
        .{ .longhand = .border_right_color, .inherited = false, .initial = .{ .color = .current }, .grammar = .color, .quirky_color = true },
        .{ .longhand = .border_right_style, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &border_styles },
        .{ .longhand = .border_right_width, .inherited = false, .initial = medium_width, .grammar = .line_width, .quirky_length = true },
        .{ .longhand = .border_top_color, .inherited = false, .initial = .{ .color = .current }, .grammar = .color, .quirky_color = true },
        .{ .longhand = .border_top_style, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &border_styles },
        .{ .longhand = .border_top_width, .inherited = false, .initial = medium_width, .grammar = .line_width, .quirky_length = true },
        .{ .longhand = .bottom, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .quirky_length = true },
        // CSS Color 4: "Initial: CanvasText".
        .{ .longhand = .color, .inherited = true, .initial = .{ .color = Color.black }, .grammar = .color, .quirky_color = true },
        .{ .longhand = .direction, .inherited = true, .initial = Value.kw(.ltr), .grammar = .keywords, .keywords = &.{ .ltr, .rtl } },
        .{ .longhand = .display, .inherited = false, .initial = .{ .display = Display.inline_flow }, .grammar = .display },
        .{ .longhand = .float, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &.{ .none, .left, .right, .inline_start, .inline_end } },
        // CSS Fonts 4: "Initial: depends on user agent" - serif (design Q11).
        .{ .longhand = .font_family, .inherited = true, .initial = Value.kw(.serif), .grammar = .font_family },
        .{ .longhand = .font_size, .inherited = true, .initial = Value.kw(.medium), .grammar = .font_size, .quirky_length = true },
        .{ .longhand = .font_style, .inherited = true, .initial = Value.kw(.normal), .grammar = .keywords, .keywords = &.{ .normal, .italic, .oblique } },
        .{ .longhand = .font_weight, .inherited = true, .initial = .{ .number = 400 }, .grammar = .font_weight },
        .{ .longhand = .height, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .quirky_length = true },
        .{ .longhand = .inset_block_end, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .logical = .{ .group = .inset, .side = .block_end } },
        .{ .longhand = .inset_block_start, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .logical = .{ .group = .inset, .side = .block_start } },
        .{ .longhand = .inset_inline_end, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .logical = .{ .group = .inset, .side = .inline_end } },
        .{ .longhand = .inset_inline_start, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .logical = .{ .group = .inset, .side = .inline_start } },
        .{ .longhand = .left, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .line_height, .inherited = true, .initial = Value.kw(.normal), .grammar = .line_height, .quirky_length = true },
        .{ .longhand = .margin_block_end, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .logical = .{ .group = .margin, .side = .block_end } },
        .{ .longhand = .margin_block_start, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .logical = .{ .group = .margin, .side = .block_start } },
        .{ .longhand = .margin_bottom, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .margin_inline_end, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .logical = .{ .group = .margin, .side = .inline_end } },
        .{ .longhand = .margin_inline_start, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .logical = .{ .group = .margin, .side = .inline_start } },
        .{ .longhand = .margin_left, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .margin_right, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .margin_top, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .opacity, .inherited = false, .initial = .{ .number = 1 }, .grammar = .opacity },
        .{ .longhand = .overflow_x, .inherited = false, .initial = Value.kw(.visible), .grammar = .keywords, .keywords = &.{ .visible, .hidden, .clip, .scroll, .auto } },
        .{ .longhand = .overflow_y, .inherited = false, .initial = Value.kw(.visible), .grammar = .keywords, .keywords = &.{ .visible, .hidden, .clip, .scroll, .auto } },
        .{ .longhand = .padding_block_end, .inherited = false, .initial = zero, .grammar = .length_percentage_nonneg, .logical = .{ .group = .padding, .side = .block_end } },
        .{ .longhand = .padding_block_start, .inherited = false, .initial = zero, .grammar = .length_percentage_nonneg, .logical = .{ .group = .padding, .side = .block_start } },
        .{ .longhand = .padding_bottom, .inherited = false, .initial = zero, .grammar = .length_percentage_nonneg, .quirky_length = true },
        .{ .longhand = .padding_inline_end, .inherited = false, .initial = zero, .grammar = .length_percentage_nonneg, .logical = .{ .group = .padding, .side = .inline_end } },
        .{ .longhand = .padding_inline_start, .inherited = false, .initial = zero, .grammar = .length_percentage_nonneg, .logical = .{ .group = .padding, .side = .inline_start } },
        .{ .longhand = .padding_left, .inherited = false, .initial = zero, .grammar = .length_percentage_nonneg, .quirky_length = true },
        .{ .longhand = .padding_right, .inherited = false, .initial = zero, .grammar = .length_percentage_nonneg, .quirky_length = true },
        .{ .longhand = .padding_top, .inherited = false, .initial = zero, .grammar = .length_percentage_nonneg, .quirky_length = true },
        .{ .longhand = .position, .inherited = false, .initial = Value.kw(.static), .grammar = .keywords, .keywords = &.{ .static, .relative, .absolute, .sticky, .fixed } },
        .{ .longhand = .right, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .text_transform, .inherited = true, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &.{ .none, .capitalize, .uppercase, .lowercase } },
        .{ .longhand = .text_wrap_mode, .inherited = true, .initial = Value.kw(.wrap), .grammar = .keywords, .keywords = &.{ .wrap, .nowrap } },
        .{ .longhand = .top, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .unicode_bidi, .inherited = false, .initial = Value.kw(.normal), .grammar = .keywords, .keywords = &.{ .normal, .embed, .isolate, .bidi_override, .isolate_override, .plaintext } },
        .{ .longhand = .visibility, .inherited = true, .initial = Value.kw(.visible), .grammar = .keywords, .keywords = &.{ .visible, .hidden, .collapse } },
        .{ .longhand = .white_space_collapse, .inherited = true, .initial = Value.kw(.collapse), .grammar = .keywords, .keywords = &.{ .collapse, .discard, .preserve, .preserve_breaks, .preserve_spaces, .break_spaces } },
        .{ .longhand = .width, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .quirky_length = true },
        .{ .longhand = .writing_mode, .inherited = true, .initial = Value.kw(.horizontal_tb), .grammar = .keywords, .keywords = &.{ .horizontal_tb, .vertical_rl, .vertical_lr, .sideways_rl, .sideways_lr } },
        .{ .longhand = .z_index, .inherited = false, .initial = Value.kw(.auto), .grammar = .z_index },
    };
    for (defs) |def| {
        const i = @intFromEnum(def.longhand);
        if (set[i]) @compileError("duplicate longhand " ++ def.longhand.name());
        set[i] = true;
        out[i] = def;
    }
    for (set, 0..) |done, i| if (!done) @compileError("no Info for " ++ @as(Longhand, @enumFromInt(i)).name());
    break :blk out;
};

// ============================================================================
// The shorthands
// ============================================================================

pub const Shorthand = enum(u8) {
    all,
    background,
    border,
    border_block,
    border_block_color,
    border_block_end,
    border_block_start,
    border_block_style,
    border_block_width,
    border_bottom,
    border_color,
    border_inline,
    border_inline_color,
    border_inline_end,
    border_inline_start,
    border_inline_style,
    border_inline_width,
    border_left,
    border_right,
    border_style,
    border_top,
    border_width,
    inset,
    inset_block,
    inset_inline,
    margin,
    margin_block,
    margin_inline,
    overflow,
    padding,
    padding_block,
    padding_inline,
    white_space,

    pub fn name(self: Shorthand) []const u8 {
        return switch (self) {
            inline else => |s| comptime dashedName(@tagName(s)),
        };
    }

    /// The longhands, in canonical order (CSSOM "shorthand ... maps to").
    pub fn longhands(self: Shorthand) []const Longhand {
        return switch (self) {
            .all => &all_longhands,
            .background => &.{ .background_image, .background_color },
            .border => &.{ .border_top_width, .border_right_width, .border_bottom_width, .border_left_width, .border_top_style, .border_right_style, .border_bottom_style, .border_left_style, .border_top_color, .border_right_color, .border_bottom_color, .border_left_color },
            .border_block => &.{ .border_block_start_width, .border_block_end_width, .border_block_start_style, .border_block_end_style, .border_block_start_color, .border_block_end_color },
            .border_inline => &.{ .border_inline_start_width, .border_inline_end_width, .border_inline_start_style, .border_inline_end_style, .border_inline_start_color, .border_inline_end_color },
            .border_block_color => &.{ .border_block_start_color, .border_block_end_color },
            .border_block_style => &.{ .border_block_start_style, .border_block_end_style },
            .border_block_width => &.{ .border_block_start_width, .border_block_end_width },
            .border_inline_color => &.{ .border_inline_start_color, .border_inline_end_color },
            .border_inline_style => &.{ .border_inline_start_style, .border_inline_end_style },
            .border_inline_width => &.{ .border_inline_start_width, .border_inline_end_width },
            .border_block_start => &.{ .border_block_start_width, .border_block_start_style, .border_block_start_color },
            .border_block_end => &.{ .border_block_end_width, .border_block_end_style, .border_block_end_color },
            .border_inline_start => &.{ .border_inline_start_width, .border_inline_start_style, .border_inline_start_color },
            .border_inline_end => &.{ .border_inline_end_width, .border_inline_end_style, .border_inline_end_color },
            .border_top => &.{ .border_top_width, .border_top_style, .border_top_color },
            .border_right => &.{ .border_right_width, .border_right_style, .border_right_color },
            .border_bottom => &.{ .border_bottom_width, .border_bottom_style, .border_bottom_color },
            .border_left => &.{ .border_left_width, .border_left_style, .border_left_color },
            .border_color => &.{ .border_top_color, .border_right_color, .border_bottom_color, .border_left_color },
            .border_style => &.{ .border_top_style, .border_right_style, .border_bottom_style, .border_left_style },
            .border_width => &.{ .border_top_width, .border_right_width, .border_bottom_width, .border_left_width },
            .inset => &.{ .top, .right, .bottom, .left },
            .inset_block => &.{ .inset_block_start, .inset_block_end },
            .inset_inline => &.{ .inset_inline_start, .inset_inline_end },
            .margin => &.{ .margin_top, .margin_right, .margin_bottom, .margin_left },
            .margin_block => &.{ .margin_block_start, .margin_block_end },
            .margin_inline => &.{ .margin_inline_start, .margin_inline_end },
            .overflow => &.{ .overflow_x, .overflow_y },
            .padding => &.{ .padding_top, .padding_right, .padding_bottom, .padding_left },
            .padding_block => &.{ .padding_block_start, .padding_block_end },
            .padding_inline => &.{ .padding_inline_start, .padding_inline_end },
            .white_space => &.{ .white_space_collapse, .text_wrap_mode },
        };
    }
};

/// `all`: every longhand but direction and unicode-bidi (Cascade 5 3.2).
const all_longhands = blk: {
    @setEvalBranchQuota(100_000);
    var out: [Longhand.count - 2]Longhand = undefined;
    var n: usize = 0;
    for (0..Longhand.count) |i| {
        const l: Longhand = @enumFromInt(i);
        if (l == .direction or l == .unicode_bidi) continue;
        out[n] = l;
        n += 1;
    }
    break :blk out;
};

/// A property name, resolved.
pub const Property = union(enum) {
    longhand: Longhand,
    shorthand: Shorthand,
};

const by_name = blk: {
    @setEvalBranchQuota(100_000);
    const l_fields = @typeInfo(Longhand).@"enum".fields;
    const s_fields = @typeInfo(Shorthand).@"enum".fields;
    var entries: [l_fields.len + s_fields.len]struct { []const u8, Property } = undefined;
    for (l_fields, 0..) |f, i| entries[i] = .{ dashedName(f.name), .{ .longhand = @enumFromInt(f.value) } };
    for (s_fields, 0..) |f, i| entries[l_fields.len + i] = .{ dashedName(f.name), .{ .shorthand = @enumFromInt(f.value) } };
    break :blk std.StaticStringMap(Property).initComptime(entries);
};

/// The supported property named `property_name`, ASCII case-insensitively;
/// null for an unsupported one (and for a custom property).
pub fn lookup(property_name: []const u8) ?Property {
    var buffer: [40]u8 = undefined;
    if (property_name.len > buffer.len) return null;
    return by_name.get(std.ascii.lowerString(&buffer, property_name));
}

// ============================================================================
// Parsing
// ============================================================================

/// What parsing a value may need from its sheet or element.
pub const ParseOptions = struct {
    allocator: Allocator,
    quirks: bool = false,
    /// Resolve a url() against the sheet's base URL (CSS Values 4 4.5.1);
    /// null leaves it as written.
    url_resolver: ?UrlResolver = null,
};

pub const UrlResolver = struct {
    context: *const anyopaque,
    resolve: *const fn (context: *const anyopaque, allocator: Allocator, url: []const u8) ?[]u8,
};

/// A longhand set by a parsed declaration.
pub const Assignment = struct {
    longhand: Longhand,
    value: Assigned,
};

pub const Assigned = union(enum) {
    value: Value,
    css_wide: values.CssWide,

    pub fn release(self: Assigned) void {
        if (self == .value) self.value.release();
    }

    pub fn retain(self: Assigned) void {
        if (self == .value) self.value.retain();
    }
};

/// The most longhands one declaration sets (`all`).
pub const max_assignments = all_longhands.len;

/// Parse `text` - a declaration's value, `!important` already taken off -
/// for `property`, appending the longhands it sets to `out`. False, and
/// nothing appended, when the value is invalid for the property. The values
/// appended hold references the caller releases.
pub fn parseDeclaration(options: ParseOptions, property: Property, text: []const u8, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    const start = out.items.len;
    errdefer {
        for (out.items[start..]) |a| a.value.release();
        out.shrinkRetainingCapacity(start);
    }
    // A CSS-wide keyword alone (CSS Values 4 6.1) sets every longhand.
    if (cssWideKeyword(text)) |keyword| {
        switch (property) {
            .longhand => |l| try out.append(options.allocator, .{ .longhand = l, .value = .{ .css_wide = keyword } }),
            .shorthand => |s| for (s.longhands()) |l| try out.append(options.allocator, .{ .longhand = l, .value = .{ .css_wide = keyword } }),
        }
        return true;
    }
    if (containsUnsupportedFunction(text)) return false;
    var stream = Stream.init(text);
    const ok = switch (property) {
        .longhand => |l| blk: {
            const value = (try parseLonghand(options, l, &stream)) orelse break :blk false;
            if (!stream.atEnd()) {
                value.release();
                break :blk false;
            }
            try out.append(options.allocator, .{ .longhand = l, .value = .{ .value = value } });
            break :blk true;
        },
        .shorthand => |s| try parseShorthand(options, s, &stream, out),
    };
    if (!ok) {
        for (out.items[start..]) |a| a.value.release();
        out.shrinkRetainingCapacity(start);
    }
    return ok;
}

fn cssWideKeyword(text: []const u8) ?values.CssWide {
    var stream = Stream.init(text);
    const token = stream.next();
    if (token.token_type != .ident) return null;
    if (!stream.atEnd()) return null;
    return values.CssWide.parse(token.value);
}

/// Math functions and var() are not supported yet: a value naming one is
/// invalid (stated; design section 6.1).
fn containsUnsupportedFunction(text: []const u8) bool {
    var tok = Tokenizer.init(text);
    while (true) {
        const token = tok.next();
        if (token.token_type == .eof) return false;
        if (token.token_type != .function) continue;
        for ([_][]const u8{ "calc", "min", "max", "clamp", "var", "env", "attr", "round", "mod", "rem", "abs", "sign", "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "pow", "sqrt", "hypot", "log", "exp", "progress", "calc-size", "if" }) |f| {
            if (tokenizer_mod.nameEql(token.value, f)) return true;
        }
    }
}

/// A value's tokens, whitespace skipped.
pub const Stream = struct {
    tok: Tokenizer,
    peeked: ?Token = null,
    text: []const u8,

    pub fn init(text: []const u8) Stream {
        return .{ .tok = Tokenizer.init(text), .text = text };
    }

    pub fn peek(self: *Stream) Token {
        if (self.peeked) |t| return t;
        while (true) {
            const t = self.tok.next();
            if (t.token_type == .whitespace) continue;
            self.peeked = t;
            return t;
        }
    }

    pub fn next(self: *Stream) Token {
        const t = self.peek();
        self.peeked = null;
        return t;
    }

    pub fn atEnd(self: *Stream) bool {
        return self.peek().token_type == .eof;
    }

    const Mark = struct { tok: Tokenizer, peeked: ?Token };

    fn mark(self: *const Stream) Mark {
        return .{ .tok = self.tok, .peeked = self.peeked };
    }

    fn restore(self: *Stream, m: Mark) void {
        self.tok = m.tok;
        self.peeked = m.peeked;
    }

    /// The position of the next token in the text.
    fn offset(self: *Stream) usize {
        const t = self.peek();
        if (t.token_type == .eof) return self.text.len;
        return @intFromPtr(t.value.ptr) - @intFromPtr(self.text.ptr);
    }

    /// Skip a function's arguments: the `(` after its name through the
    /// matching `)`.
    fn skipArguments(self: *Stream) void {
        var depth: usize = 0;
        while (true) {
            const t = self.tok.next();
            switch (t.token_type) {
                .eof => return,
                .left_paren, .function => depth += if (t.token_type == .left_paren) 1 else 0,
                .right_paren => {
                    if (depth <= 1) return;
                    depth -= 1;
                },
                else => {},
            }
        }
    }
};

/// One longhand's value, from the stream; null when its grammar does not
/// match (the stream is then wherever it stopped).
pub fn parseLonghand(options: ParseOptions, l: Longhand, stream: *Stream) Allocator.Error!?Value {
    const def = l.info();
    switch (def.grammar) {
        .keywords => {
            const k = identKeyword(stream.peek()) orelse return null;
            for (def.keywords) |allowed| if (allowed == k) {
                _ = stream.next();
                return Value.kw(k);
            };
            return null;
        },
        .length_percentage_auto => {
            if (takeKeyword(stream, &.{.auto})) |k| return Value.kw(k);
            return lengthPercentage(options, stream, .{ .negative = true, .quirky = def.quirky_length });
        },
        .length_percentage_nonneg => return lengthPercentage(options, stream, .{ .negative = false, .quirky = def.quirky_length }),
        .size => {
            if (takeKeyword(stream, &.{ .auto, .min_content, .max_content, .fit_content })) |k| return Value.kw(k);
            return lengthPercentage(options, stream, .{ .negative = false, .quirky = def.quirky_length });
        },
        .line_width => {
            if (takeKeyword(stream, &.{ .thin, .medium, .thick })) |k| return Value.kw(k);
            return lengthPercentage(options, stream, .{ .negative = false, .percent = false, .quirky = def.quirky_length });
        },
        .color => return colorValue(options, stream, def),
        .image => return imageValue(options, stream),
        .display => return displayValue(stream),
        .font_family => return fontFamilyValue(options, stream),
        .font_size => {
            if (takeKeyword(stream, &.{ .xx_small, .x_small, .small, .medium, .large, .x_large, .xx_large, .xxx_large, .larger, .smaller })) |k| return Value.kw(k);
            return lengthPercentage(options, stream, .{ .negative = false, .quirky = def.quirky_length });
        },
        .font_weight => {
            if (takeKeyword(stream, &.{ .normal, .bold, .bolder, .lighter })) |k| return Value.kw(k);
            const t = stream.peek();
            if (t.token_type != .number) return null;
            const n = t.numeric_value orelse return null;
            if (n < 1 or n > 1000) return null;
            _ = stream.next();
            return .{ .number = n };
        },
        .line_height => {
            if (takeKeyword(stream, &.{.normal})) |k| return Value.kw(k);
            const t = stream.peek();
            if (t.token_type == .number) {
                const n = t.numeric_value orelse return null;
                if (n < 0) return null;
                _ = stream.next();
                return .{ .number = n };
            }
            return lengthPercentage(options, stream, .{ .negative = false, .quirky = false });
        },
        .opacity => {
            const t = stream.peek();
            const n: f64 = switch (t.token_type) {
                .number => t.numeric_value orelse return null,
                .percentage => (t.numeric_value orelse return null) / 100,
                else => return null,
            };
            _ = stream.next();
            return .{ .number = n };
        },
        .z_index => {
            if (takeKeyword(stream, &.{.auto})) |k| return Value.kw(k);
            const t = stream.peek();
            if (t.token_type != .number or !t.is_integer) return null;
            const n = t.numeric_value orelse return null;
            _ = stream.next();
            const clamped = std.math.clamp(n, @as(f64, std.math.minInt(i32)), @as(f64, std.math.maxInt(i32)));
            return .{ .integer = @intFromFloat(clamped) };
        },
    }
}

fn identKeyword(t: Token) ?Keyword {
    if (t.token_type != .ident) return null;
    if (std.mem.indexOfScalar(u8, t.value, '\\') != null) {
        var buffer: [96]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const decoded = tokenizer_mod.decode(fba.allocator(), t.value) catch return null;
        return Keyword.parse(decoded);
    }
    return Keyword.parse(t.value);
}

fn takeKeyword(stream: *Stream, allowed: []const Keyword) ?Keyword {
    const k = identKeyword(stream.peek()) orelse return null;
    for (allowed) |a| if (a == k) {
        _ = stream.next();
        return k;
    };
    return null;
}

const LengthFlags = struct {
    negative: bool,
    percent: bool = true,
    quirky: bool,
};

fn lengthPercentage(options: ParseOptions, stream: *Stream, flags: LengthFlags) ?Value {
    const t = stream.peek();
    const value: Length = switch (t.token_type) {
        .dimension => blk: {
            const n = t.numeric_value orelse return null;
            const unit = LengthUnit.fromString(t.unit orelse return null) orelse return null;
            break :blk Length.init(n, unit);
        },
        .percentage => blk: {
            if (!flags.percent) return null;
            break :blk Length.percent(t.numeric_value orelse return null);
        },
        .number => blk: {
            const n = t.numeric_value orelse return null;
            if (n == 0) break :blk Length.px(0);
            // Quirks 3.2 "the unitless length quirk".
            if (options.quirks and flags.quirky) break :blk Length.px(n);
            return null;
        },
        else => return null,
    };
    if (!flags.negative and value.value < 0) return null;
    _ = stream.next();
    return .{ .length = value };
}

fn colorValue(options: ParseOptions, stream: *Stream, def: *const Info) ?Value {
    const t = stream.peek();
    if (t.token_type == .ident) {
        if (tokenizer_mod.nameEql(t.value, "currentcolor")) {
            _ = stream.next();
            return .{ .color = .current };
        }
    }
    // The color parser reads its own tokens: hand it the rest of the text.
    const rest = stream.text[stream.offset()..];
    var tok = Tokenizer.init(rest);
    var ctx = ParserContext.init(options.allocator, if (options.quirks and def.quirky_color) .quirks else .no_quirks);
    defer ctx.deinit();
    const property_name = def.longhand.name();
    if (color_mod.ColorParser.parse(&tok, property_name, &ctx)) |c| {
        advanceTo(stream, rest, &tok);
        // A <named-color> keeps its keyword; a hashless hex color (the
        // quirk) does not.
        if (t.token_type == .ident and !(options.quirks and def.quirky_color and tokenizer_mod.isHexColor(t.value))) {
            return namedColor(options, t.value, c) catch null;
        }
        return .{ .color = .{ .rgba = c } };
    } else |_| {}
    // A <system-color> (CSS Color 4 6.2), its color the light palette's
    // (stated: color-scheme is a later batch).
    if (t.token_type == .ident) {
        if (color_mod.ColorParser.parseWithoutContext(t.value, options.allocator)) |fc| {
            _ = stream.next();
            return namedColor(options, t.value, fc.quantize()) catch null;
        } else |_| {}
    }
    return null;
}

fn namedColor(options: ParseOptions, raw: []const u8, rgba: values.RgbaColor) Allocator.Error!Value {
    const decoded = try tokenizer_mod.decode(options.allocator, raw);
    defer options.allocator.free(decoded);
    _ = std.ascii.lowerString(decoded, decoded);
    return .{ .color = .{ .named = .{ .rgba = rgba, .name = try SharedText.create(options.allocator, decoded) } } };
}

/// Move `stream` to where `tok`, which read `rest` (a suffix of the
/// stream's text), stopped.
fn advanceTo(stream: *Stream, rest: []const u8, tok: *const Tokenizer) void {
    const consumed = tok.pos;
    const base = @intFromPtr(rest.ptr) - @intFromPtr(stream.text.ptr);
    stream.tok = Tokenizer.init(stream.text);
    stream.tok.pos = base + consumed;
    stream.peeked = null;
}

const image_functions = [_][]const u8{ "linear-gradient", "radial-gradient", "conic-gradient", "repeating-linear-gradient", "repeating-radial-gradient", "repeating-conic-gradient", "image-set", "-webkit-image-set", "cross-fade", "image", "element", "paint", "-webkit-gradient", "-webkit-linear-gradient", "-webkit-radial-gradient", "-webkit-repeating-linear-gradient", "-webkit-repeating-radial-gradient" };

/// <image> | none. A url() is resolved and kept as `url("...")`; any
/// other image function is kept as written (stated).
fn imageValue(options: ParseOptions, stream: *Stream) Allocator.Error!?Value {
    if (takeKeyword(stream, &.{.none})) |k| return Value.kw(k);
    return imageOnly(options, stream);
}

fn imageOnly(options: ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const t = stream.peek();
    switch (t.token_type) {
        .url => {
            _ = stream.next();
            const raw = try tokenizer_mod.decode(options.allocator, t.value);
            defer options.allocator.free(raw);
            return try urlValue(options, raw);
        },
        .function => {
            if (tokenizer_mod.nameEql(t.value, "url") or tokenizer_mod.nameEql(t.value, "src")) {
                const m = stream.mark();
                _ = stream.next();
                if (stream.next().token_type != .left_paren) {
                    stream.restore(m);
                    return null;
                }
                const s = stream.next();
                if (s.token_type != .string or stream.next().token_type != .right_paren) {
                    stream.restore(m);
                    return null;
                }
                const raw = try tokenizer_mod.decode(options.allocator, s.stringContents());
                defer options.allocator.free(raw);
                return try urlValue(options, raw);
            }
            for (image_functions) |f| {
                if (!tokenizer_mod.nameEql(t.value, f)) continue;
                const begin = stream.offset();
                _ = stream.next();
                stream.skipArguments();
                const end = stream.tok.pos;
                stream.peeked = null;
                const text = std.mem.trim(u8, stream.text[begin..end], " \t\n");
                return .{ .text = try SharedText.create(options.allocator, text) };
            }
            return null;
        },
        else => return null,
    }
}

fn urlValue(options: ParseOptions, raw: []const u8) Allocator.Error!Value {
    const resolved: ?[]u8 = if (options.url_resolver) |r| r.resolve(r.context, options.allocator, raw) else null;
    defer if (resolved) |r| options.allocator.free(r);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(options.allocator);
    try out.appendSlice(options.allocator, "url(");
    try values.appendString(resolved orelse raw, &out, options.allocator);
    try out.append(options.allocator, ')');
    return .{ .text = try SharedText.create(options.allocator, out.items) };
}

/// CSS Display 4 section 2: the display grammar.
fn displayValue(stream: *Stream) ?Value {
    const first = identKeywordText(stream.peek()) orelse return null;
    // Single-keyword forms.
    const single = std.StaticStringMap(Display).initComptime(.{
        .{ "none", Display.none },
        .{ "contents", Display.contents },
        .{ "inline-block", Display{ .inner = .flow_root } },
        .{ "inline-table", Display{ .inner = .table } },
        .{ "inline-flex", Display{ .inner = .flex } },
        .{ "inline-grid", Display{ .inner = .grid } },
        .{ "table-row-group", Display{ .box = .internal, .internal = .table_row_group } },
        .{ "table-header-group", Display{ .box = .internal, .internal = .table_header_group } },
        .{ "table-footer-group", Display{ .box = .internal, .internal = .table_footer_group } },
        .{ "table-row", Display{ .box = .internal, .internal = .table_row } },
        .{ "table-cell", Display{ .box = .internal, .internal = .table_cell } },
        .{ "table-column-group", Display{ .box = .internal, .internal = .table_column_group } },
        .{ "table-column", Display{ .box = .internal, .internal = .table_column } },
        .{ "table-caption", Display{ .box = .internal, .internal = .table_caption } },
        .{ "ruby-base", Display{ .box = .internal, .internal = .ruby_base } },
        .{ "ruby-text", Display{ .box = .internal, .internal = .ruby_text } },
        .{ "ruby-base-container", Display{ .box = .internal, .internal = .ruby_base_container } },
        .{ "ruby-text-container", Display{ .box = .internal, .internal = .ruby_text_container } },
    });
    if (single.get(first.slice())) |d| {
        _ = stream.next();
        return .{ .display = d };
    }
    // [<display-outside> || <display-inside>] | <display-listitem>
    var outer: ?Display.Outer = null;
    var inner: ?Display.Inner = null;
    var list_item = false;
    var count: usize = 0;
    while (count < 3) : (count += 1) {
        const word = identKeywordText(stream.peek()) orelse break;
        const s = word.slice();
        if (outer == null and (std.mem.eql(u8, s, "block") or std.mem.eql(u8, s, "inline") or std.mem.eql(u8, s, "run-in"))) {
            outer = if (std.mem.eql(u8, s, "block")) .block else if (std.mem.eql(u8, s, "inline")) .inline_ else .run_in;
        } else if (inner == null and innerKeyword(s) != null) {
            inner = innerKeyword(s);
        } else if (!list_item and std.mem.eql(u8, s, "list-item")) {
            list_item = true;
        } else break;
        _ = stream.next();
    }
    if (outer == null and inner == null and !list_item) return null;
    if (list_item) {
        // "list-item ... with flow or flow-root inner"
        if (inner) |i| if (i != .flow and i != .flow_root) return null;
        return .{ .display = .{ .outer = outer orelse .block, .inner = inner orelse .flow, .list_item = true } };
    }
    // "If a <display-outside> value is specified but <display-inside> is
    // omitted, the element's inner display type defaults to flow. If a
    // <display-inside> value is specified but <display-outside> is omitted,
    // the element's outer display type defaults to block - except for
    // ruby, which defaults to inline."
    const i = inner orelse .flow;
    const o = outer orelse (if (i == .ruby or i == .math) Display.Outer.inline_ else .block);
    return .{ .display = .{ .outer = o, .inner = i } };
}

fn innerKeyword(s: []const u8) ?Display.Inner {
    const map = std.StaticStringMap(Display.Inner).initComptime(.{
        .{ "flow", .flow }, .{ "flow-root", .flow_root }, .{ "table", .table },
        .{ "flex", .flex }, .{ "grid", .grid },           .{ "ruby", .ruby },
        .{ "math", .math },
    });
    return map.get(s);
}

/// An ident token's name, decoded and ASCII-lowercased, in a small buffer.
const IdentText = struct {
    buffer: [48]u8 = undefined,
    len: usize = 0,

    fn slice(self: *const IdentText) []const u8 {
        return self.buffer[0..self.len];
    }
};

fn identKeywordText(t: Token) ?IdentText {
    if (t.token_type != .ident) return null;
    var out: IdentText = .{};
    var scratch: [48 * 3 + 3]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&scratch);
    const decoded = tokenizer_mod.decode(fba.allocator(), t.value) catch return null;
    if (decoded.len > out.buffer.len) return null;
    out.len = decoded.len;
    _ = std.ascii.lowerString(out.buffer[0..decoded.len], decoded);
    return out;
}

const generic_families = [_][]const u8{ "serif", "sans-serif", "cursive", "fantasy", "monospace", "system-ui", "math", "emoji", "fangsong", "ui-serif", "ui-sans-serif", "ui-monospace", "ui-rounded" };

/// CSS Fonts 4 3.1: `[ <family-name> | <generic-family> ]#`, kept as its
/// serialization - strings as CSSOM serializes a string, identifier
/// sequences joined by one space.
fn fontFamilyValue(options: ParseOptions, stream: *Stream) Allocator.Error!?Value {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(options.allocator);
    var families: usize = 0;
    while (true) {
        const t = stream.peek();
        if (families > 0) try out.appendSlice(options.allocator, ", ");
        switch (t.token_type) {
            .string => {
                _ = stream.next();
                const contents = try tokenizer_mod.decode(options.allocator, t.stringContents());
                defer options.allocator.free(contents);
                try values.appendString(contents, &out, options.allocator);
            },
            .ident => {
                var words: usize = 0;
                while (stream.peek().token_type == .ident) : (words += 1) {
                    const w = stream.next();
                    const decoded = try tokenizer_mod.decode(options.allocator, w.value);
                    defer options.allocator.free(decoded);
                    // A generic family or a CSS-wide keyword cannot be one
                    // word of several; "default" is reserved.
                    if (words > 0) try out.append(options.allocator, ' ');
                    try out.appendSlice(options.allocator, decoded);
                }
            },
            else => return null,
        }
        families += 1;
        const after = stream.peek();
        if (after.token_type == .comma) {
            _ = stream.next();
            continue;
        }
        break;
    }
    if (families == 0) return null;
    return .{ .text = try SharedText.create(options.allocator, out.items) };
}

/// Whether `family` is a <generic-family> keyword.
pub fn isGenericFamily(family: []const u8) bool {
    for (generic_families) |g| if (std.ascii.eqlIgnoreCase(g, family)) return true;
    return false;
}

// ============================================================================
// Shorthand parsing
// ============================================================================

fn append(options: ParseOptions, out: *std.ArrayList(Assignment), l: Longhand, v: Value) Allocator.Error!void {
    try out.append(options.allocator, .{ .longhand = l, .value = .{ .value = v } });
}

fn parseShorthand(options: ParseOptions, s: Shorthand, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    switch (s) {
        // `all` takes only the CSS-wide keywords, handled by the caller.
        .all => return false,
        .margin, .padding, .inset, .border_width, .border_style, .border_color => return fourSides(options, s.longhands(), stream, out),
        .margin_block, .margin_inline, .padding_block, .padding_inline, .inset_block, .inset_inline, .border_block_width, .border_block_style, .border_block_color, .border_inline_width, .border_inline_style, .border_inline_color => return twoSides(options, s.longhands(), stream, out),
        .border_top, .border_right, .border_bottom, .border_left, .border_block_start, .border_block_end, .border_inline_start, .border_inline_end => {
            const ls = s.longhands();
            return borderSide(options, ls[0], ls[1], ls[2], &.{ls[0]}, &.{ls[1]}, &.{ls[2]}, stream, out);
        },
        .border => return borderSide(options, .border_top_width, .border_top_style, .border_top_color, Shorthand.border_width.longhands(), Shorthand.border_style.longhands(), Shorthand.border_color.longhands(), stream, out),
        .border_block => return borderSide(options, .border_block_start_width, .border_block_start_style, .border_block_start_color, Shorthand.border_block_width.longhands(), Shorthand.border_block_style.longhands(), Shorthand.border_block_color.longhands(), stream, out),
        .border_inline => return borderSide(options, .border_inline_start_width, .border_inline_start_style, .border_inline_start_color, Shorthand.border_inline_width.longhands(), Shorthand.border_inline_style.longhands(), Shorthand.border_inline_color.longhands(), stream, out),
        .overflow => {
            const x = (try parseLonghand(options, .overflow_x, stream)) orelse return false;
            const y = if (stream.atEnd()) x else (try parseLonghand(options, .overflow_y, stream)) orelse return false;
            if (!stream.atEnd()) return false;
            try append(options, out, .overflow_x, x);
            try append(options, out, .overflow_y, y);
            return true;
        },
        .white_space => return whiteSpace(options, stream, out),
        .background => return background(options, stream, out),
    }
}

/// `<value>{1,4}`: top, right, bottom, left (CSS Box 4 "margin").
fn fourSides(options: ParseOptions, ls: []const Longhand, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    var vs: [4]Value = undefined;
    var n: usize = 0;
    while (n < 4 and !stream.atEnd()) : (n += 1) {
        vs[n] = (try parseLonghand(options, ls[n], stream)) orelse {
            for (vs[0..n]) |v| v.release();
            return false;
        };
    }
    if (n == 0 or !stream.atEnd()) {
        for (vs[0..n]) |v| v.release();
        return false;
    }
    // "If there is only one component value, it applies to all sides. If
    // there are two values, the top and bottom are set to the first value
    // and the right and left are set to the second. If there are three
    // values, the top is set to the first value, the left and right are set
    // to the second, and the bottom is set to the third."
    const order: [4]usize = switch (n) {
        1 => .{ 0, 0, 0, 0 },
        2 => .{ 0, 1, 0, 1 },
        3 => .{ 0, 1, 2, 1 },
        else => .{ 0, 1, 2, 3 },
    };
    var used: [4]bool = .{false} ** 4;
    for (ls, 0..) |l, i| {
        const v = vs[order[i]];
        if (used[order[i]]) v.retain();
        used[order[i]] = true;
        try append(options, out, l, v);
    }
    return true;
}

/// `<value>{1,2}`: start, end (CSS Logical 1).
fn twoSides(options: ParseOptions, ls: []const Longhand, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    const a = (try parseLonghand(options, ls[0], stream)) orelse return false;
    if (stream.atEnd()) {
        try append(options, out, ls[0], a);
        a.retain();
        try append(options, out, ls[1], a);
        return true;
    }
    const b = (try parseLonghand(options, ls[1], stream)) orelse {
        a.release();
        return false;
    };
    if (!stream.atEnd()) {
        a.release();
        b.release();
        return false;
    }
    try append(options, out, ls[0], a);
    try append(options, out, ls[1], b);
    return true;
}

/// `<line-width> || <line-style> || <color>` (CSS Backgrounds 3 "border-top"),
/// each omitted one its initial value, set on each of the target longhands.
fn borderSide(options: ParseOptions, width_l: Longhand, style_l: Longhand, color_l: Longhand, widths: []const Longhand, styles: []const Longhand, colors: []const Longhand, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    var width: ?Value = null;
    var style: ?Value = null;
    var color: ?Value = null;
    var i: usize = 0;
    while (i < 3 and !stream.atEnd()) : (i += 1) {
        if (width == null) {
            if (try parseLonghand(options, width_l, stream)) |v| {
                width = v;
                continue;
            }
        }
        if (style == null) {
            if (try parseLonghand(options, style_l, stream)) |v| {
                style = v;
                continue;
            }
        }
        if (color == null) {
            if (try parseLonghand(options, color_l, stream)) |v| {
                color = v;
                continue;
            }
        }
        break;
    }
    if (!stream.atEnd() or (width == null and style == null and color == null)) {
        if (width) |v| v.release();
        if (style) |v| v.release();
        if (color) |v| v.release();
        return false;
    }
    const w = width orelse width_l.info().initial;
    const st = style orelse style_l.info().initial;
    const c = color orelse color_l.info().initial;
    for (widths, 0..) |l, k| {
        if (k > 0) w.retain();
        try append(options, out, l, w);
    }
    for (styles, 0..) |l, k| {
        if (k > 0) st.retain();
        try append(options, out, l, st);
    }
    for (colors, 0..) |l, k| {
        if (k > 0) c.retain();
        try append(options, out, l, c);
    }
    return true;
}

/// CSS Text 4 3.1: `normal | pre | pre-wrap | pre-line | <'white-space-collapse'> || <'text-wrap-mode'>`.
fn whiteSpace(options: ParseOptions, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    const first = identKeywordText(stream.peek());
    if (first) |word| {
        const legacy = std.StaticStringMap([2]Keyword).initComptime(.{
            .{ "normal", .{ .collapse, .wrap } },
            .{ "pre", .{ .preserve, .nowrap } },
            .{ "pre-wrap", .{ .preserve, .wrap } },
            .{ "pre-line", .{ .preserve_breaks, .wrap } },
        });
        if (legacy.get(word.slice())) |pair| {
            _ = stream.next();
            if (!stream.atEnd()) return false;
            try append(options, out, .white_space_collapse, Value.kw(pair[0]));
            try append(options, out, .text_wrap_mode, Value.kw(pair[1]));
            return true;
        }
    }
    var collapse: ?Value = null;
    var wrap: ?Value = null;
    var i: usize = 0;
    while (i < 2 and !stream.atEnd()) : (i += 1) {
        if (collapse == null) if (try parseLonghand(options, .white_space_collapse, stream)) |v| {
            collapse = v;
            continue;
        };
        if (wrap == null) if (try parseLonghand(options, .text_wrap_mode, stream)) |v| {
            wrap = v;
            continue;
        };
        break;
    }
    if (!stream.atEnd() or (collapse == null and wrap == null)) return false;
    try append(options, out, .white_space_collapse, collapse orelse Value.kw(.collapse));
    try append(options, out, .text_wrap_mode, wrap orelse Value.kw(.wrap));
    return true;
}

/// CSS Backgrounds 3 3.10 `background`: `<bg-layer>#, <final-bg-layer>`.
/// Every component is parsed; only the images and the final layer's color
/// are kept, the longhands Crane supports (stated).
fn background(options: ParseOptions, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    var images: std.ArrayList(u8) = .empty;
    defer images.deinit(options.allocator);
    var any_image = false;
    var color: ?Value = null;
    var layers: usize = 0;
    while (true) {
        var image: ?Value = null;
        defer if (image) |v| v.release();
        var seen = struct { position: bool = false, repeat: bool = false, attachment: bool = false, boxes: u8 = 0 }{};
        var components: usize = 0;
        while (!stream.atEnd() and stream.peek().token_type != .comma) {
            components += 1;
            if (image == null) if (try imageValue(options, stream)) |v| {
                image = v;
                continue;
            };
            if (color == null) {
                const c = colorValue(options, stream, Longhand.background_color.info());
                if (c) |v| {
                    color = v;
                    continue;
                }
            }
            if (!seen.position and backgroundPosition(stream)) {
                seen.position = true;
                // An optional `/ <bg-size>`.
                const t = stream.peek();
                if (t.token_type == .delim and std.mem.eql(u8, t.value, "/")) {
                    _ = stream.next();
                    if (!backgroundSize(stream)) return false;
                }
                continue;
            }
            if (!seen.repeat and backgroundRepeat(stream)) {
                seen.repeat = true;
                continue;
            }
            if (!seen.attachment and takeIdent(stream, &.{ "scroll", "fixed", "local" })) {
                seen.attachment = true;
                continue;
            }
            if (seen.boxes < 2 and takeIdent(stream, &.{ "border-box", "padding-box", "content-box", "text" })) {
                seen.boxes += 1;
                continue;
            }
            if (color) |v| v.release();
            return false;
        }
        if (components == 0) {
            if (color) |v| v.release();
            return false;
        }
        if (layers > 0) try images.appendSlice(options.allocator, ", ");
        if (image) |v| {
            switch (v) {
                .text => |t| try images.appendSlice(options.allocator, t.bytes),
                else => try images.appendSlice(options.allocator, "none"),
            }
            if (v == .text) any_image = true;
        } else try images.appendSlice(options.allocator, "none");
        layers += 1;
        if (stream.peek().token_type == .comma) {
            // Only the final layer may hold a color.
            if (color != null) {
                color.?.release();
                return false;
            }
            _ = stream.next();
            continue;
        }
        break;
    }
    const image_value: Value = if (!any_image and layers == 1) Value.kw(.none) else .{ .text = try SharedText.create(options.allocator, images.items) };
    try append(options, out, .background_image, image_value);
    try append(options, out, .background_color, color orelse .{ .color = Color.transparent });
    return true;
}

fn takeIdent(stream: *Stream, names: []const []const u8) bool {
    const word = identKeywordText(stream.peek()) orelse return false;
    for (names) |n| if (std.mem.eql(u8, word.slice(), n)) {
        _ = stream.next();
        return true;
    };
    return false;
}

fn isLengthPercentageToken(t: Token) bool {
    return switch (t.token_type) {
        .percentage => true,
        .dimension => t.unit != null and LengthUnit.fromString(t.unit.?) != null,
        .number => (t.numeric_value orelse 1) == 0,
        else => false,
    };
}

/// <bg-position>: up to four keywords / lengths, consumed loosely.
fn backgroundPosition(stream: *Stream) bool {
    var n: usize = 0;
    while (n < 4) : (n += 1) {
        const t = stream.peek();
        if (isLengthPercentageToken(t)) {
            _ = stream.next();
            continue;
        }
        if (takeIdent(stream, &.{ "left", "right", "top", "bottom", "center" })) continue;
        break;
    }
    return n > 0;
}

/// <bg-size> = [ <length-percentage [0,inf]> | auto ]{1,2} | cover | contain
fn backgroundSize(stream: *Stream) bool {
    if (takeIdent(stream, &.{ "cover", "contain" })) return true;
    var n: usize = 0;
    while (n < 2) : (n += 1) {
        const t = stream.peek();
        if (isLengthPercentageToken(t)) {
            _ = stream.next();
            continue;
        }
        if (takeIdent(stream, &.{"auto"})) continue;
        break;
    }
    return n > 0;
}

/// <repeat-style> = repeat-x | repeat-y | <repetition>{1,2}
fn backgroundRepeat(stream: *Stream) bool {
    if (takeIdent(stream, &.{ "repeat-x", "repeat-y" })) return true;
    var n: usize = 0;
    while (n < 2) : (n += 1) {
        if (!takeIdent(stream, &.{ "repeat", "space", "round", "no-repeat" })) break;
    }
    return n > 0;
}

// ============================================================================
// Serialization
// ============================================================================

/// CSSOM "serialize a CSS value" for one longhand's value.
pub fn serializeValue(l: Longhand, value: Value, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    _ = l;
    switch (value) {
        .keyword => |k| try out.appendSlice(allocator, k.name()),
        .length => |len| try values.appendLength(len, out, allocator),
        .number => |n| try values.appendNumber(n, out, allocator),
        .integer => |n| try out.print(allocator, "{d}", .{n}),
        .color => |c| switch (c) {
            .current => try out.appendSlice(allocator, "currentcolor"),
            .rgba => |rgba| try values.serializeRgba(rgba, out, allocator),
            .named => |n| try out.appendSlice(allocator, n.name.bytes),
        },
        .display => |d| try d.serialize(out, allocator),
        .text => |t| try out.appendSlice(allocator, t.bytes),
    }
}

/// An assigned value (a CSS-wide keyword, or a value) serialized.
pub fn serializeAssigned(l: Longhand, assigned: Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    switch (assigned) {
        .css_wide => |k| try out.appendSlice(allocator, k.name()),
        .value => |v| try serializeValue(l, v, out, allocator),
    }
}

/// How a shorthand is serialized from its longhands.
pub const ShorthandMode = enum {
    /// A declaration block's value (el.style): omitted components are
    /// left out where the grammar allows.
    specified,
    /// getComputedStyle: every component of a border side.
    computed,
};

/// CSSOM "serialize a CSS value" of a shorthand from the values of its
/// longhands (in `Shorthand.longhands` order). False when the values
/// cannot be written as the shorthand; the caller answers "".
pub fn serializeShorthand(s: Shorthand, vs: []const Assigned, mode: ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    // A shorthand whose longhands are all one CSS-wide keyword is that
    // keyword; a mix of keywords and values cannot be serialized.
    var wide_count: usize = 0;
    for (vs) |v| if (v == .css_wide) {
        wide_count += 1;
    };
    if (wide_count > 0) {
        if (wide_count != vs.len) return false;
        for (vs[1..]) |v| if (v.css_wide != vs[0].css_wide) return false;
        try out.appendSlice(allocator, vs[0].css_wide.name());
        return true;
    }
    if (s == .all) return false;
    const ls = s.longhands();
    switch (s) {
        .margin, .padding, .inset, .border_width, .border_style, .border_color => {
            const top = vs[0].value;
            const right = vs[1].value;
            const bottom = vs[2].value;
            const left = vs[3].value;
            const n: usize = if (!left.eql(right)) 4 else if (!bottom.eql(top)) 3 else if (!right.eql(top)) 2 else 1;
            for (0..n) |i| {
                if (i > 0) try out.append(allocator, ' ');
                try serializeValue(ls[i], vs[i].value, out, allocator);
            }
            return true;
        },
        .margin_block, .margin_inline, .padding_block, .padding_inline, .inset_block, .inset_inline, .border_block_width, .border_block_style, .border_block_color, .border_inline_width, .border_inline_style, .border_inline_color, .overflow => {
            try serializeValue(ls[0], vs[0].value, out, allocator);
            if (!vs[1].value.eql(vs[0].value)) {
                try out.append(allocator, ' ');
                try serializeValue(ls[1], vs[1].value, out, allocator);
            }
            return true;
        },
        .border_top, .border_right, .border_bottom, .border_left, .border_block_start, .border_block_end, .border_inline_start, .border_inline_end => return borderSideText(ls, vs, mode, out, allocator),
        .border, .border_block, .border_inline => {
            // Every side must agree: widths, then styles, then colors.
            const sides = ls.len / 3;
            for (0..3) |group| {
                const first = vs[group * sides].value;
                for (1..sides) |k| if (!vs[group * sides + k].value.eql(first)) return false;
            }
            const side_values = [3]Assigned{ vs[0], vs[sides], vs[2 * sides] };
            const side_longhands = [3]Longhand{ ls[0], ls[sides], ls[2 * sides] };
            return borderSideText(&side_longhands, &side_values, mode, out, allocator);
        },
        .white_space => {
            const c = vs[0].value.keyword;
            const w = vs[1].value.keyword;
            const legacy: ?[]const u8 = if (c == .collapse and w == .wrap) "normal" else if (c == .preserve and w == .nowrap) "pre" else if (c == .preserve and w == .wrap) "pre-wrap" else if (c == .preserve_breaks and w == .wrap) "pre-line" else null;
            if (legacy) |text| {
                try out.appendSlice(allocator, text);
                return true;
            }
            if (c == .collapse) {
                try out.appendSlice(allocator, w.name());
            } else if (w == .wrap) {
                try out.appendSlice(allocator, c.name());
            } else {
                try out.appendSlice(allocator, c.name());
                try out.append(allocator, ' ');
                try out.appendSlice(allocator, w.name());
            }
            return true;
        },
        .background => {
            // Crane keeps two of background's longhands; the others are
            // their initial values.
            const image = vs[0].value;
            const color = vs[1].value;
            const image_initial = image.isKeyword(.none);
            const color_initial = color == .color and color.color.eql(Color.transparent);
            if (mode == .computed) {
                try serializeValue(.background_color, color, out, allocator);
                try out.append(allocator, ' ');
                try serializeValue(.background_image, image, out, allocator);
                return true;
            }
            if (image_initial and color_initial) {
                try out.appendSlice(allocator, "none");
                return true;
            }
            if (!image_initial) try serializeValue(.background_image, image, out, allocator);
            if (!color_initial) {
                if (!image_initial) try out.append(allocator, ' ');
                try serializeValue(.background_color, color, out, allocator);
            }
            return true;
        },
        .all => return false,
    }
}

fn borderSideText(ls: []const Longhand, vs: []const Assigned, mode: ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    var wrote = false;
    for (0..3) |i| {
        const v = vs[i].value;
        if (mode == .specified and v.eql(ls[i].info().initial)) continue;
        if (wrote) try out.append(allocator, ' ');
        try serializeValue(ls[i], v, out, allocator);
        wrote = true;
    }
    // All three initial: the shortest form that sets them, the width.
    if (!wrote) try serializeValue(ls[0], vs[0].value, out, allocator);
    return true;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn parseText(property: []const u8, text: []const u8, list: *std.ArrayList(Assignment)) !bool {
    const p = lookup(property) orelse return error.UnknownProperty;
    return parseDeclaration(.{ .allocator = testing.allocator }, p, text, list);
}

fn freeAssignments(list: *std.ArrayList(Assignment)) void {
    for (list.items) |a| a.value.release();
    list.deinit(testing.allocator);
}

fn expectSerialized(property: []const u8, text: []const u8, expected: []const u8) !void {
    var list: std.ArrayList(Assignment) = .empty;
    defer freeAssignments(&list);
    try testing.expect(try parseText(property, text, &list));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    switch (lookup(property).?) {
        .longhand => |l| try serializeAssigned(l, list.items[0].value, &out, testing.allocator),
        .shorthand => |s| {
            var vs: [max_assignments]Assigned = undefined;
            for (s.longhands(), 0..) |l, i| {
                for (list.items) |a| if (a.longhand == l) {
                    vs[i] = a.value;
                };
            }
            try testing.expect(try serializeShorthand(s, vs[0..s.longhands().len], .specified, &out, testing.allocator));
        },
    }
    try testing.expectEqualStrings(expected, out.items);
}

fn expectInvalid(property: []const u8, text: []const u8) !void {
    var list: std.ArrayList(Assignment) = .empty;
    defer freeAssignments(&list);
    try testing.expect(!try parseText(property, text, &list));
    try testing.expectEqual(@as(usize, 0), list.items.len);
}

test "lookup: supported properties, case-insensitive; others are unsupported" {
    try testing.expectEqual(Property{ .longhand = .margin_left }, lookup("MARGIN-LEFT").?);
    try testing.expectEqual(Property{ .shorthand = .margin }, lookup("margin").?);
    try testing.expect(lookup("animation") == null);
    try testing.expect(lookup("--x") == null);
    try testing.expectEqualStrings("border-block-end-color", Longhand.border_block_end_color.name());
}

test "keyword longhands take their own keywords only" {
    try expectSerialized("position", "fixed", "fixed");
    try expectSerialized("visibility", "HIDDEN", "hidden");
    try expectInvalid("position", "block");
    try expectInvalid("position", "fixed fixed");
    try expectInvalid("float", "");
}

test "lengths: units, percentages, signs, zero and calc()" {
    try expectSerialized("margin-left", "2px", "2px");
    try expectSerialized("margin-left", "-1.5em", "-1.5em");
    try expectSerialized("margin-left", "auto", "auto");
    try expectSerialized("margin-left", "0", "0px");
    try expectSerialized("width", "50%", "50%");
    try expectSerialized("width", "fit-content", "fit-content");
    try expectInvalid("width", "-1px");
    try expectInvalid("padding-top", "auto");
    try expectInvalid("margin-left", "2");
    try expectInvalid("margin-left", "calc(1px + 2px)");
    try expectInvalid("width", "10deg");
}

test "the quirks mode unitless length applies only in quirks mode and only to its properties" {
    var list: std.ArrayList(Assignment) = .empty;
    defer freeAssignments(&list);
    try testing.expect(try parseDeclaration(.{ .allocator = testing.allocator, .quirks = true }, lookup("width").?, "100", &list));
    try testing.expectEqual(@as(f64, 100), list.items[0].value.value.length.value);
    try testing.expect(!try parseDeclaration(.{ .allocator = testing.allocator, .quirks = true }, lookup("line-height").?, "-1", &list));
}

test "colors: named, hex, rgb(), currentcolor, system colors" {
    try expectSerialized("color", "red", "red");
    try expectSerialized("color", "RED", "red");
    try expectSerialized("color", "#f00", "rgb(255, 0, 0)");
    try expectSerialized("color", "#00ff0080", "rgba(0, 255, 0, 0.5)");
    try expectSerialized("background-color", "transparent", "transparent");
    try expectSerialized("border-top-color", "currentColor", "currentcolor");
    try expectSerialized("color", "CanvasText", "canvastext");
    try expectInvalid("color", "notacolor");
    try expectInvalid("color", "red blue");
}

test "display: legacy, two-keyword and list-item forms" {
    try expectSerialized("display", "block", "block");
    try expectSerialized("display", "inline flow-root", "inline-block");
    try expectSerialized("display", "flex", "flex");
    try expectSerialized("display", "list-item", "list-item");
    try expectSerialized("display", "inline list-item", "inline list-item");
    try expectSerialized("display", "table-cell", "table-cell");
    try expectSerialized("display", "ruby", "ruby");
    try expectInvalid("display", "block inline");
    try expectInvalid("display", "list-item table");
}

test "font properties" {
    try expectSerialized("font-family", "\"Helvetica Neue\", Helvetica,  Arial, sans-serif", "\"Helvetica Neue\", Helvetica, Arial, sans-serif");
    try expectSerialized("font-family", "Times New Roman", "Times New Roman");
    try expectSerialized("font-weight", "bold", "bold");
    try expectSerialized("font-weight", "650", "650");
    try expectSerialized("font-weight", "bolder", "bolder");
    try expectInvalid("font-weight", "0");
    try expectSerialized("font-size", "x-large", "x-large");
    try expectSerialized("line-height", "1.5", "1.5");
    try expectInvalid("font-family", "");
}

test "images: none, url() resolved, gradients kept as written" {
    try expectSerialized("background-image", "url(a.png)", "url(\"a.png\")");
    try expectSerialized("background-image", "url('b c.png')", "url(\"b c.png\")");
    try expectSerialized("background-image", "none", "none");
    try expectSerialized("background-image", "linear-gradient(red, blue)", "linear-gradient(red, blue)");
    try expectInvalid("background-image", "red");
}

test "z-index and opacity" {
    try expectSerialized("z-index", "5", "5");
    try expectSerialized("z-index", "auto", "auto");
    try expectInvalid("z-index", "1.5");
    try expectSerialized("opacity", "50%", "0.5");
}

test "CSS-wide keywords set every longhand of a shorthand" {
    var list: std.ArrayList(Assignment) = .empty;
    defer freeAssignments(&list);
    try testing.expect(try parseText("margin", "inherit", &list));
    try testing.expectEqual(@as(usize, 4), list.items.len);
    try testing.expectEqual(values.CssWide.inherit, list.items[3].value.css_wide);
    try testing.expect(try parseText("all", "revert-layer", &list));
    try testing.expectEqual(@as(usize, 4 + max_assignments), list.items.len);
    try expectInvalid("all", "red");
}

test "box shorthands expand 1-4 values and serialize back to the shortest" {
    try expectSerialized("margin", "1px", "1px");
    try expectSerialized("margin", "1px 2px", "1px 2px");
    try expectSerialized("margin", "1px 2px 1px", "1px 2px");
    try expectSerialized("margin", "1px 2px 3px", "1px 2px 3px");
    try expectSerialized("margin", "1px 2px 3px 4px", "1px 2px 3px 4px");
    try expectSerialized("margin-block", "1em", "1em");
    try expectSerialized("padding-inline", "1px 2px", "1px 2px");
    try expectInvalid("margin", "1px 2px 3px 4px 5px");
    try expectInvalid("padding", "-1px");
}

test "border shorthands: any order, omitted parts initial" {
    try expectSerialized("border", "solid", "solid");
    try expectSerialized("border-top", "1px solid red", "1px solid red");
    try expectSerialized("border-left", "red 2px", "2px red");
    try expectSerialized("border-style", "solid none", "solid none");
    try expectInvalid("border", "solid solid");
    try expectInvalid("border", "1px 2px");
}

test "white-space and overflow" {
    try expectSerialized("white-space", "pre", "pre");
    try expectSerialized("white-space", "pre-line", "pre-line");
    try expectSerialized("white-space", "nowrap", "nowrap");
    try expectSerialized("white-space", "break-spaces", "break-spaces");
    try expectSerialized("white-space", "preserve nowrap", "pre");
    try expectSerialized("overflow", "hidden", "hidden");
    try expectSerialized("overflow", "hidden auto", "hidden auto");
    try expectInvalid("white-space", "pre pre");
}

test "background: every component parses, image and color are kept" {
    try expectSerialized("background", "green", "green");
    try expectSerialized("background", "url(x.png) no-repeat center / cover red", "url(\"x.png\") red");
    try expectSerialized("background", "url(a.png), url(b.png) blue", "url(\"a.png\"), url(\"b.png\") blue");
    try expectInvalid("background", "red, blue");
    try expectInvalid("background", "bogus");
}

test "logical sides map by writing mode and direction" {
    try testing.expectEqual(PhysicalSide.left, physicalSide(.inline_start, .horizontal_tb, .ltr));
    try testing.expectEqual(PhysicalSide.right, physicalSide(.inline_start, .horizontal_tb, .rtl));
    try testing.expectEqual(PhysicalSide.top, physicalSide(.block_start, .horizontal_tb, .ltr));
    try testing.expectEqual(PhysicalSide.right, physicalSide(.block_start, .vertical_rl, .ltr));
    try testing.expectEqual(PhysicalSide.bottom, physicalSide(.inline_start, .sideways_lr, .ltr));
    try testing.expectEqual(Longhand.margin_left, physicalLonghand(.margin, .left));
}

test "the lexicographic order is the enum's" {
    try testing.expectEqualStrings("appearance", lexicographic[0].name());
    try testing.expectEqualStrings("z-index", lexicographic[Longhand.count - 1].name());
}
