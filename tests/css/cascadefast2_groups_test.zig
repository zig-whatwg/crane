//! Lane cascadefast2: a ComputedStyle's values live in groups shared between
//! styles and copied on write (computed_style.zig, "Storage"), so a longhand
//! costs an element only when the element writes into its group.
//!
//! The ownership rule pinned here, through cascade() itself: a style holds
//! one reference on each group in its `held` set and on no other; a group's
//! values hold one reference each; a copy retains every counted value it
//! copies and the last release of a group releases them; teardown order
//! does not matter.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const computed = css.computed_style;
const ComputedStyle = computed.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const Longhand = css.properties.Longhand;
const Value = css.style_values.Value;

fn grouped() bool {
    return @hasDecl(computed, "groups") and @hasDecl(computed, "Group") and @hasField(ComputedStyle, "held");
}

/// The style of a child of `parent` (the root when null) whose one author
/// block is `text`.
fn styleOf(allocator: Allocator, parent: ?*const ComputedStyle, text: []const u8) !*ComputedStyle {
    var block = try DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent, .is_root = parent == null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn resolvedEquals(style: *const ComputedStyle, l: Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

fn groupOf(comptime l: Longhand) usize {
    return computed.groups.location[@intFromEnum(l)].group;
}

fn familiesRefs(style: *const ComputedStyle) u32 {
    return style.get(.font_family).font_family.refs.load(.monotonic);
}

test "a child shares its parent's untouched inherited group and copies one it writes" {
    if (comptime !grouped()) return error.GroupedStorageNotImplemented;
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "font-family: \"A Font\", monospace; color: red; margin-left: 3px");
    defer root.destroy();
    const font = groupOf(.font_family);
    try testing.expect(root.held.isSet(font));
    try testing.expectEqual(@as(u32, 1), computed.Group.of(root.slots[font]).refs);
    const families = familiesRefs(root);

    // Untouched: the same group, one more reference on it, none on the
    // values inside it.
    const shared = try styleOf(allocator, root, "");
    var shared_live = true;
    defer if (shared_live) shared.destroy();
    try testing.expect(shared.slots[font] == root.slots[font]);
    try testing.expect(shared.held.isSet(font));
    try testing.expectEqual(@as(u32, 2), computed.Group.of(root.slots[font]).refs);
    try testing.expectEqual(families, familiesRefs(root));
    // A non-inherited group the root wrote into is not inherited: the
    // child's is the initial values, held by no one.
    const surround = groupOf(.margin_left);
    try testing.expect(root.held.isSet(surround));
    try testing.expect(!shared.held.isSet(surround));
    try resolvedEquals(shared, .margin_left, "0px");

    // Written: a copy, which retains every counted value it copies (the
    // families list), and leaves the parent's value alone.
    const written = try styleOf(allocator, root, "font-size: 30px");
    var written_live = true;
    defer if (written_live) written.destroy();
    try testing.expect(written.slots[font] != root.slots[font]);
    try testing.expect(written.held.isSet(font));
    try testing.expectEqual(@as(u32, 1), computed.Group.of(written.slots[font]).refs);
    try testing.expectEqual(@as(u32, 2), computed.Group.of(root.slots[font]).refs);
    try testing.expectEqual(families + 1, familiesRefs(root));
    try resolvedEquals(written, .font_size, "30px");
    try resolvedEquals(root, .font_size, "16px");
    try resolvedEquals(written, .font_family, "A Font, monospace");

    // The copy's last release releases what it retained.
    written.destroy();
    written_live = false;
    try testing.expectEqual(families, familiesRefs(root));
    shared.destroy();
    shared_live = false;
    try testing.expectEqual(@as(u32, 1), computed.Group.of(root.slots[font]).refs);
}

test "an identical write keeps a group shared or initial" {
    if (comptime !grouped()) return error.GroupedStorageNotImplemented;
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "color: red");
    defer root.destroy();
    // display inline, margin 0, color inherited: every write identical.
    const child = try styleOf(allocator, root, "display: inline; margin-left: 0px; color: inherit; font-size: 16px");
    defer child.destroy();
    try testing.expect(!child.held.isSet(groupOf(.display)));
    try testing.expect(!child.held.isSet(groupOf(.margin_left)));
    try testing.expect(child.slots[groupOf(.color)] == root.slots[groupOf(.color)]);
    try testing.expect(child.slots[groupOf(.font_size)] == root.slots[groupOf(.font_size)]);
    try resolvedEquals(child, .color, "rgb(255, 0, 0)");
}

