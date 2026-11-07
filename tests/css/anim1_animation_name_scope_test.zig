//! CSS Scoping 1 tree-scoped references: a computed animation-name keeps the
//! tree scope of the declaration that won the cascade, as font-family's named
//! families do (css.font_family), so the style engine looks its @keyframes up
//! from the tree of the sheet that declared it (Blink ScopedCSSName, WebKit
//! nameStyleScopeOrdinal). Serialization ignores the scope; equality keeps it.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn nameList(style: *const css.computed_style.ComputedStyle) !*const css.animation_values.List {
    const value = style.get(.animation_name);
    if (value != .animation_list) return error.NotAList;
    return value.animation_list;
}

test "a computed animation-name keeps the winning declaration's tree scope" {
    const allocator = testing.allocator;
    var outer = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "animation-name: outer");
    defer outer.deinit();
    var inner = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "animation-name: inner, other");
    defer inner.deinit();
    // The inner tree's :host rule wins over the outer tree's (normal
    // declarations: the outer context wins - so give the inner one the higher
    // order within one tree to make it win here).
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &outer, .source = .{ .origin = .author, .order = 1, .tree_scope = .{ .serial = 0 } } },
        .{ .block = &inner, .source = .{ .origin = .author, .order = 2, .tree_scope = .{ .serial = 57 } } },
    });
    defer style.destroy();
    const list = try nameList(style);
    try testing.expectEqual(@as(usize, 2), list.items.items.len);
    try testing.expectEqualStrings("inner", list.items.items[0].name);
    try testing.expectEqual(@as(u64, 57), list.tree_scope.serial);
    // The scope is not part of the serialization.
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(.animation_name, style.get(.animation_name), &out, allocator);
    try testing.expectEqualStrings("inner, other", out.items);
}

test "equal names declared in different trees are different computed values" {
    const allocator = testing.allocator;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "animation-name: spin");
    defer block.deinit();
    const a = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author, .tree_scope = .{ .serial = 3 } } }});
    defer a.destroy();
    const b = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author, .tree_scope = .{ .serial = 4 } } }});
    defer b.destroy();
    const c = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author, .tree_scope = .{ .serial = 3 } } }});
    defer c.destroy();
    try testing.expect(!(try nameList(a)).eql(try nameList(b)));
    try testing.expect((try nameList(a)).eql(try nameList(c)));
}

test "other animation lists keep the document scope" {
    const allocator = testing.allocator;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "animation-duration: 2s, 3s");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author, .tree_scope = .{ .serial = 9 } } }});
    defer style.destroy();
    const value = style.get(.animation_duration);
    try testing.expect(value == .animation_list);
    try testing.expectEqual(@as(u64, 0), value.animation_list.tree_scope.serial);
}
