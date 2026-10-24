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
//! - CSS Color Adjustment 1: color-scheme
//! - CSS Box 4 / Sizing 3: margin-*, padding-*, width, height
//! - CSS Fonts 4: font-family, font-size, font-style, font-weight
//! - CSS Inline 3 / CSS 2.1: line-height
//! - CSS Text 4: white-space-collapse, text-wrap-mode, white-space, text-transform
//! - CSS Overflow 3: overflow-x, overflow-y, overflow
//! - CSS UI 4: appearance
//! - CSS Cascade 5: all
//!
//! Scalar math uses typed CSS Values 4 expressions. var()/env() remain
//! unsupported; image/background grammars retain their previous math
//! rejection until they consume that typed parser (row 118 Q16).
//!
//! Spec: https://drafts.csswg.org/css-cascade-5/#shorthand
//! Spec: https://drafts.csswg.org/cssom-1/#serializing-css-values

const std = @import("std");
const Allocator = std.mem.Allocator;
const tokenizer_mod = @import("tokenizer.zig");
const Tokenizer = tokenizer_mod.Tokenizer;
const Token = tokenizer_mod.Token;
const values = @import("style_values.zig");
const resources = @import("resource_values.zig");
const math_values = @import("math_values.zig");
const color_mod = @import("values/color.zig");
const color_scheme_mod = @import("color_scheme.zig");
const serialize_mod = @import("serialize.zig");
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
    align_content,
    align_items,
    align_self,
    anchor_name,
    anchor_scope,
    appearance,
    background_color,
    background_image,
    block_size,
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
    color_scheme,
    column_gap,
    content,
    content_visibility,
    direction,
    display,
    float,
    font_family,
    font_size,
    font_style,
    font_weight,
    grid_column_end,
    grid_column_start,
    grid_row_end,
    grid_row_start,
    grid_auto_columns,
    grid_auto_rows,
    grid_auto_flow,
    grid_template_columns,
    grid_template_rows,
    grid_template_areas,
    fit_tolerance,
    accent_color,
    box_sizing,
    caret_animation,
    caret_color,
    caret_shape,
    field_sizing,
    interactivity,
    outline_color,
    outline_offset,
    outline_style,
    outline_width,
    resize,
    height,
    inline_size,
    inset_block_end,
    inset_block_start,
    inset_inline_end,
    inset_inline_start,
    justify_content,
    justify_items,
    justify_self,
    left,
    letter_spacing,
    line_height,
    margin_block_end,
    margin_block_start,
    margin_bottom,
    margin_inline_end,
    margin_inline_start,
    margin_left,
    margin_right,
    margin_top,
    max_block_size,
    max_height,
    max_inline_size,
    max_width,
    min_block_size,
    min_height,
    min_inline_size,
    min_width,
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
    position_anchor,
    position_area,
    position_try_fallbacks,
    position_try_order,
    right,
    row_gap,
    text_orientation,
    text_transform,
    text_wrap_mode,
    top,
    unicode_bidi,
    user_select,
    visibility,
    white_space_collapse,
    width,
    writing_mode,
    z_index,
    // Row118: complete animation value lists (Q69).
    animation_duration,
    animation_timing_function,
    animation_delay,
    animation_iteration_count,
    animation_direction,
    animation_fill_mode,
    animation_play_state,
    animation_name,
    animation_composition,
    animation_timeline,
    animation_range_start,
    animation_range_end,

    // CSS Transforms 2 §5: individual components, without layout.
    translate,
    rotate,
    scale,

    // CSS Flexbox 1 §7: values independent of flex layout.
    flex_grow,
    flex_shrink,
    flex_basis,

    // CSS Transitions 1/2 §2: five lists; execution is separate.
    transition_property,
    transition_duration,
    transition_timing_function,
    transition_delay,
    transition_behavior,

    // CSS image value families (row 119).
    cursor,
    list_style_image,
    text_indent,
    fill,
    stroke,
    marker_start,
    marker_mid,
    marker_end,
    clip_path,
    filter,
    object_position,
    mask_image,
    mask_position,
    mask_size,
    mask_repeat,
    mask_origin,
    mask_clip,
    mask_composite,
    mask_mode,
    mask_border_source,
    mask_border_slice,
    mask_border_width,
    mask_border_outset,
    mask_border_repeat,
    stroke_width,
    mask_type,
    border_image_source,

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