/// Wraps an allocator and overwrites what it frees, so a read of a freed
/// group reads 0xdd bytes (docs/lessons/architecture-a-store-entry-must-hold-what-it-names.md).
const Poisoning = struct {
    child: Allocator,

    fn allocator(self: *Poisoning) Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(ctx: *anyopaque, len: usize, a: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Poisoning = @ptrCast(@alignCast(ctx));
        return self.child.rawAlloc(len, a, ra);
    }
    fn resize(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, n: usize, ra: usize) bool {
        const self: *Poisoning = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(m, a, n, ra);
    }
    fn remap(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, n: usize, ra: usize) ?[*]u8 {
        const self: *Poisoning = @ptrCast(@alignCast(ctx));
        return self.child.rawRemap(m, a, n, ra);
    }
    fn free(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, ra: usize) void {
        const self: *Poisoning = @ptrCast(@alignCast(ctx));
        @memset(m, 0xdd);
        self.child.rawFree(m, a, ra);
    }
};

test "a child keeps a shared group alive after its parent's style is destroyed" {
    if (comptime !grouped()) return error.GroupedStorageNotImplemented;
    var poisoning: Poisoning = .{ .child = testing.allocator };
    const allocator = poisoning.allocator();
    const root = try styleOf(allocator, null, "font-family: \"A Font\", monospace; text-shadow: 1px 2px red; cursor: url(c.png), pointer");
    var root_live = true;
    defer if (root_live) root.destroy();
    const child = try styleOf(allocator, root, "");
    defer child.destroy();
    const grandchild = try styleOf(allocator, child, "letter-spacing: 2px");
    defer grandchild.destroy();
    const font = groupOf(.font_family);
    // The root, the child and the grandchild (which writes only into the
    // text group) share the font group.
    try testing.expectEqual(@as(u32, 3), computed.Group.of(root.slots[font]).refs);
    root.destroy();
    root_live = false;
    // The root's reference is gone; the child's and the grandchild's hold
    // the group, its families list and its text.
    try testing.expectEqual(@as(u32, 2), computed.Group.of(child.slots[font]).refs);
    try resolvedEquals(child, .font_family, "A Font, monospace");
    try resolvedEquals(grandchild, .font_family, "A Font, monospace");
    try resolvedEquals(grandchild, .text_shadow, "rgb(255, 0, 0) 1px 2px 0px");
    try resolvedEquals(grandchild, .cursor, "url(\"c.png\"), pointer");
    try resolvedEquals(grandchild, .letter_spacing, "2px");
}

fn chain(allocator: Allocator) !void {
    const root = try styleOf(allocator, null, "font-family: \"A Font\", serif; color: blue; text-shadow: 1px 1px red; background-color: green; margin-top: 2px");
    errdefer root.destroy();
    const child = try styleOf(allocator, root, "font-size: 2em; border-top-width: 3px; border-top-style: solid; background-image: url(b.png)");
    errdefer child.destroy();
    const grandchild = try styleOf(allocator, child, "color: currentcolor; margin-top: inherit; all: inherit");
    // Parent first: the order the cache drops styles in is not the tree's.
    root.destroy();
    child.destroy();
    grandchild.destroy();
}

test "group copies and shares release everything under every allocation failure" {
    if (comptime !grouped()) return error.GroupedStorageNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, chain, .{});
}

test "the counted-value predicate defaults to counted" {
    if (comptime !@hasDecl(computed, "mayHoldReference")) return error.GroupedStorageNotImplemented;
    const may = computed.mayHoldReference;
    // Proven pointer-free.
    inline for (.{ f64, i32, bool, css.style_values.Keyword, css.style_values.Length, css.style_values.Display, struct { a: f64, b: enum { x, y } }, [3]u8, ?u32 }) |T| {
        try testing.expect(!may(T));
    }
    // A pointer at any depth, and anything the predicate cannot see into.
    inline for (.{ *u8, []const u8, ?*u32, struct { p: *u8 }, union(enum) { a: u8, b: *u8 }, [2]?*u8, *anyopaque, *const fn () void, @Vector(4, f32), anyerror!u8, opaque {}, struct { o: *opaque {} } }) |T| {
        try testing.expect(may(T));
    }
    // Value: every arm whose payload is a pointer is counted; the plain
    // keyword, length, number and display arms are not.
    inline for (@typeInfo(Value).@"union".field_types) |f_type| {
        if (@typeInfo(f_type) == .pointer) try testing.expect(may(f_type));
    }
    try testing.expect(!computed.isCounted(Value.kw(.none)));
    try testing.expect(!computed.isCounted(Value.px(3)));
    try testing.expect(!computed.isCounted(.{ .number = 1 }));
    try testing.expect(computed.isCounted(.{ .color = .{ .rgba = css.style_values.RgbaColor.black } }));
}

