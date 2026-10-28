//! Which group of a ComputedStyle each longhand's computed value lives in
//! (comptime metadata; the storage itself is computed_style.zig).
//!
//! An element's computed style is a few group pointers, not one slot per
//! longhand: a group no declaration of the element touches is shared - an
//! inherited group with the parent's style, a non-inherited one with the
//! initial values - and only a group the cascade writes a different value
//! into is copied (copy on write). So a longhand costs an element only when
//! the element, or the ancestor it inherits from, writes into its group.
//! The engines' design: Blink's ComputedStyleBase groups (DataRef, then
//! Member groups; make_computed_style_base.py), WebKit's RenderStyle DataRef
//! groups (StyleNonInheritedData, StyleInheritedData, ...), Stylo's style
//! structs shared by Arc (StyleStructRef Borrowed -> Owned).
//!
//! The rules, all checked at comptime:
//! - A group is all inherited or all non-inherited (as in all three: only
//!   then can an untouched group be shared whole with the parent's style or
//!   with the initial values).
//! - Logical longhands have no storage: ComputedStyle.get answers one with
//!   the physical longhand it maps to for the element's writing mode and
//!   direction, which is what the cascade's mapping stores.
//! - The hot groups below are the properties elements commonly set (the
//!   UA sheet's display, margins, fonts, colors; author boxes, borders and
//!   backgrounds). Every other longhand goes to a "rare" group of its
//!   inheritance, in chunks of at most `chunk` in Longhand order (Blink's
//!   field_group "*", split into leaf groups of 16: _evaluate_misc_group).
//!   A NEW longhand lands in a rare chunk unless it is listed here, so it
//!   costs no element that writes nothing into that chunk.
//! - A group holds at most `chunk` values, so a group with its header
//!   (computed_style.Group, 24 B) is at most 504 B: one 512 B size class.

const std = @import("std");
const properties = @import("properties.zig");
const Longhand = properties.Longhand;

/// The most values in one group.
pub const chunk = 15;

const Hot = struct { name: []const u8, inherited: bool, members: []const Longhand };

const hot = [_]Hot{
    .{ .name = "font", .inherited = true, .members = &.{
        .font_family,         .font_size,         .font_style,             .font_weight,           .font_width,
        .line_height,         .font_size_adjust,  .font_kerning,           .font_feature_settings, .font_variation_settings,
        .font_optical_sizing, .font_variant_caps, .font_variant_ligatures, .font_variant_numeric,  .font_variant_east_asian,
    } },
    .{ .name = "text", .inherited = true, .members = &.{
        .color,          .color_scheme, .direction,            .writing_mode,   .text_orientation,
        .visibility,     .cursor,       .text_align,           .text_transform, .text_indent,
        .letter_spacing, .word_spacing, .white_space_collapse, .text_wrap_mode, .interactivity,
    } },
    .{ .name = "box", .inherited = false, .members = &.{
        .display,    .position,   .float,        .z_index,     .box_sizing,
        .overflow_x, .overflow_y, .unicode_bidi, .contain,     .content_visibility,
        .appearance, .opacity,    .content,      .user_select, .resize,
    } },
    .{ .name = "surround", .inherited = false, .members = &.{
        .margin_top,  .margin_right,  .margin_bottom,  .margin_left,
        .padding_top, .padding_right, .padding_bottom, .padding_left,
        .top,         .right,         .bottom,         .left,
    } },
    .{ .name = "border", .inherited = false, .members = &.{
        .border_top_width,    .border_top_style,    .border_top_color,
        .border_right_width,  .border_right_style,  .border_right_color,
        .border_bottom_width, .border_bottom_style, .border_bottom_color,
        .border_left_width,   .border_left_style,   .border_left_color,
    } },
    .{ .name = "size", .inherited = false, .members = &.{ .width, .height, .min_width, .min_height, .max_width, .max_height } },
    .{ .name = "background", .inherited = false, .members = &.{
        .background_color,  .background_image,      .background_position_x, .background_position_y, .background_size,
        .background_repeat, .background_attachment, .background_origin,     .background_clip,
    } },
    .{ .name = "flex", .inherited = false, .members = &.{
        .align_content, .align_items, .align_self, .justify_content, .justify_items, .justify_self,
        .flex_grow,     .flex_shrink, .flex_basis, .row_gap,         .column_gap,
    } },
};