/// CSSOM 7.2 step 5 enumerates names lexicographically, independently of
/// declaration order. Separate property families can append contiguous blocks.
pub const lexicographic: [Longhand.count]Longhand = blk: {
    @setEvalBranchQuota(100_000);
    var out: [Longhand.count]Longhand = undefined;
    for (0..Longhand.count) |i| out[i] = @enumFromInt(i);
    std.mem.sort(Longhand, &out, {}, struct {
        fn lessThan(_: void, a: Longhand, b: Longhand) bool {
            return std.mem.lessThan(u8, a.name(), b.name());
        }
    }.lessThan);
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

    pub const Group = enum { margin, padding, inset, border_width, border_style, border_color, size, min_size, max_size };
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
        .size => switch (side) {
            .top, .bottom => .height,
            .left, .right => .width,
        },
        .min_size => switch (side) {
            .top, .bottom => .min_height,
            .left, .right => .min_width,
        },
        .max_size => switch (side) {
            .top, .bottom => .max_height,
            .left, .right => .max_width,
        },
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
    animation_list,
    individual_transform,
    flex_factor,
    flex_basis,
    grid_line,
    grid_tracks,
    grid_areas,
    grid_flow,
    fit_tolerance,
    caret_color,
    auto_color,
    signed_length,
    gap,
    alignment,
    anchor_names,
    anchor_scope,
    position_anchor,
    position_area,
    position_try_fallbacks,
    keywords,
    /// <length-percentage> | auto (margins, insets)
    length_percentage_auto,
    /// <length-percentage [0,inf]> (padding)
    length_percentage_nonneg,
    /// auto | <length-percentage [0,inf]> | min-content | max-content | fit-content
    size,
    /// none replaces auto for maximum sizes (CSS Sizing 3 §3.1.3).
    max_size,
    line_width,
    color,
    image,
    display,
    font_family,
    font_size,
    font_weight,
    letter_spacing,
    line_height,
    opacity,
    z_index,
    /// CSS Text 4 text-transform (`values.TextTransform`).
    text_transform,
    /// CSS Color Adjustment 1 color-scheme (`values.ColorScheme`).
    color_scheme,
    /// CSS Generated Content 3: typed strings, attributes and layout values.
    content,
    cursor,
    text_indent,
    paint,
    reference,
    shape,
    filter,
    image_position,
    mask,
    stroke_width,
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
        .{ .longhand = .translate, .inherited = false, .initial = Value.kw(.none), .grammar = .individual_transform },
        .{ .longhand = .rotate, .inherited = false, .initial = Value.kw(.none), .grammar = .individual_transform },
        .{ .longhand = .scale, .inherited = false, .initial = Value.kw(.none), .grammar = .individual_transform },
        .{ .longhand = .flex_grow, .inherited = false, .initial = .{ .number = 0 }, .grammar = .flex_factor },
        .{ .longhand = .flex_shrink, .inherited = false, .initial = .{ .number = 1 }, .grammar = .flex_factor },
        .{ .longhand = .flex_basis, .inherited = false, .initial = Value.kw(.auto), .grammar = .flex_basis },
        .{ .longhand = .transition_property, .inherited = false, .initial = Value.kw(.all), .grammar = .animation_list },
        .{ .longhand = .transition_duration, .inherited = false, .initial = .{ .number = 0 }, .grammar = .animation_list },
        .{ .longhand = .transition_timing_function, .inherited = false, .initial = Value.kw(.ease), .grammar = .animation_list },
        .{ .longhand = .transition_delay, .inherited = false, .initial = .{ .number = 0 }, .grammar = .animation_list },
        .{ .longhand = .transition_behavior, .inherited = false, .initial = Value.kw(.normal), .grammar = .animation_list },
        // Row118 animation properties; execution is outside this value layer.
        .{ .longhand = .animation_duration, .inherited = false, .initial = Value.kw(.auto), .grammar = .animation_list },
        .{ .longhand = .animation_timing_function, .inherited = false, .initial = Value.kw(.ease), .grammar = .animation_list },
        .{ .longhand = .animation_delay, .inherited = false, .initial = .{ .number = 0 }, .grammar = .animation_list },
        .{ .longhand = .animation_iteration_count, .inherited = false, .initial = .{ .number = 1 }, .grammar = .animation_list },
        .{ .longhand = .animation_direction, .inherited = false, .initial = Value.kw(.normal), .grammar = .animation_list },
        .{ .longhand = .animation_fill_mode, .inherited = false, .initial = Value.kw(.none), .grammar = .animation_list },
        .{ .longhand = .animation_play_state, .inherited = false, .initial = Value.kw(.running), .grammar = .animation_list },
        .{ .longhand = .animation_name, .inherited = false, .initial = Value.kw(.none), .grammar = .animation_list },
        .{ .longhand = .animation_composition, .inherited = false, .initial = Value.kw(.replace), .grammar = .animation_list },
        .{ .longhand = .animation_timeline, .inherited = false, .initial = Value.kw(.auto), .grammar = .animation_list },
        .{ .longhand = .animation_range_start, .inherited = false, .initial = Value.kw(.normal), .grammar = .animation_list },
        .{ .longhand = .animation_range_end, .inherited = false, .initial = Value.kw(.normal), .grammar = .animation_list },

        .{ .longhand = .grid_auto_columns, .inherited = false, .initial = Value.kw(.auto), .grammar = .grid_tracks },
        .{ .longhand = .grid_auto_rows, .inherited = false, .initial = Value.kw(.auto), .grammar = .grid_tracks },
        .{ .longhand = .grid_auto_flow, .inherited = false, .initial = .{ .grid_flow = .{} }, .grammar = .grid_flow },
        .{ .longhand = .grid_template_columns, .inherited = false, .initial = Value.kw(.none), .grammar = .grid_tracks },
        .{ .longhand = .grid_template_rows, .inherited = false, .initial = Value.kw(.none), .grammar = .grid_tracks },
        .{ .longhand = .grid_template_areas, .inherited = false, .initial = Value.kw(.none), .grammar = .grid_areas },
        .{ .longhand = .fit_tolerance, .inherited = false, .initial = Value.kw(.normal), .grammar = .fit_tolerance },
        .{ .longhand = .accent_color, .inherited = true, .initial = Value.kw(.auto), .grammar = .auto_color },
        .{ .longhand = .box_sizing, .inherited = false, .initial = Value.kw(.content_box), .grammar = .keywords, .keywords = &.{ .content_box, .border_box } },
        .{ .longhand = .caret_animation, .inherited = true, .initial = Value.kw(.auto), .grammar = .keywords, .keywords = &.{ .auto, .manual } },
        .{ .longhand = .caret_color, .inherited = true, .initial = Value.kw(.auto), .grammar = .caret_color },
        .{ .longhand = .caret_shape, .inherited = true, .initial = Value.kw(.auto), .grammar = .keywords, .keywords = &.{ .auto, .bar, .block, .underscore } },
        .{ .longhand = .field_sizing, .inherited = false, .initial = Value.kw(.fixed), .grammar = .keywords, .keywords = &.{ .fixed, .content } },
        .{ .longhand = .interactivity, .inherited = true, .initial = Value.kw(.auto), .grammar = .keywords, .keywords = &.{ .auto, .inert } },
        .{ .longhand = .outline_color, .inherited = false, .initial = .{ .color = .current }, .grammar = .color },
        .{ .longhand = .outline_offset, .inherited = false, .initial = zero, .grammar = .signed_length },
        .{ .longhand = .outline_style, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &.{ .auto, .none, .dotted, .dashed, .solid, .double, .groove, .ridge, .inset, .outset } },
        .{ .longhand = .outline_width, .inherited = false, .initial = medium_width, .grammar = .line_width },
        .{ .longhand = .resize, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &.{ .none, .both, .horizontal, .vertical, .block, .@"inline" } },
        .{ .longhand = .grid_column_end, .inherited = false, .initial = Value.kw(.auto), .grammar = .grid_line },
        .{ .longhand = .grid_column_start, .inherited = false, .initial = Value.kw(.auto), .grammar = .grid_line },
        .{ .longhand = .grid_row_end, .inherited = false, .initial = Value.kw(.auto), .grammar = .grid_line },
        .{ .longhand = .grid_row_start, .inherited = false, .initial = Value.kw(.auto), .grammar = .grid_line },
        .{ .longhand = .column_gap, .inherited = false, .initial = Value.kw(.normal), .grammar = .gap },
        .{ .longhand = .row_gap, .inherited = false, .initial = Value.kw(.normal), .grammar = .gap },
        .{ .longhand = .align_content, .inherited = false, .initial = .{ .alignment = .{ .position = .normal } }, .grammar = .alignment },
        .{ .longhand = .align_items, .inherited = false, .initial = .{ .alignment = .{ .position = .normal } }, .grammar = .alignment },
        .{ .longhand = .align_self, .inherited = false, .initial = .{ .alignment = .{ .position = .auto } }, .grammar = .alignment },
        .{ .longhand = .justify_content, .inherited = false, .initial = .{ .alignment = .{ .position = .normal } }, .grammar = .alignment },
        .{ .longhand = .justify_items, .inherited = false, .initial = .{ .alignment = .{ .position = .legacy } }, .grammar = .alignment },
        .{ .longhand = .justify_self, .inherited = false, .initial = .{ .alignment = .{ .position = .auto } }, .grammar = .alignment },
        .{ .longhand = .anchor_name, .inherited = false, .initial = Value.kw(.none), .grammar = .anchor_names },
        .{ .longhand = .anchor_scope, .inherited = false, .initial = Value.kw(.none), .grammar = .anchor_scope },
        .{ .longhand = .appearance, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &.{ .none, .auto, .base, .base_select, .searchfield, .textarea, .checkbox, .radio, .menulist, .listbox, .meter, .progress_bar, .button, .textfield, .menulist_button } },
        .{ .longhand = .background_color, .inherited = false, .initial = .{ .color = Color.transparent }, .grammar = .color, .quirky_color = true },
        .{ .longhand = .background_image, .inherited = false, .initial = Value.kw(.none), .grammar = .image },
        .{ .longhand = .block_size, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .logical = .{ .group = .size, .side = .block_start } },
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
        // CSS Color 4: "Initial: CanvasText" - resolved in the element's
        // color scheme when it is computed (initialComputed answers the light
        // one where there is no element).
        .{ .longhand = .color, .inherited = true, .initial = .{ .color = .{ .system = .canvastext } }, .grammar = .color, .quirky_color = true },
        // CSS Color Adjustment 1 2.2: "Initial: normal", "Inherited: yes".
        .{ .longhand = .color_scheme, .inherited = true, .initial = Value.kw(.normal), .grammar = .color_scheme },
        .{ .longhand = .content, .inherited = false, .initial = Value.kw(.normal), .grammar = .content },
        // CSS Contain 2 §4: non-inherited; the computed value is as specified.
        .{ .longhand = .content_visibility, .inherited = false, .initial = Value.kw(.visible), .grammar = .keywords, .keywords = &.{ .visible, .auto, .hidden } },
        .{ .longhand = .direction, .inherited = true, .initial = Value.kw(.ltr), .grammar = .keywords, .keywords = &.{ .ltr, .rtl } },
        .{ .longhand = .display, .inherited = false, .initial = .{ .display = Display.inline_flow }, .grammar = .display },
        .{ .longhand = .float, .inherited = false, .initial = Value.kw(.none), .grammar = .keywords, .keywords = &.{ .none, .left, .right, .inline_start, .inline_end } },
        // CSS Fonts 4: "Initial: depends on user agent" - serif (design Q11).
        .{ .longhand = .font_family, .inherited = true, .initial = Value.kw(.serif), .grammar = .font_family },
        .{ .longhand = .font_size, .inherited = true, .initial = Value.kw(.medium), .grammar = .font_size, .quirky_length = true },
        .{ .longhand = .font_style, .inherited = true, .initial = Value.kw(.normal), .grammar = .keywords, .keywords = &.{ .normal, .italic, .oblique } },
        .{ .longhand = .font_weight, .inherited = true, .initial = .{ .number = 400 }, .grammar = .font_weight },
        .{ .longhand = .height, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .quirky_length = true },
        .{ .longhand = .inline_size, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .logical = .{ .group = .size, .side = .inline_start } },
        .{ .longhand = .inset_block_end, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .logical = .{ .group = .inset, .side = .block_end } },
        .{ .longhand = .inset_block_start, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .logical = .{ .group = .inset, .side = .block_start } },
        .{ .longhand = .inset_inline_end, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .logical = .{ .group = .inset, .side = .inline_end } },
        .{ .longhand = .inset_inline_start, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .logical = .{ .group = .inset, .side = .inline_start } },
        .{ .longhand = .left, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .quirky_length = true },
        // CSS Text4 §8.2: normal computes to zero; percentages stay computed.
        .{ .longhand = .letter_spacing, .inherited = true, .initial = Value.kw(.normal), .grammar = .letter_spacing, .quirky_length = true },
        .{ .longhand = .line_height, .inherited = true, .initial = Value.kw(.normal), .grammar = .line_height, .quirky_length = true },
        .{ .longhand = .margin_block_end, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .logical = .{ .group = .margin, .side = .block_end } },
        .{ .longhand = .margin_block_start, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .logical = .{ .group = .margin, .side = .block_start } },
        .{ .longhand = .margin_bottom, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .margin_inline_end, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .logical = .{ .group = .margin, .side = .inline_end } },
        .{ .longhand = .margin_inline_start, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .logical = .{ .group = .margin, .side = .inline_start } },
        .{ .longhand = .margin_left, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .margin_right, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .margin_top, .inherited = false, .initial = zero, .grammar = .length_percentage_auto, .quirky_length = true },
        // CSS Sizing 3 §§3.1.2–3.1.3 and CSS Logical 1 §4.1.
        .{ .longhand = .max_block_size, .inherited = false, .initial = Value.kw(.none), .grammar = .max_size, .logical = .{ .group = .max_size, .side = .block_start } },
        .{ .longhand = .max_height, .inherited = false, .initial = Value.kw(.none), .grammar = .max_size, .quirky_length = true },
        .{ .longhand = .max_inline_size, .inherited = false, .initial = Value.kw(.none), .grammar = .max_size, .logical = .{ .group = .max_size, .side = .inline_start } },
        .{ .longhand = .max_width, .inherited = false, .initial = Value.kw(.none), .grammar = .max_size, .quirky_length = true },
        .{ .longhand = .min_block_size, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .logical = .{ .group = .min_size, .side = .block_start } },
        .{ .longhand = .min_height, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .quirky_length = true },
        .{ .longhand = .min_inline_size, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .logical = .{ .group = .min_size, .side = .inline_start } },
        .{ .longhand = .min_width, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .quirky_length = true },
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
        // CSSWG reversed the position shorthand/reset resolution on 2024-09-04:
        // https://github.com/w3c/csswg-drafts/issues/10321#issuecomment-2330338181
        // Both pinned/upstream WPT and C/F/S ship normal as the initial value.
        .{ .longhand = .position_anchor, .inherited = false, .initial = Value.kw(.normal), .grammar = .position_anchor },
        .{ .longhand = .position_area, .inherited = false, .initial = Value.kw(.none), .grammar = .position_area },
        .{ .longhand = .position_try_fallbacks, .inherited = false, .initial = Value.kw(.none), .grammar = .position_try_fallbacks },
        .{ .longhand = .position_try_order, .inherited = false, .initial = Value.kw(.normal), .grammar = .keywords, .keywords = &.{ .normal, .most_width, .most_height, .most_block_size, .most_inline_size } },
        .{ .longhand = .right, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .quirky_length = true },
        // Writing Modes 4 §5.1: computed as specified, including horizontal boxes.
        .{ .longhand = .text_orientation, .inherited = true, .initial = Value.kw(.mixed), .grammar = .keywords, .keywords = &.{ .mixed, .upright, .sideways, .sideways_right } },
        .{ .longhand = .text_transform, .inherited = true, .initial = .{ .text_transform = .{} }, .grammar = .text_transform },
        .{ .longhand = .text_wrap_mode, .inherited = true, .initial = Value.kw(.wrap), .grammar = .keywords, .keywords = &.{ .wrap, .nowrap } },
        .{ .longhand = .top, .inherited = false, .initial = Value.kw(.auto), .grammar = .length_percentage_auto, .quirky_length = true },
        .{ .longhand = .unicode_bidi, .inherited = false, .initial = Value.kw(.normal), .grammar = .keywords, .keywords = &.{ .normal, .embed, .isolate, .bidi_override, .isolate_override, .plaintext } },
        // CSS UI 4 §6.1: auto remains computed auto; selection resolves its
        // used value against the parent. Explicit inherit uses the cascade.
        // contain remains in the current grammar: Gecko bug 1036853 is open;
        // Blink/WebKit also describe it as unimplemented, not declined (Q2).
        .{ .longhand = .user_select, .inherited = false, .initial = Value.kw(.auto), .grammar = .keywords, .keywords = &.{ .auto, .text, .none, .contain, .all } },
        .{ .longhand = .visibility, .inherited = true, .initial = Value.kw(.visible), .grammar = .keywords, .keywords = &.{ .visible, .hidden, .collapse } },
        .{ .longhand = .white_space_collapse, .inherited = true, .initial = Value.kw(.collapse), .grammar = .keywords, .keywords = &.{ .collapse, .discard, .preserve, .preserve_breaks, .preserve_spaces, .break_spaces } },
        .{ .longhand = .width, .inherited = false, .initial = Value.kw(.auto), .grammar = .size, .quirky_length = true },
        .{ .longhand = .writing_mode, .inherited = true, .initial = Value.kw(.horizontal_tb), .grammar = .keywords, .keywords = &.{ .horizontal_tb, .vertical_rl, .vertical_lr, .sideways_rl, .sideways_lr } },
        .{ .longhand = .z_index, .inherited = false, .initial = Value.kw(.auto), .grammar = .z_index },
        // CSS UI4 §5.1.1; CSS Lists3 §3.3.
        .{ .longhand = .cursor, .inherited = true, .initial = Value.kw(.auto), .grammar = .cursor },
        .{ .longhand = .list_style_image, .inherited = true, .initial = Value.kw(.none), .grammar = .image },
        .{ .longhand = .text_indent, .inherited = true, .initial = Value.px(0), .grammar = .text_indent },
        .{ .longhand = .fill, .inherited = true, .initial = .{ .color = Color.black }, .grammar = .paint },
        .{ .longhand = .stroke, .inherited = true, .initial = Value.kw(.none), .grammar = .paint },
        .{ .longhand = .marker_start, .inherited = true, .initial = Value.kw(.none), .grammar = .reference },
        .{ .longhand = .marker_mid, .inherited = true, .initial = Value.kw(.none), .grammar = .reference },
        .{ .longhand = .marker_end, .inherited = true, .initial = Value.kw(.none), .grammar = .reference },
        .{ .longhand = .clip_path, .inherited = false, .initial = Value.kw(.none), .grammar = .shape },
        .{ .longhand = .filter, .inherited = false, .initial = Value.kw(.none), .grammar = .filter },
        .{ .longhand = .object_position, .inherited = false, .initial = Value.kw(.center), .grammar = .image_position },
        .{ .longhand = .mask_image, .inherited = false, .initial = Value.kw(.none), .grammar = .mask },
        .{ .longhand = .mask_position, .inherited = false, .initial = .{ .length = .percent(0) }, .grammar = .mask },
        .{ .longhand = .mask_size, .inherited = false, .initial = Value.kw(.auto), .grammar = .mask },
        .{ .longhand = .mask_repeat, .inherited = false, .initial = .{ .image_repeat = .{ .x = .repeat, .y = .repeat } }, .grammar = .mask },
        .{ .longhand = .mask_origin, .inherited = false, .initial = .{ .image_keyword = .border_box }, .grammar = .mask },
        .{ .longhand = .mask_clip, .inherited = false, .initial = .{ .image_keyword = .border_box }, .grammar = .mask },
        .{ .longhand = .mask_composite, .inherited = false, .initial = .{ .image_keyword = .add }, .grammar = .mask },
        .{ .longhand = .mask_mode, .inherited = false, .initial = .{ .image_keyword = .match_source }, .grammar = .mask },
        .{ .longhand = .mask_border_source, .inherited = false, .initial = Value.kw(.none), .grammar = .mask },
        .{ .longhand = .mask_border_slice, .inherited = false, .initial = .{ .number = 0 }, .grammar = .mask },
        .{ .longhand = .mask_border_width, .inherited = false, .initial = Value.kw(.auto), .grammar = .mask },
        .{ .longhand = .mask_border_outset, .inherited = false, .initial = .{ .number = 0 }, .grammar = .mask },
        .{ .longhand = .mask_border_repeat, .inherited = false, .initial = .{ .image_repeat = .{ .x = .stretch, .y = .stretch, .border = true } }, .grammar = .mask },
        .{ .longhand = .stroke_width, .inherited = true, .initial = Value.px(1), .grammar = .stroke_width },
        .{ .longhand = .mask_type, .inherited = false, .initial = .{ .image_keyword = .luminance }, .grammar = .mask },
        // CSS Backgrounds3 §5.1: one image, independently of border widths.
        .{ .longhand = .border_image_source, .inherited = false, .initial = Value.kw(.none), .grammar = .image },
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
    _webkit_text_orientation,
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
    gap,
    grid_area,
    grid_column,
    grid_row,
    grid_template,
    grid,
    outline,
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
    place_content,
    place_items,
    place_self,
    position_try,
    white_space,
    animation,
    animation_range,
    flex,
    transition,
    marker,
    mask,
    mask_border,

    pub fn name(self: Shorthand) []const u8 {
        return switch (self) {
            inline else => |s| comptime dashedName(@tagName(s)),
        };
    }

    /// The longhands, in canonical order (CSSOM "shorthand ... maps to").
    pub fn longhands(self: Shorthand) []const Longhand {
        return switch (self) {
            ._webkit_text_orientation => &.{.text_orientation},
            .all => &all_longhands,
            .background => &.{ .background_image, .background_color },
            .border => &.{ .border_top_width, .border_right_width, .border_bottom_width, .border_left_width, .border_top_style, .border_right_style, .border_bottom_style, .border_left_style, .border_top_color, .border_right_color, .border_bottom_color, .border_left_color, .border_image_source },
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
            .gap => &.{ .row_gap, .column_gap },
            .grid_area => &.{ .grid_row_start, .grid_column_start, .grid_row_end, .grid_column_end },
            .grid_column => &.{ .grid_column_start, .grid_column_end },
            .grid_row => &.{ .grid_row_start, .grid_row_end },
            .grid_template => &.{ .grid_template_rows, .grid_template_columns, .grid_template_areas },
            .grid => &.{ .grid_template_rows, .grid_template_columns, .grid_template_areas, .grid_auto_flow, .grid_auto_rows, .grid_auto_columns },
            .outline => &.{ .outline_width, .outline_style, .outline_color },
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
            .place_content => &.{ .align_content, .justify_content },
            .place_items => &.{ .align_items, .justify_items },
            .place_self => &.{ .align_self, .justify_self },
            .position_try => &.{ .position_try_order, .position_try_fallbacks },
            .white_space => &.{ .white_space_collapse, .text_wrap_mode },
            .animation => &.{ .animation_duration, .animation_timing_function, .animation_delay, .animation_iteration_count, .animation_direction, .animation_fill_mode, .animation_play_state, .animation_name, .animation_timeline, .animation_range_start, .animation_range_end },
            .animation_range => &.{ .animation_range_start, .animation_range_end },
            .flex => &.{ .flex_grow, .flex_shrink, .flex_basis },
            .transition => &.{ .transition_property, .transition_duration, .transition_timing_function, .transition_delay, .transition_behavior },
            .marker => &.{ .marker_start, .marker_mid, .marker_end },
            .mask => &@import("mask_values.zig").longhands,
            .mask_border => &@import("mask_values.zig").border_longhands,
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

/// CSS Cascade 5 1.1 "legacy name aliases" of supported properties: a
/// property known by another name, which parses, reads and sets the same
/// property (and is not enumerated). CSS UI 4: "-webkit-appearance" is a
/// legacy name alias of appearance.
const legacy_aliases = .{
    // CSS Gaps 1 §2.4: aliases share the canonical property entries.
    .{ "flow-tolerance", Property{ .longhand = .fit_tolerance } },
    .{ "grid-row-gap", Property{ .longhand = .row_gap } },
    .{ "grid-column-gap", Property{ .longhand = .column_gap } },
    .{ "grid-gap", Property{ .shorthand = .gap } },
    .{ "-webkit-appearance", Property{ .longhand = .appearance } },
    // CSS UI 4 §6.1 requires the legacy spelling to alias user-select.
    .{ "-webkit-user-select", Property{ .longhand = .user_select } },
};

/// Names exposed by CSSStyleProperties as attributes, but not as separate
/// declarations or computed longhand entries (CSSOM 6.6.2).
pub const legacy_alias_names = blk: {
    var names: [legacy_aliases.len][]const u8 = undefined;
    for (legacy_aliases, 0..) |alias, i| names[i] = alias[0];
    break :blk names;
};

const by_name = blk: {
    @setEvalBranchQuota(100_000);
    const l_fields = @typeInfo(Longhand).@"enum".fields;
    const s_fields = @typeInfo(Shorthand).@"enum".fields;
    var entries: [l_fields.len + s_fields.len + legacy_aliases.len]struct { []const u8, Property } = undefined;
    for (l_fields, 0..) |f, i| entries[i] = .{ dashedName(f.name), .{ .longhand = @enumFromInt(f.value) } };
    for (s_fields, 0..) |f, i| entries[l_fields.len + i] = .{ dashedName(f.name), .{ .shorthand = @enumFromInt(f.value) } };
    for (legacy_aliases, 0..) |alias, i| entries[l_fields.len + s_fields.len + i] = .{ alias[0], alias[1] };
    break :blk std.StaticStringMap(Property).initComptime(entries);
};

test "a legacy name alias is the property it names" {
    try std.testing.expectEqual(Property{ .longhand = .appearance }, lookup("-webkit-appearance").?);
    try std.testing.expectEqual(Property{ .longhand = .appearance }, lookup("-WEBKIT-APPEARANCE").?);
    try std.testing.expectEqual(@as(?Property, null), lookup("-webkit-filter"));
}

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
    /// Borrowed while parsing; resource-bearing values retain this record.
    /// CSS Variables 1 §2.1: future untyped var() substitution must supply
    /// the CONSUMING declaration's source after substituting its tokens.
    resource_source: ?*values.ResourceSource = null,
    /// Borrowed, immutable source ordinals for numeric random() functions.
    random_scope: ?*const @import("random_values.zig").ParseScope = null,
    /// SVG2 §4.2 presentation-attribute number-to-length parsing context.
    svg_presentation: bool = false,
};

pub const UrlResolver = resources.UrlResolver;

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
    const content_functions = property == .longhand and property.longhand == .content;
    const opaque_image = (property == .longhand and property.longhand == .background_image) or
        (property == .shorthand and property.shorthand == .background);
    var functions = FunctionFlags{};
    if (containsUnsupportedToken(text, content_functions, opaque_image, &functions)) return false;
    if (functions.random_item) {
        const pending = try @import("pending_values.zig").Pending.create(options, property, text) orelse return false;
        defer pending.unref();
        const longhands: []const Longhand = switch (property) {
            .longhand => |l| &.{l},
            .shorthand => |sh| sh.longhands(),
        };
        for (longhands) |l| {
            try out.append(options.allocator, .{ .longhand = l, .value = .{ .value = .{ .pending = pending } } });
            pending.ref();
        }
        return true;
    }
    // Q90: one immutable ordinal table belongs to this source declaration,
    // before shorthand expansion. Backtracking borrows it without mutation.
    var scope = if (functions.numeric_random and options.random_scope == null)
        try @import("random_values.zig").ParseScope.init(options.allocator, text, switch (property) {
            .longhand => |l| l.name(),
            .shorthand => |sh| sh.name(),
        }, .{})
    else
        null;
    defer if (scope) |*owned| owned.deinit();
    var scoped_options = options;
    if (scope) |*owned| scoped_options.random_scope = owned;
    var stream = Stream.init(text);
    const ok = switch (property) {
        .longhand => |l| blk: {
            const value = (try parseLonghand(scoped_options, l, &stream)) orelse break :blk false;
            if (!stream.atEnd()) {
                value.release();
                break :blk false;
            }
            errdefer value.release();
            try out.append(options.allocator, .{ .longhand = l, .value = .{ .value = value } });
            break :blk true;
        },
        .shorthand => |s| try parseShorthand(scoped_options, s, &stream, out),
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

/// Unsupported substitution/functions cannot pass through opaque grammars.
const FunctionFlags = struct { numeric_random: bool = false, random_item: bool = false };

fn containsUnsupportedToken(text: []const u8, content_functions: bool, opaque_image: bool, flags: *FunctionFlags) bool {
    var tok = Tokenizer.init(text);
    var opaque_math = false;
    while (true) {
        const token = tok.next();
        if (token.token_type == .eof) return opaque_math and !flags.random_item;
        // Syntax 3 section 7.2 applies inside nested functions too. Generic
        // declaration serialization must leave these tokens invalid for
        // this property grammar, unlike Fonts' forgiving src components.
        if (token.token_type == .bad_string or token.token_type == .bad_url) return true;
        if (token.token_type == .function and tokenizer_mod.nameEql(token.value, "random")) flags.numeric_random = true;
        if (token.token_type == .function and tokenizer_mod.nameEql(token.value, "random-item")) flags.random_item = true;
        // Q56: the custom-property/env substitution foundation stays
        // unavailable even inside an otherwise accepted pending value.
        if (token.token_type == .function and (tokenizer_mod.nameEql(token.value, "var") or tokenizer_mod.nameEql(token.value, "env"))) return true;
        if (content_functions) continue;
        if (token.token_type != .function) continue;
        if (math_values.isFunction(token)) {
            if (opaque_image) opaque_math = true;
            continue;
        }
        for ([_][]const u8{ "var", "env", "attr", "round", "mod", "rem", "abs", "sign", "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "pow", "sqrt", "hypot", "log", "exp", "progress", "calc-size", "if" }) |f| {
            if (tokenizer_mod.nameEql(token.value, f)) return true;
        }
    }
}

/// A value's tokens, whitespace skipped.
pub const Stream = struct {
    tok: Tokenizer,
    peeked: ?Token = null,
    text: []const u8,
    peeked_offset: usize = 0,

    pub fn init(text: []const u8) Stream {
        return .{ .tok = Tokenizer.init(text), .text = text };
    }

    pub fn peek(self: *Stream) Token {
        if (self.peeked) |t| return t;
        // Syntax3 §4.3.1: comments precede each token. Record the stream
        // position after trivia, before url() drops its function spelling.
        self.tok.skipWhitespace();
        self.peeked_offset = self.tok.pos;
        const t = self.tok.next();
        self.peeked = t;
        return t;
    }

    pub fn next(self: *Stream) Token {
        const t = self.peek();
        self.peeked = null;
        return t;
    }

    pub fn atEnd(self: *Stream) bool {
        return self.peek().token_type == .eof;
    }

    const Mark = struct { tok: Tokenizer, peeked: ?Token, peeked_offset: usize };

    fn mark(self: *const Stream) Mark {
        return .{ .tok = self.tok, .peeked = self.peeked, .peeked_offset = self.peeked_offset };
    }

    fn restore(self: *Stream, m: Mark) void {
        self.tok = m.tok;
        self.peeked = m.peeked;
        self.peeked_offset = m.peeked_offset;
    }

    /// The position of the next token in the text.
    fn offset(self: *Stream) usize {
        _ = self.peek();
        return self.peeked_offset;
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
        .flex_factor => return @import("flex_values.zig").consumeFactor(options, stream),
        .individual_transform => {
            if (takeKeyword(stream, &.{.none})) |keyword| return Value.kw(keyword);
            const transforms = @import("transform_values.zig");
            const kind: transforms.Kind = switch (l) {
                .translate => .translate,
                .rotate => .rotate,
                .scale => .scale,
                else => unreachable,
            };
            return .{ .transform = try transforms.parse(options, stream, kind) orelse return null };
        },
        .animation_list => return .{ .animation_list = try @import("animation_values.zig").List.consume(options, l, stream) orelse return null },
        .grid_tracks => {
            const automatic = l == .grid_auto_columns or l == .grid_auto_rows;
            if (!automatic) if (takeKeyword(stream, &.{.none})) |k| return Value.kw(k);
            return .{ .grid_tracks = try @import("grid_tracks.zig").Tracks.consume(options, stream, if (automatic) .automatic else .template) orelse return null };
        },
        .grid_areas => {
            if (takeKeyword(stream, &.{.none})) |k| return Value.kw(k);
            return .{ .grid_areas = try @import("grid_tracks.zig").Areas.consume(options, stream) orelse return null };
        },
        .grid_flow => return .{ .grid_flow = @import("grid_tracks.zig").Flow.consume(stream) orelse return null },
        .fit_tolerance => {
            // Grid 3 §4.2: normal stays symbolic until layout determines
            // its used value. flow-tolerance is the legacy property alias.
            if (takeKeyword(stream, &.{ .normal, .infinite })) |k| return Value.kw(k);
            return lengthPercentage(options, stream, .{ .negative = false, .quirky = false });
        },
        .caret_color => return @import("ui_values.zig").consumeCaretColor(options, stream),
        .auto_color => return @import("ui_values.zig").consumeAutoColor(options, stream),
        .signed_length => return lengthPercentage(options, stream, .{ .negative = true, .percent = false, .quirky = false }),
        .grid_line => {
            if (takeKeyword(stream, &.{.auto})) |k| return Value.kw(k);
            return .{ .grid_line = try @import("grid_values.zig").Line.consume(options, stream) orelse return null };
        },
        .gap => {
            // Gaps1 §2.1. The new thin/medium/thick extension is a row118
            // Q35 follow-up pending WPT and clarified computed semantics.
            if (takeKeyword(stream, &.{.normal})) |k| return Value.kw(k);
            return lengthPercentage(options, stream, .{ .negative = false, .quirky = false });
        },
        .alignment => return .{ .alignment = @import("alignment.zig").Value.consume(stream, std.meta.stringToEnum(@import("alignment.zig").Mode, @tagName(l)).?) orelse return null },
        .anchor_names, .anchor_scope => {
            if (takeKeyword(stream, &.{.none})) |k| return Value.kw(k);
            if (def.grammar == .anchor_scope) if (takeKeyword(stream, &.{.all})) |k| return Value.kw(k);
            return anchorNames(options, stream, true);
        },
        .position_anchor => {
            if (takeKeyword(stream, &.{ .normal, .none, .auto, .match_parent })) |k| return Value.kw(k);
            return anchorNames(options, stream, false);
        },
        .position_area => {
            if (takeKeyword(stream, &.{.none})) |k| return Value.kw(k);
            return .{ .position_area = @import("position_area.zig").Area.consume(stream) orelse return null };
        },
        .position_try_fallbacks => return positionTryFallbacks(options, stream),
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
            const inset = if (def.logical) |logical| logical.group == .inset else l == .top or l == .right or l == .bottom or l == .left;
            return lengthPercentage(options, stream, .{ .negative = true, .quirky = def.quirky_length, .anchor_position = inset, .anchor_size = true });
        },
        .length_percentage_nonneg => return lengthPercentage(options, stream, .{ .negative = false, .quirky = def.quirky_length }),
        .size, .max_size, .flex_basis => {
            // Anchor Positioning §5 limits anchor-size() to the accepted
            // positioning properties. Flexbox's width-like basis grammar
            // does not give flex-basis that positioning context.
            const allow_anchor_size = def.grammar != .flex_basis;
            if (def.grammar == .flex_basis) if (takeKeyword(stream, &.{.content})) |keyword| return Value.kw(keyword);
            if (takeKeyword(stream, &.{def.initial.keyword})) |k| return Value.kw(k);
            if (takeKeyword(stream, &.{ .min_content, .max_content, .fit_content, .stretch })) |k| return Value.kw(k);
            if (stream.peek().token_type == .function and tokenizer_mod.nameEql(stream.peek().value, "fit-content")) {
                _ = stream.next();
                if (stream.next().token_type != .left_paren) return null;
                const argument = try lengthPercentage(options, stream, .{ .negative = false, .quirky = false, .anchor_size = allow_anchor_size }) orelse return null;
                defer argument.release();
                const end = stream.next().token_type;
                if (end != .right_paren and end != .eof) return null;
                const function = try values.SizingFunction.create(options.allocator, argument);
                argument.retain();
                return .{ .sizing_function = function };
            }
            return lengthPercentage(options, stream, .{ .negative = false, .quirky = def.quirky_length, .anchor_size = allow_anchor_size });
        },
        .line_width => {
            if (takeKeyword(stream, &.{ .thin, .medium, .thick })) |k| return Value.kw(k);
            return lengthPercentage(options, stream, .{ .negative = false, .percent = false, .quirky = def.quirky_length });
        },
        .color => return colorValue(options, stream, def),
        .image => return if (l == .background_image) @import("image_values.zig").parseList(options, l, stream) else imageValue(options, stream),
        .display => return displayValue(stream),
        .text_transform => return textTransformValue(stream),
        .color_scheme => return colorSchemeValue(options, stream),
        .content => {
            if (takeKeyword(stream, &.{ .normal, .none })) |k| return Value.kw(k);
            const generated = @import("generated_content.zig");
            const resolver: ?generated.UrlResolver = if (options.url_resolver) |r| .{ .context = r.context, .resolve = r.resolve } else null;
            const parsed = try generated.parseWithSource(options.allocator, stream.text[stream.offset()..], resolver, options.resource_source) orelse return null;
            while (!stream.atEnd()) _ = stream.next();
            return .{ .content = parsed };
        },
        .font_family => return fontFamilyValue(options, stream),
        .font_size => {
            if (takeKeyword(stream, &.{ .xx_small, .x_small, .small, .medium, .large, .x_large, .xx_large, .xxx_large, .larger, .smaller })) |k| return Value.kw(k);
            return lengthPercentage(options, stream, .{ .negative = false, .quirky = def.quirky_length });
        },
        .font_weight => {
            if (takeKeyword(stream, &.{ .normal, .bold, .bolder, .lighter })) |k| return Value.kw(k);
            const t = stream.peek();
            if (math_values.isFunction(t)) return mathValue(options, stream, .{ .kind = .number, .minimum = 1, .maximum = 1000 });
            if (t.token_type != .number) return null;
            const n = t.numeric_value orelse return null;
            if (n < 1 or n > 1000) return null;
            _ = stream.next();
            return .{ .number = n };
        },
        .letter_spacing => {
            if (takeKeyword(stream, &.{.normal})) |k| return Value.kw(k);
            // Values 4 Appendix C: only a number token gains a px unit;
            // lengthPercentage never applies this quirk inside calc().
            return lengthPercentage(options, stream, .{ .negative = true, .quirky = def.quirky_length });
        },
        .line_height => {
            if (takeKeyword(stream, &.{.normal})) |k| return Value.kw(k);
            const t = stream.peek();
            if (math_values.isFunction(t)) return mathValue(options, stream, .{ .kind = .length_percentage_number, .minimum = 0 });
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
            if (math_values.isFunction(t)) return mathValue(options, stream, .{ .kind = .number_percentage, .minimum = 0, .maximum = 1 });
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
            if (math_values.isFunction(t)) return mathValue(options, stream, .{ .kind = .integer, .minimum = std.math.minInt(i32), .maximum = std.math.maxInt(i32) });
            if (t.token_type != .number or !t.is_integer) return null;
            const n = t.numeric_value orelse return null;
            _ = stream.next();
            const clamped = std.math.clamp(n, @as(f64, std.math.minInt(i32)), @as(f64, std.math.maxInt(i32)));
            return .{ .integer = @intFromFloat(clamped) };
        },
        .cursor => return @import("cursor_values.zig").parse(options, stream),
        .text_indent => return @import("text_indent.zig").parse(options, stream),
        .paint => return @import("svg_paint.zig").parse(options, stream),
        .reference => return @import("svg_paint.zig").parseReference(options, stream),
        .shape => return @import("shape_values.zig").parse(options, stream),
        .filter => return @import("filter_values.zig").parse(options, stream),
        .image_position => return if (try @import("position_values.zig").parse(options, stream, .position)) |position| .{ .image_position = position } else null,
        .mask => return @import("mask_values.zig").parse(options, l, stream),
        .stroke_width => return @import("svg_paint.zig").parseStrokeWidth(options, stream),
    }
}

/// Anchor Position 1 §§2.1–2.2: names remain case-sensitive, including
/// duplicates. Only CSS identifier serialization changes their spelling.
fn anchorNames(options: ParseOptions, stream: *Stream, list: bool) Allocator.Error!?Value {
    const allocator = options.allocator;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    while (true) {
        const name = try @import("anchor_fallbacks.zig").dashedName(allocator, stream) orelse return null;
        defer allocator.free(name);
        const escaped = try serialize_mod.serializeIdentifier(allocator, name);
        defer allocator.free(escaped);
        try out.appendSlice(allocator, escaped);
        if (!list or stream.peek().token_type != .comma) break;
        _ = stream.next();
        try out.appendSlice(allocator, ", ");
    }
    return .{ .text = try SharedText.create(allocator, out.items) };
}

fn positionTryFallbacks(options: ParseOptions, stream: *Stream) Allocator.Error!?Value {
    if (takeKeyword(stream, &.{.none})) |k| return Value.kw(k);
    return .{ .try_fallbacks = .{ .list = try @import("anchor_fallbacks.zig").Fallbacks.parse(options.allocator, stream) orelse return null } };
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
    anchor_position: bool = false,
    anchor_size: bool = false,
};

fn lengthPercentage(options: ParseOptions, stream: *Stream, flags: LengthFlags) Allocator.Error!?Value {
    const t = stream.peek();
    const grammar = math_values.Grammar{
        .kind = if (flags.percent) .length_percentage else .length,
        .minimum = if (flags.negative) -std.math.floatMax(f64) else 0,
        .anchor_position = flags.anchor_position,
        .anchor_size = flags.anchor_size,
    };
    if (math_values.isFunction(t)) return mathValue(options, stream, grammar);
    const value: Length = switch (t.token_type) {
        .dimension => blk: {
            const n = t.numeric_value orelse return null;
            const raw_unit = t.unit orelse return null;
            const unit = LengthUnit.fromString(raw_unit) orelse {
                const extended = math_values.Unit.parse(raw_unit) orelse return null;
                const expression = try math_values.dimension(options.allocator, .{ .value = n, .unit = extended }, grammar) orelse return null;
                _ = stream.next();
                return .{ .calculation = expression };
            };
            break :blk Length.init(n, unit);
        },
        .percentage => blk: {
            if (!flags.percent) return null;
            break :blk Length.percent(t.numeric_value orelse return null);
        },
        .number => blk: {
            const n = t.numeric_value orelse return null;
            if (n == 0) break :blk Length.px(0);
            // SVG2 §4.2 steps 3–4: a presentation attribute admits a
            // number wherever a length occurs, including nested grammars.
            // Q11's browser probe limits this mode to lengths, not angles.
            if (options.svg_presentation) break :blk Length.px(n);
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

pub fn mathValue(options: ParseOptions, stream: *Stream, grammar: math_values.Grammar) Allocator.Error!?Value {
    const begin = stream.offset();
    const parsed = try math_values.parseWithScope(options.allocator, stream.text[begin..], grammar, options.random_scope) orelse return null;
    stream.tok = Tokenizer.init(stream.text);
    stream.tok.pos = begin + parsed.consumed;
    stream.peeked = null;
    return .{ .calculation = parsed.expression };
}

fn colorValue(options: ParseOptions, stream: *Stream, def: *const Info) Allocator.Error!?Value {
    const t = stream.peek();
    if (@import("color_values.zig").isFunction(t)) {
        const color = try @import("color_values.zig").parse(options, stream) orelse return null;
        return .{ .color = color };
    }
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
            return try namedColor(options, t.value, c);
        }
        return .{ .color = .{ .rgba = c } };
    } else |_| {}
    // A <system-color> (CSS Color 4 6.2): kept as the keyword, resolved
    // against the element's used color scheme when it is computed.
    if (t.token_type == .ident) {
        const escaped = std.mem.indexOfScalar(u8, t.value, '\\') != null;
        const decoded = if (escaped) try tokenizer_mod.decode(options.allocator, t.value) else t.value;
        defer if (escaped) options.allocator.free(decoded);
        if (color_mod.SystemColor.parse(decoded)) |system| {
            _ = stream.next();
            return .{ .color = .{ .system = system } };
        }
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

/// Images4: shared typed choices over the unchanged URL/raw leaf grammar.
fn imageValue(options: ParseOptions, stream: *Stream) Allocator.Error!?Value {
    if (takeKeyword(stream, &.{.none})) |k| return Value.kw(k);
    return imageOnly(options, stream);
}

fn imageOnly(options: ParseOptions, stream: *Stream) Allocator.Error!?Value {
    return @import("image_values.zig").parse(options, stream, .{});
}

/// The pre-existing URL and raw gradient parser; no choice is made here.
pub fn parseImageLeaf(options: ParseOptions, stream: *Stream) Allocator.Error!?Value {
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
                const closing = if (s.token_type == .string) stream.next().token_type else s.token_type;
                // Syntax3 §5.5.10: EOF closes the quoted URL function.
                if (s.token_type != .string or (closing != .right_paren and closing != .eof)) {
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
                const shared = try SharedText.create(options.allocator, text);
                errdefer shared.unref();
                shared.resource_urls = try resources.collect(options.allocator, text, options.url_resolver, options.resource_source);
                shared.image_kind = if (std.mem.endsWith(u8, f, "gradient")) .gradient else .other;
                return .{ .text = shared };
            }
            return null;
        },
        else => return null,
    }
}

pub fn urlValue(options: ParseOptions, raw: []const u8) Allocator.Error!Value {
    const resolved: ?[]u8 = if (options.url_resolver) |r| r.resolve(r.context, options.allocator, raw) else null;
    defer if (resolved) |r| options.allocator.free(r);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(options.allocator);
    try out.appendSlice(options.allocator, "url(");
    // Values4 §4.5: keep authored text separate from frozen resolution.
    try values.appendString(raw, &out, options.allocator);
    try out.append(options.allocator, ')');
    const url = values.ResourceUrl.describe(raw, resolved, options.url_resolver != null, options.resource_source, .{ .start = 0, .end = out.items.len });
    const shared = try SharedText.createWithResources(options.allocator, out.items, &.{url});
    shared.image_kind = .url;
    return .{ .text = shared };
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

/// `none | [capitalize | uppercase | lowercase] || full-width ||
/// full-size-kana | math-auto`: each component at most once.
fn textTransformValue(stream: *Stream) ?Value {
    if (takeKeyword(stream, &.{.none}) != null) return .{ .text_transform = .{} };
    if (takeKeyword(stream, &.{.math_auto}) != null) return .{ .text_transform = .{ .math_auto = true } };
    var transform: values.TextTransform = .{};
    var count: usize = 0;
    while (count < 3) : (count += 1) {
        const k = identKeyword(stream.peek()) orelse break;
        switch (k) {
            .capitalize, .uppercase, .lowercase => {
                if (transform.case != .none) return null;
                transform.case = switch (k) {
                    .capitalize => .capitalize,
                    .uppercase => .uppercase,
                    else => .lowercase,
                };
            },
            .full_width => {
                if (transform.full_width) return null;
                transform.full_width = true;
            },
            .full_size_kana => {
                if (transform.full_size_kana) return null;
                transform.full_size_kana = true;
            },
            else => break,
        }
        _ = stream.next();
    }
    if (count == 0) return null;
    return .{ .text_transform = transform };
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
/// CSS Color Adjustment 1 2.2: `normal | [ light | dark | <custom-ident> ]+
/// && only?`. `only` comes first or last (`light only dark` is invalid);
/// normal, only and the <custom-ident> exclusions (CSS Values 4 4.2: the
/// CSS-wide keywords and `default`) are no scheme names. Serialized per
/// grammar: the schemes in order, light and dark lowercase, a custom ident
/// as an identifier with its case, then `only` (Chrome, Firefox and Safari:
/// "only dark light" reads "dark light only").
fn colorSchemeValue(options: ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const allocator = options.allocator;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var support: color_scheme_mod.Support = .{};
    var names: usize = 0;
    var index: usize = 0;
    while (!stream.atEnd()) : (index += 1) {
        const t = stream.peek();
        if (t.token_type != .ident) return null;
        _ = stream.next();
        const decoded = try tokenizer_mod.decode(allocator, t.value);
        defer allocator.free(decoded);
        if (std.ascii.eqlIgnoreCase(decoded, "normal")) {
            // `normal` alone; never one name of several.
            if (index != 0 or !stream.atEnd()) return null;
            return Value.kw(.normal);
        }
        if (std.ascii.eqlIgnoreCase(decoded, "only")) {
            if (support.only) return null;
            support.only = true;
            // Last, after at least one name - or first, before them.
            if (names > 0) {
                if (!stream.atEnd()) return null;
                break;
            }
            continue;
        }
        if (values.CssWide.parse(decoded) != null or std.ascii.eqlIgnoreCase(decoded, "default")) return null;
        if (names > 0) try out.append(allocator, ' ');
        if (std.ascii.eqlIgnoreCase(decoded, "light")) {
            support.add(.light);
            try out.appendSlice(allocator, "light");
        } else if (std.ascii.eqlIgnoreCase(decoded, "dark")) {
            support.add(.dark);
            try out.appendSlice(allocator, "dark");
        } else {
            const ident = try serialize_mod.serializeIdentifier(allocator, decoded);
            defer allocator.free(ident);
            try out.appendSlice(allocator, ident);
        }
        names += 1;
    }
    if (names == 0) return null;
    if (support.only) try out.appendSlice(allocator, " only");
    return .{ .color_scheme = .{ .text = try SharedText.create(allocator, out.items), .support = support } };
}

/// The color scheme support `text` names when it is a valid color-scheme
/// value - `Support.none` for `normal` - or null when it is not one: HTML
/// 4.2.5.1 step 2 for a color-scheme meta's content ("parse a list of
/// component values" given it, then "if parsed is a valid CSS
/// 'color-scheme' property value"). A CSS-wide keyword is no color scheme
/// value there: Firefox 144 and Safari 27.0.1 skip a meta whose content is
/// `inherit` for the next one, Chrome 151 stops at it (lane style4 probe).
pub fn parseColorSchemeSupport(allocator: Allocator, text: []const u8) Allocator.Error!?color_scheme_mod.Support {
    var stream = Stream.init(text);
    const value = (try colorSchemeValue(.{ .allocator = allocator }, &stream)) orelse return null;
    defer value.release();
    if (!stream.atEnd()) return null;
    return switch (value) {
        .color_scheme => |c| c.support,
        else => color_scheme_mod.Support.none,
    };
}

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
        .flex => return @import("flex_values.zig").consumeShorthand(options, stream, out),
        .animation, .animation_range, .transition => return @import("animation_values.zig").consumeShorthand(options, s, stream, out),
        .grid_template, .grid => {
            const ls = s.longhands();
            try out.ensureUnusedCapacity(options.allocator, ls.len);
            const grid_values = @import("grid_tracks.zig");
            if (s == .grid_template) {
                const parsed = try grid_values.consumeTemplate(options, stream) orelse return false;
                if (!stream.atEnd()) {
                    parsed.deinit();
                    return false;
                }
                const components = [_]Value{ parsed.rows, parsed.columns, parsed.areas };
                for (ls, components) |l, v| out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
            } else {
                const parsed = try grid_values.consumeGrid(options, stream) orelse return false;
                if (!stream.atEnd()) {
                    parsed.deinit();
                    return false;
                }
                const components = [_]Value{ parsed.template.rows, parsed.template.columns, parsed.template.areas, .{ .grid_flow = parsed.flow }, parsed.auto_rows, parsed.auto_columns };
                for (ls, components) |l, v| out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
            }
            return true;
        },
        .outline => {
            try out.ensureUnusedCapacity(options.allocator, 3);
            const components = try @import("ui_values.zig").consumeGroup(options, stream, .{ .outline_width, .outline_style, .outline_color }) orelse return false;
            for (s.longhands(), components) |l, v| out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
            return true;
        },
        .grid_area, .grid_column, .grid_row => {
            // Grid 2 §8.4: row-start / column-start / row-end / column-end.
            const grid = @import("grid_values.zig");
            const ls = s.longhands();
            var parsed: [4]Value = undefined;
            var count: usize = 0;
            defer for (parsed[0..count]) |value| value.release();
            while (true) {
                parsed[count] = try parseLonghand(options, ls[count], stream) orelse return false;
                count += 1;
                if (stream.atEnd()) break;
                if (count == ls.len or !grid.slash(stream.next())) return false;
            }
            while (count < ls.len) : (count += 1) {
                const source: usize = if (count == 3) 1 else 0;
                parsed[count] = grid.omitted(parsed[source]);
                parsed[count].retain();
            }
            try out.ensureUnusedCapacity(options.allocator, ls.len);
            for (ls, parsed[0..count]) |l, value| {
                value.retain();
                out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = value } });
            }
            return true;
        },
        .place_content, .place_items, .place_self => {
            // Align3 §§5.2, 6.3, 7.3: consume each whole alignment, then
            // default the second from the first (baseline content → start).
            const ls = s.longhands();
            const first = (try parseLonghand(options, ls[0], stream)) orelse return false;
            const second = if (!stream.atEnd())
                (try parseLonghand(options, ls[1], stream)) orelse return false
            else if (s == .place_content and first.alignment.position == .baseline)
                Value{ .alignment = .{ .position = .start } }
            else
                first;
            if (!stream.atEnd()) return false;
            try out.ensureUnusedCapacity(options.allocator, 2);
            out.appendAssumeCapacity(.{ .longhand = ls[0], .value = .{ .value = first } });
            out.appendAssumeCapacity(.{ .longhand = ls[1], .value = .{ .value = second } });
            return true;
        },
        .position_try => {
            // Anchor Position 1 §6.3: the optional order precedes the list.
            const order = (try parseLonghand(options, .position_try_order, stream)) orelse Value.kw(.normal);
            const fallbacks = (try positionTryFallbacks(options, stream)) orelse return false;
            errdefer fallbacks.release();
            if (!stream.atEnd()) {
                fallbacks.release();
                return false;
            }
            try out.ensureUnusedCapacity(options.allocator, 2);
            out.appendAssumeCapacity(.{ .longhand = .position_try_order, .value = .{ .value = order } });
            out.appendAssumeCapacity(.{ .longhand = .position_try_fallbacks, .value = .{ .value = fallbacks } });
            return true;
        },
        ._webkit_text_orientation => {
            // Chrome accepts vertical-right, Safari mixed, and Firefox
            // does not ship this alias. Use Blink's complete mechanism so
            // the alias can express the initial without accepting mixed.
            // Row118 Q128; Blink WebkitTextOrientation in longhands_custom.cc.
            // https://wpt.fyi/results/css/cssom/cssom-getPropertyValue-common-checks.html
            // This is a shorthand because its grammar differs from the longhand.
            const token = stream.next();
            const word = identKeywordText(token) orelse return false;
            if (!stream.atEnd()) return false;
            const mapped: Keyword = if (std.mem.eql(u8, word.slice(), "vertical-right")) .mixed else blk: {
                const keyword = Keyword.parse(word.slice()) orelse return false;
                break :blk switch (keyword) {
                    .upright, .sideways => keyword,
                    .sideways_right => .sideways,
                    else => return false,
                };
            };
            try append(options, out, .text_orientation, Value.kw(mapped));
            return true;
        },
        // `all` takes only the CSS-wide keywords, handled by the caller.
        .all => return false,
        .margin, .padding, .inset, .border_width, .border_style, .border_color => return fourSides(options, s.longhands(), stream, out),
        .margin_block, .margin_inline, .padding_block, .padding_inline, .inset_block, .inset_inline, .border_block_width, .border_block_style, .border_block_color, .border_inline_width, .border_inline_style, .border_inline_color, .gap => return twoSides(options, s.longhands(), stream, out),
        .border_top, .border_right, .border_bottom, .border_left, .border_block_start, .border_block_end, .border_inline_start, .border_inline_end => {
            const ls = s.longhands();
            return borderSide(options, ls[0], ls[1], ls[2], &.{ls[0]}, &.{ls[1]}, &.{ls[2]}, stream, out);
        },
        .border => {
            if (!try borderSide(options, .border_top_width, .border_top_style, .border_top_color, Shorthand.border_width.longhands(), Shorthand.border_style.longhands(), Shorthand.border_color.longhands(), stream, out)) return false;
            // Backgrounds3 §3.4: border resets the supported border-image
            // components. Its side shorthands do not reset them.
            try append(options, out, .border_image_source, Value.kw(.none));
            return true;
        },
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
        .marker => return @import("svg_paint.zig").parseMarker(options, stream, out),
        .mask => return @import("mask_values.zig").parseShorthand(options, stream, out),
        .mask_border => return @import("mask_values.zig").parseBorder(options, stream, out),
    }
}

/// `<value>{1,4}`: top, right, bottom, left (CSS Box 4 "margin").
fn fourSides(options: ParseOptions, ls: []const Longhand, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    // Reserve before acquiring values: after parsing, transfers cannot fail.
    try out.ensureUnusedCapacity(options.allocator, ls.len);
    var vs: [4]Value = undefined;
    var n: usize = 0;
    errdefer for (vs[0..n]) |v| v.release();
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
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = v } });
    }
    return true;
}

