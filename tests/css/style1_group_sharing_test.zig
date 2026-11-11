//! Lane style1 batch 1: two styles that hold identical values share the
//! group that holds them (computed_style.zig, "Storage"), so an element pays
//! for a group only when no other style holds the same values.
//!
//! - `clone()`: a holder of a style's groups, one more reference on each
//!   (Blink's MatchedPropertiesCache keeps `CloneStyle()`, WebKit's
//!   MatchedDeclarationsCache `ComputedStyle::clonePtr`: "the ComputedStyle in
//!   the cache is really just a holder for the substructures").
//! - `adoptEqualGroups(from)`: each group a style holds alone whose values
//!   are identical (or, since lane style1 b3, Value.eql-equal: a value the
//!   cascade allocated) to `from`'s is replaced by `from`'s, shared. No value
//!   a reader can see changes.
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
    return @hasDecl(ComputedStyle, "clone") and @hasDecl(ComputedStyle, "adoptEqualGroups") and @hasDecl(ComputedStyle, "groupsHeldAlone");
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

    try testing.expectEqual(alone_before, b.adoptEqualGroups(a));
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
    try testing.expectEqual(@as(usize, 0), b.adoptEqualGroups(a));
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
    try testing.expectEqual(@as(usize, 1), b.adoptEqualGroups(a));
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
    try testing.expectEqual(@as(usize, 0), b.adoptEqualGroups(a));
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
    try testing.expect(b.adoptEqualGroups(holder) >= 5);
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

// Lane style1 b3: values the cascade allocates per element (a font-family
// list, through var()) are equal but not identical; adoption shares them by
// Value.eql, and a write after adoption copies the shared group first.
test "groups whose values are equal but not identical are shared; a later write copies, never writes through" {
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "--ff: Georgia, serif");
    defer root.destroy();
    const text = "font-family: var(--ff); margin-left: 3px";
    const a = try styleOf(allocator, root, text);
    defer a.destroy();
    const b = try styleOf(allocator, root, text);
    defer b.destroy();
    const font = computed.groups.location[@backingInt(Longhand.font_family)].group;
    // Each cascade substituted var(--ff) and allocated its own list.
    try testing.expect(a.slots[font] != b.slots[font]);
    try testing.expect(!computed.identical(a.get(.font_family), b.get(.font_family)));
    try testing.expect(a.get(.font_family).eql(b.get(.font_family)));
    try testing.expect(b.adoptEqualGroups(a) >= 1);
    try testing.expect(a.slots[font] == b.slots[font]);
    // Copy on write: b's next write to that group copies it; a keeps its value.
    try testing.expectEqual(font, computed.groups.location[@backingInt(Longhand.font_weight)].group);
    const weight = a.get(.font_weight);
    try b.set(.font_weight, .{ .number = 701 });
    try testing.expect(a.slots[font] != b.slots[font]);
    try testing.expect(a.get(.font_weight).eql(weight));
    try testing.expect(b.get(.font_weight).eql(.{ .number = 701 }));
    try testing.expect(a.get(.font_family).eql(b.get(.font_family)));
}

test "a custom property record held alone and equal to another's is shared; a different value is not" {
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "--x: 1px");
    defer root.destroy();
    const a = try styleOf(allocator, root, "--a: 3px; --b: calc(var(--a) * 2)");
    defer a.destroy();
    const b = try styleOf(allocator, root, "--a: 3px; --b: calc(var(--a) * 2)");
    defer b.destroy();
    const c = try styleOf(allocator, root, "--a: 4px; --b: calc(var(--a) * 2)");
    defer c.destroy();
    try testing.expect(a.custom != b.custom);
    try testing.expectEqual(@as(usize, 1), b.adoptEqualCustom(a));
    try testing.expect(a.custom == b.custom);
    try testing.expectEqual(@as(u32, 2), a.custom.?.refs);
    try testing.expectEqual(@as(usize, 0), c.adoptEqualCustom(a));
    try testing.expect(c.custom != a.custom);
    try testing.expect(!c.customValue("--b").?.eql(a.customValue("--b").?));
    // A record shared already (its parent's) is never swapped.
    const d = try styleOf(allocator, root, "margin-left: 1px");
    defer d.destroy();
    try testing.expect(d.custom == root.custom);
    try testing.expectEqual(@as(usize, 0), d.adoptEqualCustom(a));
}

// Lane style1 b4: a url() is its resolved URL and the request made for it.
// Value.eql compares a value's text only ("eql deliberately remains a
// value/text comparison. Reuse decisions that keep a source need both":
// Value.resourcesEql), so the same `url(./)` under two base URLs was one value
// to b3's adoption - and to the Debug self-check, which compared through the
// same eql. RED at 67d0ed46337 (server1): firstDifference found no
// difference, and WPT css/cssom/css-style-attr-decl-block.html "Changes to
// CSS declaration block after a base URL change" read the old base's URL
// after the declaration was set again under the new one. Adoption now shares
// on computed_style.interchangeable; the self-check observes
// (firstObservableDifference: serialization and fetch identity).

