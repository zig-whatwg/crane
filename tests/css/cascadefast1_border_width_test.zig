//! CSS Backgrounds 3 §3.3 border-width: the computed value is the absolute
//! length, snapped as a border width, whatever the border style; initial
//! `medium`. Only the resolved value (CSSOM §9, getComputedStyle) is zero
//! for a side whose style is none or hidden, so a child inheriting the
//! width gets the length. Chrome 156, Firefox 158 and Safari 27 pass
//! css/css-backgrounds/border-width-computed.html 6/6 (wpt.fyi); Gecko keeps
//! nsStyleBorder::mBorder (the length) apart from mComputedBorder (zeroed).
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const cascade = css.cascade.cascade;
const Longhand = css.properties.Longhand;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;

fn styleOf(parent: ?*const ComputedStyle, text: []const u8) !*ComputedStyle {
    var block = try DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    return cascade(.{ .allocator = testing.allocator, .parent = parent, .is_root = parent == null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn expectResolved(style: *const ComputedStyle, l: Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("{s}\n", .{l.name()});
        return err;
    };
}

test "a drawn border with no width takes medium" {
    const style = try styleOf(null, "border-top-style: solid; border-left-style: double; border-inline-end-style: dotted");
    defer style.destroy();
    try expectResolved(style, .border_top_width, "3px");
    try expectResolved(style, .border_left_width, "3px");
    // ltr horizontal: inline-end is the right side.
    try expectResolved(style, .border_right_width, "3px");
    try expectResolved(style, .border_inline_end_width, "3px");
    try expectResolved(style, .border_bottom_width, "0px");
    try expectResolved(style, .border_block_end_width, "0px");
}

test "the computed width stays the length; only the resolved value is zero" {
    const style = try styleOf(null, "");
    defer style.destroy();
    for ([_]Longhand{ .border_top_width, .border_right_width, .border_bottom_width, .border_left_width, .border_block_start_width, .border_inline_end_width }) |l| {
        try testing.expectEqual(@as(f64, 3), style.get(l).length.value);
        try expectResolved(style, l, "0px");
    }
    const hidden = try styleOf(null, "border-style: hidden; border-width: 5px");
    defer hidden.destroy();
    try testing.expectEqual(@as(f64, 5), hidden.get(.border_top_width).length.value);
    try expectResolved(hidden, .border_top_width, "0px");
    try expectResolved(hidden, .border_inline_start_width, "0px");
}

test "a child inherits the length its parent does not draw" {
    const parent = try styleOf(null, "border-top: 5px none");
    defer parent.destroy();
    try expectResolved(parent, .border_top_width, "0px");
    const child = try styleOf(parent, "border-top-style: solid; border-top-width: inherit");
    defer child.destroy();
    try expectResolved(child, .border_top_width, "5px");
    const keyword_parent = try styleOf(null, "border-top: thick hidden");
    defer keyword_parent.destroy();
    const keyword_child = try styleOf(keyword_parent, "border-top-style: solid; border-top-width: inherit");
    defer keyword_child.destroy();
    try expectResolved(keyword_child, .border_top_width, "5px");
    // Its own style none: the inherited width resolves to zero again.
    const undrawn = try styleOf(parent, "border-top-width: inherit");
    defer undrawn.destroy();
    try expectResolved(undrawn, .border_top_width, "0px");
    try testing.expectEqual(@as(f64, 5), undrawn.get(.border_top_width).length.value);
}

test "a logical width resolves against its mapped side's style" {
    const style = try styleOf(null, "direction: rtl; border-inline-start: 4px solid; border-left-width: 7px");
    defer style.destroy();
    // rtl: inline-start is the right side, drawn; the left is not.
    try expectResolved(style, .border_inline_start_width, "4px");
    try expectResolved(style, .border_right_width, "4px");
    try expectResolved(style, .border_left_width, "0px");
    try expectResolved(style, .border_inline_end_width, "0px");
}

test "the initial style resolves every border width to zero" {
    const style = try ComputedStyle.initial(testing.allocator);
    defer style.destroy();
    try expectResolved(style, .border_top_width, "0px");
    try testing.expectEqual(@as(f64, 3), style.get(.border_top_width).length.value);
}