/// `<value>{1,2}`: start, end (CSS Logical 1).
fn twoSides(options: ParseOptions, ls: []const Longhand, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    try out.ensureUnusedCapacity(options.allocator, 2);
    const a = (try parseLonghand(options, ls[0], stream)) orelse return false;
    errdefer a.release();
    if (stream.atEnd()) {
        out.appendAssumeCapacity(.{ .longhand = ls[0], .value = .{ .value = a } });
        a.retain();
        out.appendAssumeCapacity(.{ .longhand = ls[1], .value = .{ .value = a } });
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
    out.appendAssumeCapacity(.{ .longhand = ls[0], .value = .{ .value = a } });
    out.appendAssumeCapacity(.{ .longhand = ls[1], .value = .{ .value = b } });
    return true;
}

/// `<line-width> || <line-style> || <color>` (CSS Backgrounds 3 "border-top"),
/// each omitted one its initial value, set on each of the target longhands.
fn borderSide(options: ParseOptions, width_l: Longhand, style_l: Longhand, color_l: Longhand, widths: []const Longhand, styles: []const Longhand, colors: []const Longhand, stream: *Stream, out: *std.ArrayList(Assignment)) Allocator.Error!bool {
    try out.ensureUnusedCapacity(options.allocator, widths.len + styles.len + colors.len);
    var width: ?Value = null;
    var style: ?Value = null;
    var color: ?Value = null;
    errdefer {
        if (width) |v| v.release();
        if (style) |v| v.release();
        if (color) |v| v.release();
    }
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
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = w } });
    }
    for (styles, 0..) |l, k| {
        if (k > 0) st.retain();
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = st } });
    }
    for (colors, 0..) |l, k| {
        if (k > 0) c.retain();
        out.appendAssumeCapacity(.{ .longhand = l, .value = .{ .value = c } });
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
    var images: std.ArrayList(Value) = .empty;
    defer {
        for (images.items) |image| image.release();
        images.deinit(options.allocator);
    }
    var color: ?Value = null;
    defer if (color) |v| v.release();
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
                const c = try colorValue(options, stream, Longhand.background_color.info());
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
            return false;
        }
        if (components == 0) {
            return false;
        }
        // Q78: preserve the typed image and its candidates through this
        // shorthand, before the full component expansion lands in d1b.
        try images.append(options.allocator, image orelse Value.kw(.none));
        image = null;
        if (stream.peek().token_type == .comma) {
            // Only the final layer may hold a color.
            if (color != null) {
                return false;
            }
            _ = stream.next();
            continue;
        }
        break;
    }
    try out.ensureUnusedCapacity(options.allocator, 2);
    const image_value: Value = if (images.items.len == 1) blk: {
        images.items[0].retain();
        break :blk images.items[0];
    } else .{ .layers = try @import("image_layers.zig").Layers.create(options.allocator, .background_image, images.items) };
    out.appendAssumeCapacity(.{ .longhand = .background_image, .value = .{ .value = image_value } });
    out.appendAssumeCapacity(.{ .longhand = .background_color, .value = .{ .value = color orelse .{ .color = Color.transparent } } });
    color = null;
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
    // Scalar initial sentinels avoid one allocation per untouched style.
    if (l == .object_position and value.isKeyword(.center)) return out.appendSlice(allocator, "50% 50%");
    if (l == .mask_position and value == .length) {
        try values.appendLength(value.length, out, allocator);
        try out.append(allocator, ' ');
        return values.appendLength(value.length, out, allocator);
    }
    switch (value) {
        .keyword => |k| try out.appendSlice(allocator, k.name()),
        .length => |len| try values.appendLength(len, out, allocator),
        .number => |n| {
            try values.appendNumber(n, out, allocator);
            if (l == .animation_delay or l == .transition_duration or l == .transition_delay) try out.append(allocator, 's');
        },
        .integer => |n| try out.print(allocator, "{d}", .{n}),
        .color => |c| try c.serializeSpecified(out, allocator),
        .display => |d| try d.serialize(out, allocator),
        .text_transform => |t| try t.serialize(out, allocator),
        .color_scheme => |c| try out.appendSlice(allocator, c.text.bytes),
        .content => |c| try out.appendSlice(allocator, c.serialization),
        .calculation => |c| try c.serialize(out, allocator),
        .sizing_function => |s| {
            try out.appendSlice(allocator, "fit-content(");
            try serializeValue(l, s.argument, out, allocator);
            try out.append(allocator, ')');
        },
        .grid_line => |line| try line.serialize(out, allocator),
        .grid_tracks => |tracks| try tracks.serialize(out, allocator),
        .grid_areas => |areas| try areas.serialize(out, allocator),
        .grid_flow => |flow| try flow.serialize(out, allocator),
        .caret_pair => |pair| try pair.serialize(out, allocator),
        .animation_list => |list| try list.serialize(out, allocator),
        .transform => |transform| try transform.serialize(out, allocator),
        .alignment => |a| try a.serialize(out, allocator),
        .position_area => |a| try a.serialize(out, allocator),
        .try_fallbacks => |f| try f.list.serialize(f.computed, out, allocator),
        .text => |t| try out.appendSlice(allocator, t.bytes),
        .pending => |pending| if (pending.property == .longhand) try out.appendSlice(allocator, pending.text),
        .cursor => |c| try out.appendSlice(allocator, c.text.bytes),
        .indent => |v| try v.serialize(out, allocator),
        .paint => |v| try v.serialize(out, allocator, null),
        .filter => |v| try out.appendSlice(allocator, v.text.bytes),
        .shape => |v| try v.serialize(out, allocator),
        .image_position => |v| try v.serialize(out, allocator),
        .image_size => |v| try v.serialize(out, allocator),
        .image_quad => |v| try v.serialize(out, allocator),
        .layers => |v| try out.appendSlice(allocator, v.text.bytes),
        .image_keyword => |v| try out.appendSlice(allocator, v.name()),
        .image_repeat => |v| try v.serialize(out, allocator),
        .image => |v| try out.appendSlice(allocator, v.text.bytes),
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
    // Appendix A: only the complete original shorthand can serialize a
    // pending value; mixed/overridden placeholders serialize as empty.
    for (vs) |v| if (v.value == .pending) {
        const pending = v.value.pending;
        if (pending.property != .shorthand or pending.property.shorthand != s) return false;
        for (vs) |other| if (other.value != .pending or other.value.pending != pending) return false;
        try out.appendSlice(allocator, pending.text);
        return true;
    };
    if (s == .all) return false;
    const ls = s.longhands();
    switch (s) {
        .flex => return @import("flex_values.zig").serializeShorthand(vs, out, allocator),
        .animation, .animation_range, .transition => return @import("animation_values.zig").serializeShorthand(s, vs, mode, out, allocator),
        .grid_template => return @import("grid_tracks.zig").serializeTemplate(.{ .rows = vs[0].value, .columns = vs[1].value, .areas = vs[2].value }, out, allocator),
        .grid => return @import("grid_tracks.zig").serializeGrid(.{
            .template = .{ .rows = vs[0].value, .columns = vs[1].value, .areas = vs[2].value },
            .flow = vs[3].value.grid_flow,
            .auto_rows = vs[4].value,
            .auto_columns = vs[5].value,
        }, out, allocator),
        .outline => {
            // UI 4 §3.1 / CSSWG #10611: width, style, color. Safari ships
            // the newer order; omit initial values only for specified CSSOM.
            var wrote = false;
            for (ls, vs) |l, v| {
                if (mode == .specified and v.value.eql(l.info().initial)) continue;
                if (wrote) try out.append(allocator, ' ');
                try serializeValue(l, v.value, out, allocator);
                wrote = true;
            }
            if (!wrote) try out.appendSlice(allocator, "none");
            return true;
        },
        .grid_area, .grid_column, .grid_row => {
            const grid = @import("grid_values.zig");
            var count = ls.len;
            while (count > 1) {
                const source: usize = if (count == 4) 1 else 0;
                if (!vs[count - 1].value.eql(grid.omitted(vs[source].value))) break;
                count -= 1;
            }
            for (ls[0..count], vs[0..count], 0..) |l, v, i| {
                if (i != 0) try out.appendSlice(allocator, " / ");
                try serializeValue(l, v.value, out, allocator);
            }
            return true;
        },
        .position_try => {
            if (!vs[0].value.isKeyword(.normal)) {
                try serializeValue(.position_try_order, vs[0].value, out, allocator);
                try out.append(allocator, ' ');
            }
            try serializeValue(.position_try_fallbacks, vs[1].value, out, allocator);
            return true;
        },
        ._webkit_text_orientation => {
            // Blink's specified and computed alias both map mixed back to
            // vertical-right. The standard longhand still serializes mixed.
            if (vs[0].value.isKeyword(.mixed)) {
                try out.appendSlice(allocator, "vertical-right");
            } else try serializeValue(.text_orientation, vs[0].value, out, allocator);
            return true;
        },
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
        .margin_block, .margin_inline, .padding_block, .padding_inline, .inset_block, .inset_inline, .border_block_width, .border_block_style, .border_block_color, .border_inline_width, .border_inline_style, .border_inline_color, .overflow, .place_content, .place_items, .place_self, .gap => {
            try serializeValue(ls[0], vs[0].value, out, allocator);
            if (!vs[1].value.eql(vs[0].value)) {
                try out.append(allocator, ' ');
                try serializeValue(ls[1], vs[1].value, out, allocator);
            }
            return true;
        },
        .border_top, .border_right, .border_bottom, .border_left, .border_block_start, .border_block_end, .border_inline_start, .border_inline_end => return borderSideText(ls, vs, mode, out, allocator),
        .border, .border_block, .border_inline => {
            // CSSOM §6.7.2: reset-only components must have initial values.
            if (s == .border and !vs[12].value.isKeyword(.none)) return false;
            // Every side must agree: widths, then styles, then colors.
            const sides = if (s == .border) 4 else ls.len / 3;
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
                try @import("resolved_urls.zig").serialize(.background_image, image, out, allocator);
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
        .marker => return @import("svg_paint.zig").serializeMarker(vs, mode, out, allocator),
        .mask => return @import("mask_values.zig").serialize(vs, mode, out, allocator),
        .mask_border => return @import("mask_values.zig").serializeBorder(vs, mode, out, allocator),
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
    try testing.expectEqual(Property{ .shorthand = .animation }, lookup("animation").?);
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
    try expectSerialized("margin-left", "calc(1px + 2px)", "calc(3px)");
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

test "color-scheme: normal, or light, dark and custom idents with only first or last" {
    // css/css-color-adjust/parsing/color-scheme-valid.html; the custom
    // idents keep their case and `only` serializes last (Chrome 151,
    // Firefox 144 and Safari 27 alike, tmp/analysis of lane style4).
    try expectSerialized("color-scheme", "normal", "normal");
    try expectSerialized("color-scheme", "NORMAL", "normal");
    try expectSerialized("color-scheme", "light", "light");
    try expectSerialized("color-scheme", "dark", "dark");
    try expectSerialized("color-scheme", "light dark", "light dark");
    try expectSerialized("color-scheme", "dark light", "dark light");
    try expectSerialized("color-scheme", "only light", "light only");
    try expectSerialized("color-scheme", "light only", "light only");
    try expectSerialized("color-scheme", "light dark only", "light dark only");
    try expectSerialized("color-scheme", "light light", "light light");
    try expectSerialized("color-scheme", "dark dark", "dark dark");
    try expectSerialized("color-scheme", "light purple", "light purple");
    try expectSerialized("color-scheme", "purple dark interesting", "purple dark interesting");
    try expectSerialized("color-scheme", "none", "none");
    try expectSerialized("color-scheme", "light none", "light none");
    try expectSerialized("color-scheme", "only light dark", "light dark only");
    try expectSerialized("color-scheme", "only light light", "light light only");
    try expectSerialized("color-scheme", "only light purple", "light purple only");
    try expectSerialized("color-scheme", "only none", "none only");
    try expectSerialized("color-scheme", "LIGHT Dark ONLY", "light dark only");
    try expectSerialized("color-scheme", "Purple", "Purple");
    try expectSerialized("color-scheme", "\\6c ight", "light");
    try expectSerialized("color-scheme", "  dark  ", "dark");
    // css/css-color-adjust/parsing/color-scheme-invalid.html.
    try expectInvalid("color-scheme", "only normal");
    try expectInvalid("color-scheme", "normal dark");
    try expectInvalid("color-scheme", "normal purple");
    try expectInvalid("color-scheme", "light normal");
    try expectInvalid("color-scheme", "light, dark");
    try expectInvalid("color-scheme", "light inherit");
    try expectInvalid("color-scheme", "light initial");
    try expectInvalid("color-scheme", "light unset");
    try expectInvalid("color-scheme", "light revert");
    try expectInvalid("color-scheme", "light revert-layer");
    try expectInvalid("color-scheme", "default");
    try expectInvalid("color-scheme", "light default");
    try expectInvalid("color-scheme", "only");
    try expectInvalid("color-scheme", "only only");
    try expectInvalid("color-scheme", "light only dark");
    try expectInvalid("color-scheme", "only light only");
    try expectInvalid("color-scheme", "");
    try expectInvalid("color-scheme", "light 1");
    try expectInvalid("color-scheme", "\"light\"");
}

test "a color-scheme meta's content: a whole color-scheme value, CSS-wide keywords not" {
    // HTML 4.2.5.1 step 2.2: "If parsed is a valid CSS 'color-scheme'
    // property value". Chrome 151, Firefox 144 and Safari 27.0.1 alike:
    // whitespace around is fine, `dark !important` is invalid; `inherit`
    // is invalid in Firefox and Safari (Chrome takes it as valid).
    const Case = struct { []const u8, ?color_scheme_mod.Support.First };
    const cases = [_]Case{
        .{ "  dark  ", .dark },
        .{ "light dark", .light },
        .{ "normal", .none },
        .{ "foo", .none },
        .{ "dark !important", null },
        .{ "inherit", null },
        .{ "initial", null },
        .{ "", null },
        .{ ",,invalid", null },
        .{ "light,dark", null },
        .{ "light only dark", null },
    };
    for (cases) |case| {
        const support = try parseColorSchemeSupport(testing.allocator, case[0]);
        if (case[1]) |first| {
            testing.expectEqual(first, support.?.first) catch |err| {
                std.debug.print("{s}\n", .{case[0]});
                return err;
            };
        } else {
            testing.expect(support == null) catch |err| {
                std.debug.print("{s}\n", .{case[0]});
                return err;
            };
        }
    }
}

test "color-scheme names the color scheme support its schemes make" {
    const Case = struct { text: []const u8, first: color_scheme_mod.Support.First, light: bool, dark: bool, only: bool };
    const cases = [_]Case{
        .{ .text = "dark", .first = .dark, .light = false, .dark = true, .only = false },
        .{ .text = "purple light dark", .first = .light, .light = true, .dark = true, .only = false },
        .{ .text = "only dark light", .first = .dark, .light = true, .dark = true, .only = true },
        .{ .text = "purple", .first = .none, .light = false, .dark = false, .only = false },
        .{ .text = "none only", .first = .none, .light = false, .dark = false, .only = true },
    };
    for (cases) |case| {
        var list: std.ArrayList(Assignment) = .empty;
        defer freeAssignments(&list);
        try testing.expect(try parseText("color-scheme", case.text, &list));
        const support = list.items[0].value.value.color_scheme.support;
        try testing.expectEqual(case.first, support.first);
        try testing.expectEqual(case.light, support.light);
        try testing.expectEqual(case.dark, support.dark);
        try testing.expectEqual(case.only, support.only);
    }
    var list: std.ArrayList(Assignment) = .empty;
    defer freeAssignments(&list);
    try testing.expect(try parseText("color-scheme", "normal", &list));
    try testing.expect(list.items[0].value.value.isKeyword(.normal));
}

test "text-transform: a case keyword, full-width and full-size-kana in any order, or math-auto" {
    // css/css-text/parsing/text-transform-valid.html and -invalid.html.
    try expectSerialized("text-transform", "none", "none");
    try expectSerialized("text-transform", "UPPERCASE", "uppercase");
    try expectSerialized("text-transform", "full-width", "full-width");
    try expectSerialized("text-transform", "full-size-kana", "full-size-kana");
    try expectSerialized("text-transform", "math-auto", "math-auto");
    try expectSerialized("text-transform", "full-width lowercase", "lowercase full-width");
    try expectSerialized("text-transform", "full-size-kana full-width", "full-width full-size-kana");
    try expectSerialized("text-transform", "full-size-kana full-width capitalize", "capitalize full-width full-size-kana");
    try expectInvalid("text-transform", "none full-width");
    try expectInvalid("text-transform", "capitalize none");
    try expectInvalid("text-transform", "capitalize full-width lowercase");
    try expectInvalid("text-transform", "full-width full-size-kana full-width");
    try expectInvalid("text-transform", "math-auto uppercase");
    try expectInvalid("text-transform", "uppercase math-auto");
    try expectInvalid("text-transform", "full-width math-auto");
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

test "CSSOM enumeration sorts names independently of property blocks" {
    var seen = [_]bool{false} ** Longhand.count;
    for (lexicographic, 0..) |l, i| {
        try testing.expect(!seen[@intFromEnum(l)]);
        seen[@intFromEnum(l)] = true;
        if (i > 0) try testing.expect(std.mem.lessThan(u8, lexicographic[i - 1].name(), l.name()));
    }
    for (seen) |present| try testing.expect(present);
    try testing.expectEqualStrings("z-index", lexicographic[Longhand.count - 1].name());
}

test "cursor sorts between content and direction" {
    const cursor_index = std.mem.indexOfScalar(Longhand, &lexicographic, .cursor).?;
    try testing.expect(cursor_index > std.mem.indexOfScalar(Longhand, &lexicographic, .content).?);
    try testing.expect(cursor_index < std.mem.indexOfScalar(Longhand, &lexicographic, .direction).?);
}

test "ci1 stream offsets retain token starts across peek and mark restore" {
    const text = "  /* prefix */url( a.svg )  counter(item)";
    var stream = Stream.init(text);
    const before_peek = stream.mark();
    try testing.expectEqual(tokenizer_mod.TokenType.url, stream.peek().token_type);
    try testing.expectEqual(std.mem.indexOf(u8, text, "url(").?, stream.offset());
    const with_peek = stream.mark();
    _ = stream.next();
    try testing.expectEqual(tokenizer_mod.TokenType.function, stream.peek().token_type);
    try testing.expectEqual(std.mem.indexOf(u8, text, "counter").?, stream.offset());
    stream.restore(with_peek);
    try testing.expectEqual(tokenizer_mod.TokenType.url, stream.peek().token_type);
    try testing.expectEqual(std.mem.indexOf(u8, text, "url(").?, stream.offset());
    stream.restore(before_peek);
    try testing.expectEqual(std.mem.indexOf(u8, text, "url(").?, stream.offset());
    while (!stream.atEnd()) _ = stream.next();
    try testing.expectEqual(text.len, stream.offset());
    const at_end = stream.mark();
    _ = stream.next();
    stream.restore(at_end);
    try testing.expectEqual(text.len, stream.offset());
}

test "ci1 stream offsets locate quoted escaped padded and mixed URL tokens" {
    for ([_][]const u8{ "url('a.svg')", "u\\72 l(a.svg)", "url( \ta.svg\n)" }) |text| {
        var stream = Stream.init(text);
        _ = stream.peek();
        try testing.expectEqual(@as(usize, 0), stream.offset());
    }
    const text = "\"prefix\" url(a.svg)";
    var stream = Stream.init(text);
    try testing.expectEqual(tokenizer_mod.TokenType.string, stream.next().token_type);
    try testing.expectEqual(std.mem.indexOf(u8, text, "url(").?, stream.offset());
    try testing.expectEqual(tokenizer_mod.TokenType.url, stream.next().token_type);
    try testing.expectEqual(text.len, stream.offset());
}
