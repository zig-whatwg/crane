//! Lane style1 batch 2, item (B): a computed transition or animation list
//! whose items all compute to themselves is the declared list, one more
//! reference - as Easing.compute keeps a keyword easing and grid Line.compute
//! an integer line - so siblings matched by the same rule hold the same
//! transition data (Blink and WebKit share it between such elements through
//! their matched-properties caches).
//!
//! RED at 55e9a4f78de: List.compute allocated a fresh list per element
//! (animation_values.List.create + its items + a dupe of every name), so two
//! siblings never held the same list and every element that declared a
//! transition paid five lists and their items.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const Longhand = css.properties.Longhand;
const TreeScopeRef = css.cascade.TreeScopeRef;

const transition_longhands = [_]Longhand{ .transition_property, .transition_duration, .transition_timing_function, .transition_delay, .transition_behavior };

fn cascadeWith(allocator: Allocator, parent: ?*const ComputedStyle, block: *const DeclarationBlock, tree_scope: TreeScopeRef) !*ComputedStyle {
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent, .is_root = parent == null }, &.{.{ .block = block, .source = .{ .origin = .author, .tree_scope = tree_scope } }});
}

fn parse(text: []const u8) !DeclarationBlock {
    return DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
}

fn listOf(style: *const ComputedStyle, l: Longhand) *css.animation_values.List {
    return style.get(l).animation_list;
}

fn serialized(style: *const ComputedStyle, l: Longhand) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    return out.toOwnedSlice(testing.allocator);
}

test "siblings that declare the same transition hold the declared lists" {
    var root_block = try parse("font-size: 20px");
    defer root_block.deinit();
    const root = try cascadeWith(testing.allocator, null, &root_block, .{});
    defer root.destroy();
    var block = try parse("transition: opacity 0.3s ease 0s");
    defer block.deinit();
    const a = try cascadeWith(testing.allocator, root, &block, .{});
    defer a.destroy();
    const b = try cascadeWith(testing.allocator, root, &block, .{});
    defer b.destroy();
    for (transition_longhands) |l| {
        const declared = block.get(l).?.value.value.animation_list;
        try testing.expect(listOf(a, l) == declared);
        try testing.expect(listOf(b, l) == declared);
    }
    // The values a reader sees are the declared ones.
    const expected = [_][]const u8{ "opacity", "0.3s", "ease", "0s", "normal" };
    for (transition_longhands, expected) |l, text| {
        const now = try serialized(b, l);
        defer testing.allocator.free(now);
        try testing.expectEqualStrings(text, now);
    }
}

test "a transition costs an element no allocation beyond its group" {
    // Five longhands into one group either way: the same header, the same
    // group copy, the same cascade bookkeeping. Only the per-element lists
    // (five lists, their item arrays and the property name) would differ.
    var root_block = try parse("font-size: 20px");
    defer root_block.deinit();
    const root = try cascadeWith(testing.allocator, null, &root_block, .{});
    defer root.destroy();
    var control_block = try parse("margin: 1px 2px 3px 4px; padding-top: 5px");
    defer control_block.deinit();
    var transition_block = try parse("transition: opacity 0.3s ease 0s");
    defer transition_block.deinit();

    var control = CountingAllocator{ .child = testing.allocator };
    const c = try cascadeWith(control.allocator(), root, &control_block, .{});
    defer c.destroy();
    var transition = CountingAllocator{ .child = testing.allocator };
    const t = try cascadeWith(transition.allocator(), root, &transition_block, .{});
    defer t.destroy();
    std.debug.print("STYLE1B2_LIST_ALLOCATIONS control={d} transition={d}\n", .{ control.count, transition.count });
    try testing.expectEqual(control.count, transition.count);
}

test "an item that computes to something else makes the element its own list" {
    var block = try parse("transition-duration: 300ms, 1s; transition-delay: calc(1s + 100ms)");
    defer block.deinit();
    const style = try cascadeWith(testing.allocator, null, &block, .{});
    defer style.destroy();
    // 300ms computes to 0.3s (the canonical unit), so the list changes.
    try testing.expect(listOf(style, .transition_duration) != block.get(.transition_duration).?.value.value.animation_list);
    try testing.expect(listOf(style, .transition_delay) != block.get(.transition_delay).?.value.value.animation_list);
    const duration = try serialized(style, .transition_duration);
    defer testing.allocator.free(duration);
    try testing.expectEqualStrings("0.3s, 1s", duration);
    const delay = try serialized(style, .transition_delay);
    defer testing.allocator.free(delay);
    try testing.expectEqualStrings("1.1s", delay);
    // The declaration is unchanged.
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("transition-duration", &out);
    try testing.expectEqualStrings("300ms, 1s", out.items);
}

test "animation-name keeps its declaration's tree scope without writing into the declared list" {
    // CSS Scoping 1 tree-scoped references: the computed name remembers the
    // tree of the sheet that declared it. One block can be matched from two
    // trees (a constructed sheet adopted by the document and a shadow root),
    // so the declared list is never the place to write it.
    var block = try parse("animation-name: spin");
    defer block.deinit();
    const declared = block.get(.animation_name).?.value.value.animation_list;
    const shadow = try cascadeWith(testing.allocator, null, &block, .{ .serial = 7 });
    defer shadow.destroy();
    const document = try cascadeWith(testing.allocator, null, &block, .{});
    defer document.destroy();
    try testing.expectEqual(@as(u64, 7), listOf(shadow, .animation_name).tree_scope.serial);
    try testing.expectEqual(@as(u64, 0), listOf(document, .animation_name).tree_scope.serial);
    try testing.expectEqual(@as(u64, 0), declared.tree_scope.serial);
    // The document's name is the declared list; the shadow tree's is its own.
    try testing.expect(listOf(document, .animation_name) == declared);
    try testing.expect(listOf(shadow, .animation_name) != declared);
}

const CountingAllocator = struct {
    child: Allocator,
    count: usize = 0,

    fn allocator(self: *CountingAllocator) Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(ctx: *anyopaque, len: usize, a: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.count += 1;
        return self.child.rawAlloc(len, a, ra);
    }
    fn resize(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, n: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(m, a, n, ra);
    }
    fn remap(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, n: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawRemap(m, a, n, ra);
    }
    fn free(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(m, a, ra);
    }
};
