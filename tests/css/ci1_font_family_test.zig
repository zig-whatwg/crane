//! Fonts4 §2.1 / CSS Shadow1 §4.2: owned, tree-scoped family names.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectFamily(input: []const u8, expected: ?[]const u8) !void {
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = .font_family }, input, &assignments));
    if (expected) |text| {
        try testing.expectEqual(@as(usize, 1), assignments.items.len);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try css.properties.serializeValue(.font_family, assignments.items[0].value.value, &out, testing.allocator);
        try testing.expectEqualStrings(text, out.items);
    }
}

test "font family canonicalization preserves names that require quotes" {
    // Q39: optional quotes follow Firefox/Safari. Reserved, leading-digit,
    // punctuation and repeated-space names must round-trip without changes.
    try expectFamily("'Helvetica Neue', SERIF", "Helvetica Neue, serif");
    try expectFamily("'Veronica'", "Veronica");
    try expectFamily("'inherit', 'serif', 'Serif', 'default'", "\"inherit\", \"serif\", \"Serif\", \"default\"");
    try expectFamily("'21st Century', '34J', '1'", "\"21st Century\", \"34J\", \"1\"");
    try expectFamily("'A  B', 'A,B', 'A!B'", "\"A  B\", \"A,B\", \"A!B\"");
    try expectFamily("\\48 elvetica  Neue, sans-serif", "Helvetica Neue, sans-serif");
    // Q40/Q41: a leading generic is reserved; CSS-wide words inside names
    // are accepted but quoted by the Chrome/Safari serialization majority.
    try expectFamily("serif Foo", null);
    try expectFamily("Foo serif", "Foo serif");
    try expectFamily("inherit Foo", "\"inherit Foo\"");
    try expectFamily("Foo inherit", "\"Foo inherit\"");
    try expectFamily("default bongo", "\"default bongo\"");
    try expectFamily("caption, icon, menu", "caption, icon, menu");
    try expectFamily("emoji, 'emoji', fangsong, 'fangsong'", "emoji, emoji, fangsong, fangsong");
    try testing.expect(!css.properties.isGenericFamily("emoji"));
    try testing.expect(!css.properties.isGenericFamily("fangsong"));
    for ([_][]const u8{ "cursive serif", "'Lucida' Grande", "Ahem!", "#POUND", "Hawaii 5-0", "A, inherit", "default, A", "A, revert-rule", "A,", ",A" }) |bad| try expectFamily(bad, null);
}

const ScopeChecks = if (@hasDecl(css, "font_request") and @hasField(css.cascade.Source, "tree_scope")) struct {
    fn inherited(allocator: std.mem.Allocator) !void {
        var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-family:'Scoped Family',serif");
        var parent_block_owned = true;
        defer if (parent_block_owned) parent_block.deinit();
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author, .tree_scope = .{ .serial = 41 } } }});
        var parent_owned = true;
        defer if (parent_owned) parent.destroy();
        var empty = css.declarations.DeclarationBlock.init(allocator);
        defer empty.deinit();
        const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &empty, .source = .{ .origin = .author, .tree_scope = .{ .serial = 99 } } }});
        defer child.destroy();
        var explicit_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-family:inherit");
        defer explicit_block.deinit();
        const explicit_child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &explicit_block, .source = .{ .origin = .author, .tree_scope = .{ .serial = 99 } } }});
        defer explicit_child.destroy();
        parent.destroy();
        parent_owned = false;
        parent_block.deinit();
        parent_block_owned = false;

        for ([_]*const css.computed_style.ComputedStyle{ child, explicit_child }) |inherited_style| {
            const request = css.font_request.fromComputed(inherited_style) orelse return error.NoComputedFontRequest;
            try testing.expectEqual(@as(usize, 2), request.families.len);
            try testing.expectEqualStrings("Scoped Family", request.families[0].named.name);
            try testing.expectEqual(@as(u64, 41), request.families[0].named.scope.serial);
            try testing.expect(request.families[1] == .generic);
        }
    }

    fn winner(allocator: std.mem.Allocator) !void {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-family:From User");
        defer user.deinit();
        var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-family:revert");
        defer author.deinit();
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
            .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 17 } } },
            .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 23 } } },
        });
        defer style.destroy();
        const request = css.font_request.fromComputed(style) orelse return error.NoComputedFontRequest;
        try testing.expectEqualStrings("From User", request.families[0].named.name);
        try testing.expectEqual(@as(u64, 17), request.families[0].named.scope.serial);
    }
    fn nestedFamilies(allocator: std.mem.Allocator) !void {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font:600 18px 'Scope One','Scope Two',serif");
        var user_owned = true;
        defer if (user_owned) user.deinit();
        var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font:revert");
        var author_owned = true;
        defer if (author_owned) author.deinit();
        var matched = [_]css.cascade.Matched{
            .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 37 } } },
            .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 91 } } },
        };
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &matched);
        var parent_owned = true;
        defer if (parent_owned) parent.destroy();
        // The aggregate owns each named reference's copied winning scope.
        matched[0].source.tree_scope.serial = 999;
        var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font:inherit");
        var child_block_owned = true;
        defer if (child_block_owned) child_block.deinit();
        const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{
            .block = &child_block,
            .source = .{ .origin = .author, .tree_scope = .{ .serial = 73 } },
        }});
        defer child.destroy();
        parent.destroy();
        parent_owned = false;
        user.deinit();
        user_owned = false;
        author.deinit();
        author_owned = false;
        child_block.deinit();
        child_block_owned = false;
        const request = css.font_request.fromComputed(child) orelse return error.NoComputedFontRequest;
        try testing.expectEqual(@as(usize, 3), request.families.len);
        for ([_][]const u8{ "Scope One", "Scope Two" }, 0..) |name, index| {
            const item = request.families[index];
            try testing.expect(item == .named);
            try testing.expectEqualStrings(name, item.named.name);
            try testing.expectEqual(@as(u64, 37), item.named.scope.serial);
        }
        try testing.expect(request.families[2] == .generic);
        try testing.expectEqual(@as(f32, 600), request.weight);
        try testing.expectEqual(@as(f32, 18), request.size_px);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try child.serializeResolved(.font_family, &out, allocator);
        try testing.expectEqualStrings("Scope One, Scope Two, serif", out.items);
    }
} else struct {};

test "inherited named families retain their declaration scope and outlive both parent and declaration" {
    if (comptime !@hasDecl(css, "font_request") or !@hasField(css.cascade.Source, "tree_scope")) return error.TypedFontFamilyNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, ScopeChecks.inherited, .{});
}

test "revert captures the actual winning family's scope at every allocation failure" {
    if (comptime !@hasDecl(css, "font_request") or !@hasField(css.cascade.Source, "tree_scope")) return error.TypedFontFamilyNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, ScopeChecks.winner, .{});
}

// Q93: a real nested Families consumer. Image ComponentContext forwarding
// is separately pinned by its capture test until the owner tree-count API.
test "font shorthand revert and inheritance retain every nested family scope after all sources end" {
    if (comptime !@hasDecl(css, "font_request") or !@hasField(css.cascade.Source, "tree_scope")) return error.TypedFontFamilyNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, ScopeChecks.nestedFamilies, .{});
}