/// Where a longhand's value lives: groups[group][index]. Logical longhands
/// have none (`stored` false).
pub const Location = struct { group: u8 = 0, index: u8 = 0, stored: bool = false };

const Layout = struct {
    count: usize,
    location: [Longhand.count]Location,
    lengths: [Longhand.count]u8,
    inherited: [Longhand.count]bool,
    names: [Longhand.count][]const u8,
};

const layout: Layout = blk: {
    @setEvalBranchQuota(200_000);
    var out: Layout = .{ .count = 0, .location = @splat(.{}), .lengths = @splat(0), .inherited = @splat(false), .names = @splat("") };
    var placed: [Longhand.count]bool = @splat(false);
    for (hot) |h| {
        if (h.members.len > chunk) @compileError("group " ++ h.name ++ " holds more than chunk values");
        const g = out.count;
        out.count += 1;
        out.inherited[g] = h.inherited;
        out.names[g] = h.name;
        for (h.members) |l| {
            if (l.logical() != null) @compileError(l.name() ++ " is logical: it has no storage");
            if (l.inherited() != h.inherited) @compileError(l.name() ++ " does not share group " ++ h.name ++ "'s inheritance");
            if (placed[@intFromEnum(l)]) @compileError(l.name() ++ " is in two groups");
            placed[@intFromEnum(l)] = true;
            out.location[@intFromEnum(l)] = .{ .group = g, .index = out.lengths[g], .stored = true };
            out.lengths[g] += 1;
        }
    }
    // The rare chunks, inherited then non-inherited, in Longhand order.
    for ([_]bool{ true, false }) |inheriting| {
        var g: ?usize = null;
        for (0..Longhand.count) |i| {
            const l: Longhand = @enumFromInt(i);
            if (placed[i] or l.logical() != null or l.inherited() != inheriting) continue;
            if (g == null or out.lengths[g.?] == chunk) {
                g = out.count;
                out.count += 1;
                out.inherited[g.?] = inheriting;
                out.names[g.?] = if (inheriting) "rare inherited" else "rare";
            }
            placed[i] = true;
            out.location[i] = .{ .group = g.?, .index = out.lengths[g.?], .stored = true };
            out.lengths[g.?] += 1;
        }
    }
    if (out.count > 64) @compileError("more groups than ComputedStyle's held mask");
    break :blk out;
};

/// The number of groups.
pub const count = layout.count;

/// Each longhand's location.
pub const location = layout.location;

/// Each group's number of values.
pub const lengths: [count]u8 = layout.lengths[0..count].*;

/// Whether each group's values are inherited ones.
pub const inherited: [count]bool = layout.inherited[0..count].*;

/// Each group's name (a hot group's, or "rare"/"rare inherited").
pub const names: [count][]const u8 = layout.names[0..count].*;

/// The longhands of group `g`, in index order.
pub fn members(comptime g: usize) [lengths[g]]Longhand {
    comptime {
        @setEvalBranchQuota(100_000);
        var out: [lengths[g]]Longhand = undefined;
        for (0..Longhand.count) |i| {
            const loc = location[i];
            if (loc.stored and loc.group == g) out[loc.index] = @enumFromInt(i);
        }
        return out;
    }
}

/// The offset of group g's first value in a flat array of every group's
/// values in group order (computed_style's initial values).
pub const offsets: [count]usize = blk: {
    var out: [count]usize = undefined;
    var at: usize = 0;
    for (0..count) |g| {
        out[g] = at;
        at += lengths[g];
    }
    break :blk out;
};

/// The number of stored (non-logical) longhands.
pub const stored = offsets[count - 1] + lengths[count - 1];

test "every non-logical longhand is stored once, in a group of its own inheritance" {
    var seen: [count][chunk]bool = @splat(@splat(false));
    for (0..Longhand.count) |i| {
        const l: Longhand = @enumFromInt(i);
        const loc = location[i];
        try std.testing.expectEqual(l.logical() == null, loc.stored);
        if (!loc.stored) continue;
        try std.testing.expect(loc.group < count);
        try std.testing.expect(loc.index < lengths[loc.group]);
        try std.testing.expectEqual(l.inherited(), inherited[loc.group]);
        try std.testing.expect(!seen[loc.group][loc.index]);
        seen[loc.group][loc.index] = true;
    }
    for (0..count) |g| for (0..lengths[g]) |k| try std.testing.expect(seen[g][k]);
}
