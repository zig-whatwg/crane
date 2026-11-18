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

test "a highlight copies font and line-height from its originating element, ignoring its own" {
    // CSS Pseudo 4 §3.6 (csswg#7591): what the applicable properties need to
    // resolve - font-size and the other font properties (em and the other
    // font-relative lengths), line-height (lh), color-scheme - is copied from
    // the originating element, "ignoring any values specified on the
    // highlight pseudo-element itself" (WPT highlight-cascade-007.html).
    const root = try styleOf(null, "font-size: 12px; line-height: 13px", false, null);
    defer root.destroy();
    const root_selection = try styleOf(root, "font-size: 42px; line-height: 43px; font-family: monospace; text-shadow: green 1em 0", true, null);
    defer root_selection.destroy();
    try expectValue(root_selection, .font_size, "12px");
    try expectValue(root_selection, .line_height, "13px");
    try expectValue(root_selection, .text_shadow, "rgb(0, 128, 0) 12px 0px 0px");
    const child = try styleOf(root, "font-size: 18px; line-height: 19px; font-family: serif", false, null);
    defer child.destroy();
    const child_selection = try styleOf(child, "text-decoration-thickness: 1em; font-size: inherit", true, root_selection);
    defer child_selection.destroy();
    try expectValue(child_selection, .font_size, "18px");
    try expectValue(child_selection, .line_height, "19px");
    try expectValue(child_selection, .font_family, "serif");
    // The parent highlight's text-shadow is inherited as computed there.
    try expectValue(child_selection, .text_shadow, "rgb(0, 128, 0) 12px 0px 0px");
    try expectValue(child_selection, .text_decoration_thickness, "18px");
}
