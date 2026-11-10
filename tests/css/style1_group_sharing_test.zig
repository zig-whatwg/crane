//! Lane style1 batch 1: two styles that hold identical values share the
//! group that holds them (computed_style.zig, "Storage"), so an element pays
//! for a group only when no other style holds the same values.
//!
//! - `clone()`: a holder of a style's groups, one more reference on each
//!   (Blink's MatchedPropertiesCache keeps `CloneStyle()`, WebKit's
//!   MatchedDeclarationsCache `ComputedStyle::clonePtr`: "the ComputedStyle in
//!   the cache is really just a holder for the substructures").
//! - `adoptIdenticalGroups(from)`: each group a style holds alone whose values
//!   are identical to `from`'s is replaced by `from`'s, shared. No value a
//!   reader can see changes.
//!
//! RED at 01edfb83b0a: neither function exists.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const computed = css.computed_style;
const ComputedStyle = computed.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const Longhand = css.properties.Longhand;

fn implemented() bool {
    return @hasDecl(ComputedStyle, "clone") and @hasDecl(ComputedStyle, "adoptIdenticalGroups") and @hasDecl(ComputedStyle, "groupsHeldAlone");
}

/// The style of a child of `parent` (the root when null) whose one author
/// block is `text`.
fn styleOf(allocator: Allocator, parent: ?*const ComputedStyle, text: []const u8) !*ComputedStyle {
    var block = try DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent, .is_root = parent == null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn groupOf(comptime l: Longhand) usize {
    return computed.groups.location[@backingInt(l)].group;
}

fn serialized(style: *const ComputedStyle, l: Longhand) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    return out.toOwnedSlice(testing.allocator);
}

const block_text = "display: flex; margin-left: 3px; padding-top: 2px; border-top: 1px solid red; background-color: #fafafa; color: #333";
const probes = [_]Longhand{ .display, .margin_left, .padding_top, .border_top_width, .border_top_style, .border_top_color, .background_color, .color, .font_size };

test "two siblings that write the same values share every group they wrote" {
    if (comptime !implemented()) return error.GroupSharingNotImplemented;
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "font-size: 20px");
    defer root.destroy();
    const a = try styleOf(allocator, root, block_text);
    defer a.destroy();
    const b = try styleOf(allocator, root, block_text);
    defer b.destroy();
    // Before: each holds its own copy of the groups its block wrote.
    const alone_before = b.groupsHeldAlone();
    try testing.expect(alone_before >= 5);
    var before: [probes.len][]u8 = undefined;
    for (probes, 0..) |l, i| before[i] = try serialized(b, l);
    defer for (before) |s| testing.allocator.free(s);

    try testing.expectEqual(alone_before, b.adoptIdenticalGroups(a));
    try testing.expectEqual(@as(usize, 0), b.groupsHeldAlone());
    try testing.expectEqual(@as(usize, 0), a.groupsHeldAlone());
    for ([_]usize{ groupOf(.display), groupOf(.margin_left), groupOf(.border_top_width), groupOf(.background_color), groupOf(.color) }) |g| {
        try testing.expect(a.slots[g] == b.slots[g]);
        try testing.expectEqual(@as(u32, 2), computed.Group.of(b.slots[g]).refs);
    }
    // After: the same values.
    for (probes, 0..) |l, i| {
        const now = try serialized(b, l);
        defer testing.allocator.free(now);
        try testing.expectEqualStrings(before[i], now);
    }
    // A second adoption shares nothing more.
    try testing.expectEqual(@as(usize, 0), b.adoptIdenticalGroups(a));
}

test "a group whose values differ in one slot stays the style's own" {
    if (comptime !implemented()) return error.GroupSharingNotImplemented;
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    const a = try styleOf(allocator, root, "margin-left: 3px; margin-top: 1px; display: block");
    defer a.destroy();
    const b = try styleOf(allocator, root, "margin-left: 3px; margin-top: 2px; display: block");
    defer b.destroy();
    // display's group is identical; the margins' differ in margin-top.
    try testing.expectEqual(@as(usize, 1), b.adoptIdenticalGroups(a));
    try testing.expect(a.slots[groupOf(.display)] == b.slots[groupOf(.display)]);
    try testing.expect(a.slots[groupOf(.margin_top)] != b.slots[groupOf(.margin_top)]);
    const top = try serialized(b, .margin_top);
    defer testing.allocator.free(top);
    try testing.expectEqualStrings("2px", top);
}

test "an em length shares only under parents with the same font size" {
    if (comptime !implemented()) return error.GroupSharingNotImplemented;
    const allocator = testing.allocator;
    const small = try styleOf(allocator, null, "font-size: 10px");
    defer small.destroy();
    const big = try styleOf(allocator, null, "font-size: 20px");
    defer big.destroy();
    // The same declarations, computed under two parents: 20px and 40px.
    const a = try styleOf(allocator, small, "margin-left: 2em");
    defer a.destroy();
    const b = try styleOf(allocator, big, "margin-left: 2em");
    defer b.destroy();
    try testing.expectEqual(@as(usize, 0), b.adoptIdenticalGroups(a));
    const left = try serialized(b, .margin_left);
    defer testing.allocator.free(left);
    try testing.expectEqualStrings("40px", left);
}

test "a holder keeps the groups after the style it was made from is gone, and frees them last" {
    if (comptime !implemented()) return error.GroupSharingNotImplemented;
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    const a = try styleOf(allocator, root, "--x: 1; " ++ block_text);
    const holder = try a.clone(allocator);
    const g = groupOf(.margin_left);
    try testing.expectEqual(@as(u32, 2), computed.Group.of(a.slots[g]).refs);
    a.destroy();
    try testing.expectEqual(@as(u32, 1), computed.Group.of(holder.slots[g]).refs);
    // A later style shares the holder's groups (std.testing.allocator fails
    // the test if any group outlives the last of them, or is freed twice).
    const b = try styleOf(allocator, root, "--x: 1; " ++ block_text);
    defer b.destroy();
    try testing.expect(b.adoptIdenticalGroups(holder) >= 5);
    holder.destroy();
    const left = try serialized(b, .margin_left);
    defer testing.allocator.free(left);
    try testing.expectEqualStrings("3px", left);
}

test "sharing never allocates, and a failed clone leaves the style's references as they were" {
    if (comptime !implemented()) return error.GroupSharingNotImplemented;
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    const a = try styleOf(allocator, root, block_text);
    defer a.destroy();
    var failing = testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try testing.expectError(error.OutOfMemory, a.clone(failing.allocator()));
    try testing.expectEqual(@as(u32, 1), computed.Group.of(a.slots[groupOf(.margin_left)]).refs);
}
