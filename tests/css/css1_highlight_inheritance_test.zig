//! Lane css1: CSS Pseudo 4 §3.5 highlight inheritance in the cascade - a
//! highlight pseudo-element's properties, inherited or not, take the
//! parent's highlight's value when the cascade gives them none (or inherit /
//! unset), and at the root color is the originating element's.
//! WPT css/css-pseudo/highlight-cascade/highlight-pseudos-inheritance-
//! computed-001.html and highlight-currentcolor-computed-inheritance.html.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;
const Style = css.computed_style.ComputedStyle;

fn styleOf(parent: ?*const Style, text: []const u8, highlight: bool, highlight_parent: ?*const Style) !*Style {
    var block = try Block.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(.{
        .allocator = testing.allocator,
        .parent = parent,
        .pseudo = if (highlight) "selection" else null,
        .highlight = highlight,
        .highlight_parent = highlight_parent,
    }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn expectValue(style: *const Style, longhand: css.properties.Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(longhand, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "a highlight inherits non-inherited properties from the parent's highlight" {
    const root = try styleOf(null, "color: lime", false, null);
    defer root.destroy();
    const root_selection = try styleOf(root, "background-color: green; color: lime", true, null);
    defer root_selection.destroy();
    const child = try styleOf(root, "", false, null);
    defer child.destroy();
    const child_selection = try styleOf(child, "", true, root_selection);
    defer child_selection.destroy();
    // background-color is not an inherited property, and still inherits.
    try expectValue(child_selection, .background_color, "rgb(0, 128, 0)");
    try expectValue(child_selection, .color, "rgb(0, 255, 0)");
    // unset inherits too.
    const unset = try styleOf(child, "background-color: unset", true, root_selection);
    defer unset.destroy();
    try expectValue(unset, .background_color, "rgb(0, 128, 0)");
}

test "at the root, a highlight's color is the originating element's; the rest initial" {
    const root = try styleOf(null, "color: rgb(1, 2, 3); background-color: red", false, null);
    defer root.destroy();
    const selection = try styleOf(root, "", true, null);
    defer selection.destroy();
    try expectValue(selection, .color, "rgb(1, 2, 3)");
    try expectValue(selection, .background_color, "rgba(0, 0, 0, 0)");
}

test "an ordinary pseudo-element still inherits only inherited properties" {
    const root = try styleOf(null, "background-color: green", false, null);
    defer root.destroy();
    const child = try styleOf(root, "", false, null);
    defer child.destroy();
    try expectValue(child, .background_color, "rgba(0, 0, 0, 0)");
}

test "currentColor down the highlight chain is each originating element's color" {
    // The root highlight's color is currentColor; a child's highlight with no
    // color inherits currentColor, so it is the child's own color.
    const root = try styleOf(null, "color: black", false, null);
    defer root.destroy();
    const root_selection = try styleOf(root, "", true, null);
    defer root_selection.destroy();
    const link = try styleOf(root, "color: lime", false, null);
    defer link.destroy();
    const link_selection = try styleOf(link, "", true, root_selection);
    defer link_selection.destroy();
    try expectValue(link_selection, .color, "rgb(0, 255, 0)");
    // A concrete color is inherited as that color.
    const blue_selection = try styleOf(root, "color: blue", true, null);
    defer blue_selection.destroy();
    const child_selection = try styleOf(link, "", true, blue_selection);
    defer child_selection.destroy();
    try expectValue(child_selection, .color, "rgb(0, 0, 255)");
    // A declared currentcolor is the originating element's, and inherited as
    // currentColor too.
    const current_selection = try styleOf(link, "color: currentcolor", true, blue_selection);
    defer current_selection.destroy();
    try expectValue(current_selection, .color, "rgb(0, 255, 0)");
    const grandchild = try styleOf(root, "color: rgb(1, 2, 3)", false, null);
    defer grandchild.destroy();
    const grandchild_selection = try styleOf(grandchild, "", true, current_selection);
    defer grandchild_selection.destroy();
    try expectValue(grandchild_selection, .color, "rgb(1, 2, 3)");
}
