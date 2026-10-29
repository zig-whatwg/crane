//! Typed OM §5: recognize singleton shapes from retained native fields.
//! Integrator Q60's property-specific rulings and singleton principle.
const std = @import("std");
const properties = @import("../properties.zig");
const values = @import("../style_values.zig");
const math = @import("../math_values.zig");
const native = @import("native_values.zig");
const numeric = @import("numeric.zig");
const Value = values.Value;
const Longhand = properties.Longhand;

pub const Shape = union(enum) {
    keyword: []const u8,
    /// Native fields prove one keyword; use the owning serializer for its
    /// spelling. The result is never tokenized to discover its shape.
    canonical_keyword: Value,
    numeric: math.Numeric,
    calculation: *math.Expression,
    pending: *@import("../pending_values.zig").Pending,
    text_keywords: []const u8,
    image,
    unsupported,
};

fn bits(values_to_count: anytype) usize {
    var count: usize = 0;
    inline for (values_to_count) |bit| count += @intFromBool(bit);
    return count;
}

fn repeatedArea(keyword: anytype) bool {
    return switch (keyword) {
        .center,
        .span_all,
        .start,
        .end,
        .span_start,
        .span_end,
        .self_start,
        .self_end,
        .span_self_start,
        .span_self_end,
        => true,
        else => false,
    };
}

/// Borrow the one URL image proved by its native tag. Q87: gradients,
/// image-set and light-dark remain opaque until ordinary computation selects
/// a URL. A one-item Content keeps ownership of its image and provenance.
pub fn urlImage(value: Value) ?Value {
    const image = if (value == .content) blk: {
        const content = value.content;
        if (content.alternate != null or content.items.len != 1) return null;
        const item = content.items[0];
        if (item.kind != .image) return null;
        break :blk item.image orelse return null;
    } else value;
    return if (image == .text and image.text.image_kind == .url) image else null;
}