test "identical compares tags, addresses and float bits, never text" {
    if (comptime !@hasDecl(computed, "identical")) return error.GroupedStorageNotImplemented;
    const identical = computed.identical;
    try testing.expect(identical(Value.px(3), Value.px(3)));
    try testing.expect(!identical(Value.px(0), Value.px(-0.0)));
    try testing.expect(!identical(Value.px(3), .{ .number = 3 }));
    try testing.expect(identical(Value.kw(.auto), Value.kw(.auto)));
    const a = try css.style_values.SharedText.create(testing.allocator, "x");
    defer a.unref();
    const b = try css.style_values.SharedText.create(testing.allocator, "x");
    defer b.unref();
    try testing.expect(identical(.{ .text = a }, .{ .text = a }));
    try testing.expect(!identical(.{ .text = a }, .{ .text = b }));
}

test "a style's size does not grow with the longhands Crane supports" {
    if (comptime !grouped()) return error.GroupedStorageNotImplemented;
    std.debug.print("CF2_STYLE_LAYOUT longhands={d} groups={d} stored={d} ComputedStyle={d} Value={d}\n", .{
        Longhand.count, computed.groups.count, computed.groups.stored, @sizeOf(ComputedStyle), @sizeOf(Value),
    });
    // One pointer per group, not a value per longhand.
    try testing.expect(@sizeOf(ComputedStyle) <= 512);
    // A child that declares nothing allocates only its header.
    var counting = CountingAllocator{ .child = testing.allocator };
    const root = try styleOf(testing.allocator, null, "color: red; margin-left: 2px");
    defer root.destroy();
    const child = try css.cascade.cascade(.{ .allocator = counting.allocator(), .parent = root }, &.{});
    defer child.destroy();
    try testing.expectEqual(@as(usize, 1), counting.count);
    try testing.expectEqual(@as(usize, @sizeOf(ComputedStyle)), counting.bytes);
}

const CountingAllocator = struct {
    child: Allocator,
    count: usize = 0,
    bytes: usize = 0,

    fn allocator(self: *CountingAllocator) Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(ctx: *anyopaque, len: usize, a: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.count += 1;
        self.bytes += len;
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

test "the held bit, never a static array's address, decides what a style writes and frees" {
    if (comptime !grouped()) return error.GroupedStorageNotImplemented;
    const identical = computed.identical;
    // A held group whose values are back to the initial ones is still this
    // style's: freed once, at destroy (the testing allocator reports a
    // leak or a double free).
    const style = try ComputedStyle.initial(testing.allocator);
    defer style.destroy();
    const surround = groupOf(.margin_left);
    try style.set(.margin_left, Value.px(3));
    try testing.expect(style.held.isSet(surround));
    try style.set(.margin_left, Value.px(0));
    try testing.expect(style.held.isSet(surround));
    try testing.expect(identical(style.get(.margin_left), Value.px(0)));
    // Groups whose initial values are identical (none in today's layout,
    // any a later one makes): writing into one leaves the other unheld and
    // initial, and frees only the one written.
    var pairs: usize = 0;
    const initial = try ComputedStyle.initial(testing.allocator);
    defer initial.destroy();
    for (0..computed.groups.count) |a| for (a + 1..computed.groups.count) |b| {
        if (computed.groups.lengths[a] != computed.groups.lengths[b]) continue;
        const same = for (0..computed.groups.lengths[a]) |k| {
            if (!identical(initial.slots[a][k], initial.slots[b][k])) break false;
        } else true;
        if (!same) continue;
        pairs += 1;
        const written = try ComputedStyle.initial(testing.allocator);
        defer written.destroy();
        const target = for (0..Longhand.count) |i| {
            const loc = computed.groups.location[i];
            if (loc.stored and loc.group == a and loc.index == 0) break @as(Longhand, @enumFromInt(i));
        } else unreachable;
        try written.set(target, Value.px(12345));
        try testing.expect(written.held.isSet(a));
        try testing.expect(!written.held.isSet(b));
        for (0..computed.groups.lengths[b]) |k| try testing.expect(identical(written.slots[b][k], initial.slots[b][k]));
    };
    std.debug.print("CF2_EQUAL_INITIAL_GROUPS {d}\n", .{pairs});
}