const UrlResolver = struct {
    prefix: []const u8,
    fn resolve(context: *const anyopaque, allocator: Allocator, raw: []const u8) ?[]u8 {
        const self: *const UrlResolver = @ptrCast(@alignCast(context));
        return std.mem.concat(allocator, u8, &.{ self.prefix, raw }) catch null;
    }
};

/// A child of `parent` whose block sets `background-image: url(./)`,
/// resolved against `base` and fetched under `policy`.
fn urlStyle(allocator: Allocator, parent: *const ComputedStyle, base: []const u8, policy: []const u8) !*ComputedStyle {
    const resolver: UrlResolver = .{ .prefix = base };
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = base, .referrer_policy = policy });
    defer source.unref();
    var block = DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = UrlResolver.resolve } }, "background-image", "url(./)", ""));
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

/// `new`, made after `old` from another source, keeps its own background
/// group through adoption, and the self-check's observation names
/// background-image where Value.eql sees nothing.
fn expectKeptApart(old: *const ComputedStyle, new: *ComputedStyle) !void {
    try testing.expect(new.firstDifference(old) == null);
    try testing.expectEqual(@as(?Longhand, .background_image), try new.firstObservableDifference(old, testing.allocator));
    const before = try serialized(new, .background_image);
    defer testing.allocator.free(before);
    _ = new.adoptEqualGroups(old);
    const bg = groupOf(.background_image);
    try testing.expect(new.slots[bg] != old.slots[bg]);
    const after = try serialized(new, .background_image);
    defer testing.allocator.free(after);
    try testing.expectEqualStrings(before, after);
}

test "a url resolved against another base is another value: adoption keeps it apart, and the self-check observes it" {
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    const old = try urlStyle(allocator, root, "https://example.test/css/cssom/", "");
    defer old.destroy();
    const new = try urlStyle(allocator, root, "https://example.test/", "");
    defer new.destroy();
    const old_text = try serialized(old, .background_image);
    defer testing.allocator.free(old_text);
    const new_text = try serialized(new, .background_image);
    defer testing.allocator.free(new_text);
    try testing.expect(!std.mem.eql(u8, old_text, new_text));
    try expectKeptApart(old, new);
    // The same url under the same base is one value: shared.
    const twin = try urlStyle(allocator, root, "https://example.test/", "");
    defer twin.destroy();
    try testing.expect(try twin.firstObservableDifference(new, allocator) == null);
    try testing.expectEqual(@as(usize, 1), twin.adoptEqualGroups(new));
    try testing.expect(twin.slots[groupOf(.background_image)] == new.slots[groupOf(.background_image)]);
}

test "a url fetched under another referrer policy is another value: the same text and URL, another request" {
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    const old = try urlStyle(allocator, root, "https://example.test/", "no-referrer");
    defer old.destroy();
    const new = try urlStyle(allocator, root, "https://example.test/", "");
    defer new.destroy();
    const old_text = try serialized(old, .background_image);
    defer testing.allocator.free(old_text);
    const new_text = try serialized(new, .background_image);
    defer testing.allocator.free(new_text);
    try testing.expectEqualStrings(old_text, new_text);
    try expectKeptApart(old, new);
}

test "interchangeable is Value.eql and the resources behind the value; a record's whole identity is its eql" {
    const allocator = testing.allocator;
    const root = try styleOf(allocator, null, "--x: 1px");
    defer root.destroy();
    const a = try urlStyle(allocator, root, "https://example.test/a/", "");
    defer a.destroy();
    const b = try urlStyle(allocator, root, "https://example.test/b/", "");
    defer b.destroy();
    const x = a.get(.background_image);
    const y = b.get(.background_image);
    try testing.expect(x.eql(y));
    try testing.expect(!computed.interchangeable(css.style_values.Value, x, y));
    try testing.expect(computed.interchangeable(css.style_values.Value, x, a.get(.background_image)));
    // Tree-scoped names keep their scope in Value.eql (font-family's named
    // families, CSS Scoping 1): the same name from two trees is two values.
    var block = try DeclarationBlock.parse(.{ .allocator = allocator }, "font-family: Foo");
    defer block.deinit();
    var scoped: [2]*ComputedStyle = undefined;
    for (&scoped, 1..) |*s, serial| s.* = try css.cascade.cascade(.{ .allocator = allocator, .parent = root }, &.{.{ .block = &block, .source = .{ .origin = .author, .tree_scope = .{ .serial = serial } } }});
    defer for (scoped) |s| s.destroy();
    try testing.expect(!computed.interchangeable(css.style_values.Value, scoped[0].get(.font_family), scoped[1].get(.font_family)));
    // A custom property record: its eql (names, text, taint, parents).
    const c = try styleOf(allocator, root, "--a: 3px");
    defer c.destroy();
    const d = try styleOf(allocator, root, "--a: 3px");
    defer d.destroy();
    try testing.expect(computed.interchangeable(?*const css.custom_properties.CustomProperties, c.custom, d.custom));
}