pub fn shape(longhand: Longhand, value: Value) Shape {
    // Q194 / Typed OM §5: initial sentinels must reify like parsed values.
    // These owners serialize their scalar/keyword initials as two-component
    // positions. Q32 keeps the position class opaque and property-associated;
    // §5.3 pending values still take precedence over ordinary reification.
    if ((longhand == .mask_position or longhand == .object_position) and value != .pending)
        return .unsupported;
    if (native.numericLeaf(longhand, value)) |number| return .{ .numeric = number };
    return switch (value) {
        .keyword => |keyword| .{ .keyword = keyword.name() },
        .calculation => |expression| .{ .calculation = expression },
        .pending => |pending| .{ .pending = pending },
        .color => |color| if (color == .current) .{ .keyword = "currentcolor" } else .unsupported,
        .alignment => |alignment| if (alignment.modifier == null) .{ .keyword = alignment.position.name() } else .unsupported,
        .font_width_keyword => |keyword| .{ .keyword = keyword.name() },
        .font_system => |keyword| .{ .keyword = keyword.name() },
        .display => |display| blk: {
            if (display.box != .normal) break :blk .{ .canonical_keyword = value };
            if (display.list_item) break :blk if (display.outer == .block and display.inner == .flow) .{ .keyword = "list-item" } else .unsupported;
            const single = switch (display.outer) {
                .inline_ => true,
                .block => display.inner != .ruby and display.inner != .math,
                .run_in => display.inner == .flow,
            };
            break :blk if (single) .{ .canonical_keyword = value } else .unsupported;
        },
        .text_transform => |transform| if (transform.math_auto or bits(.{ transform.case != .none, transform.full_width, transform.full_size_kana }) <= 1) .{ .canonical_keyword = value } else .unsupported,
        .grid_line => |line| if (line.isCustomIdent()) .{ .keyword = line.name } else .unsupported, // Q60: integer/span stay Style.
        .grid_flow => |flow| if (!flow.column or !flow.dense) .{ .canonical_keyword = value } else .unsupported,
        .containment => |contain| if (contain.spelling != .components or bits(.{ contain.size != .none, contain.layout, contain.style, contain.paint }) <= 1) .{ .canonical_keyword = value } else .unsupported,
        .position_visibility => |visibility| if (bits(.{ visibility.anchor_valid, visibility.anchor_visible, visibility.no_overflow }) <= 1) .{ .canonical_keyword = value } else .unsupported,
        .position_area => |area| if (area.first == area.second or (area.first == .span_all and !repeatedArea(area.second)) or (area.second == .span_all and !repeatedArea(area.first))) .{ .canonical_keyword = value } else .unsupported,
        .decoration_keywords => |keywords| if (keywords.count == 1) .{ .keyword = keywords.items[0].name() } else .unsupported,
        .corner_radius => |corner| blk: {
            const axes = corner.axes();
            break :blk if (axes[0].eql(axes[1])) shape(longhand, axes[0]) else .unsupported;
        },
        .image_keyword => |keyword| if (keyword == .border_area_text) .unsupported else .{ .keyword = keyword.name() },
        .image_repeat => |repeat| if (repeat.x == repeat.y or (!repeat.border and ((repeat.x == .repeat and repeat.y == .no_repeat) or (repeat.x == .no_repeat and repeat.y == .repeat)))) .{ .canonical_keyword = value } else .unsupported,
        .image_size => |size| if (size.axes[0].isKeyword(.auto) and size.axes[1].isKeyword(.auto)) .{ .keyword = "auto" } else .unsupported, // Q62: numeric/auto serializes as two components in both shippers.
        .image_quad => |quad| blk: {
            if (quad.fill) break :blk .unsupported;
            for (quad.sides[1..]) |side| if (!side.eql(quad.sides[0])) break :blk .unsupported;
            break :blk shape(longhand, quad.sides[0]);
        },
        .image_resolution => |resolution| blk: {
            if (resolution == .initial) break :blk .{ .numeric = .{ .value = 1, .unit = .dppx } };
            const descriptor = resolution.owned;
            if (descriptor.snap) break :blk .unsupported;
            if (descriptor.from_image) break :blk if (descriptor.resolution == null) .{ .keyword = "from-image" } else .unsupported;
            const component = descriptor.resolution orelse break :blk .unsupported;
            break :blk switch (component) {
                .literal => |literal| .{ .numeric = .{ .value = literal.number, .unit = numeric.parseUnit(@tagName(literal.unit)).? } },
                .math => |operand| shape(longhand, operand),
            };
        },
        .indent => |indent| if (!indent.flags.hanging and !indent.flags.each_line) shape(longhand, indent.offset) else .unsupported,
        .font_size_adjust => |adjust| if (adjust.metric == .ex_height) (if (adjust.aspect) |aspect| shape(longhand, aspect) else .{ .keyword = "from-font" }) else .unsupported,
        .text_values => |components| blk: {
            if (components.items.len == 1) break :blk shape(longhand, components.items[0]);
            if (longhand == .hyphenate_limit_chars and components.items.len == 3 and components.items[1].isKeyword(.auto) and components.items[2].isKeyword(.auto)) break :blk shape(longhand, components.items[0]);
            if (longhand == .text_decoration_inset and components.items.len == 2 and components.items[0].eql(components.items[1])) break :blk shape(longhand, components.items[0]);
            break :blk .unsupported;
        },
        .shape => |outline| if (outline.data == .box and outline.box != null) .{ .keyword = outline.box.?.name() } else .unsupported,
        .grid_tracks => |tracks| blk: {
            if (tracks.subgrid) break :blk if (tracks.items.len == 0) .{ .keyword = "subgrid" } else .unsupported;
            if (tracks.items.len != 1 or tracks.items[0] != .track or tracks.items[0].track != .breadth) break :blk .unsupported;
            break :blk switch (tracks.items[0].track.breadth) {
                .intrinsic => |keyword| .{ .keyword = switch (keyword) {
                    .auto => "auto",
                    .min_content => "min-content",
                    .max_content => "max-content",
                } },
                .numeric => |number| switch (number.scalar) {
                    .numeric => |n| .{ .numeric = n },
                    .calculation => |expression| .{ .calculation = expression },
                },
            };
        },
        .image => .unsupported,
        .content => if (urlImage(value) != null) .image else .unsupported,
        .color_scheme => |scheme| .{ .text_keywords = scheme.text.bytes }, // Q63 named cold-text exception.
        .text => |text| if (text.image_kind == .url) .image else if (text.image_kind == .generic) .{ .text_keywords = text.bytes } else .unsupported,
        // Q32: transform/position subclasses are routed. These retain native
        // data as KNOWN-INCOMPLETE until that family lands, never a fake API.
        // font-family is always opaque by §5.1, even a lone generic family.
        else => .unsupported,
    };
}
