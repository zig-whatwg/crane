//! CSS Syntax 3 sections 5.5.2–5.5.6: block contents retain declaration runs.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn declaration(rule: css.rules.Rule, name: []const u8, value: []const u8) !void {
    try std.testing.expectEqual(@as(usize, 1), rule.declarations.len);
    try std.testing.expectEqualStrings(name, rule.declarations[0].name);
    try std.testing.expectEqualStrings(value, rule.declarations[0].value);
}

fn runs(allocator: std.mem.Allocator) !void {
    var sheet = try css.rules.parseStyleSheetContents(allocator,
        \\article { color: red; & > .child { color: blue; }
        \\ color: green; @media all { color: purple; & .grandchild { width: 2px; } color: pink; }
        \\ color: black }
    );
    defer sheet.deinit();
    try std.testing.expectEqual(@as(usize, 1), sheet.items.len);
    const parent = sheet.items[0];
    try declaration(parent, "color", "red");
    try std.testing.expectEqual(@as(usize, 4), parent.children.len);
    try std.testing.expectEqualStrings("& > .child", parent.children[0].prelude);
    try declaration(parent.children[0], "color", "blue");
    try std.testing.expectEqualStrings("declarations", @tagName(parent.children[1].kind));
    try declaration(parent.children[1], "color", "green");
    const media = parent.children[2];
    try std.testing.expectEqualStrings("media", media.name);
    try std.testing.expectEqual(@as(usize, 0), media.declarations.len);
    try std.testing.expectEqual(@as(usize, 3), media.children.len);
    try std.testing.expectEqualStrings("declarations", @tagName(media.children[0].kind));
    try declaration(media.children[0], "color", "purple");
    try declaration(media.children[1], "width", "2px");
    try declaration(media.children[2], "color", "pink");
    try declaration(parent.children[3], "color", "black");
}

test "nesting syntax retains interleaved declarations and conditional rule contents" {
    try runs(a);
}

fn recovery(allocator: std.mem.Allocator) !void {
    var sheet = try css.rules.parseStyleSheetContents(
        allocator,
        "a { color: red; bogus; color: green; :unknown { color: blue } color: black; @unknown; width: 1px; }",
    );
    defer sheet.deinit();
    const rule = sheet.items[0];
    // A semicolon-terminated failed parse is not a rule boundary.
    try std.testing.expectEqual(@as(usize, 2), rule.declarations.len);
    try std.testing.expectEqualStrings("green", rule.declarations[1].value);
    // A complete block and any at-rule are boundaries, even if their
    // grammars are later rejected by the DOM rule model.
    try std.testing.expectEqual(@as(usize, 4), rule.children.len);
    try std.testing.expectEqualStrings(":unknown", rule.children[0].prelude);
    try declaration(rule.children[1], "color", "black");
    try std.testing.expectEqualStrings("unknown", rule.children[2].name);
    try declaration(rule.children[3], "width", "1px");
}

test "nesting syntax distinguishes failed declarations from invalid rule boundaries" {
    try recovery(a);
}

fn ambiguity(allocator: std.mem.Allocator) !void {
    var sheet = try css.rules.parseStyleSheetContents(allocator, "--x: { color: red; } p { --tokens: { .hidden { color: red; } }; & .shown { color: green; } }");
    defer sheet.deinit();
    // Syntax 5.5.3 rejects a top-level qualified rule whose prelude starts
    // with a custom-property name followed by a colon.
    try std.testing.expectEqual(@as(usize, 1), sheet.items.len);
    const rule = sheet.items[0];
    try std.testing.expectEqualStrings("p", rule.prelude);
    try std.testing.expectEqual(@as(usize, 1), rule.declarations.len);
    try std.testing.expectEqualStrings("--tokens", rule.declarations[0].name);
    try std.testing.expectEqual(@as(usize, 1), rule.children.len);
    try std.testing.expectEqualStrings("& .shown", rule.children[0].prelude);
}

test "nesting syntax custom-property ambiguity does not reveal rules inside values" {
    try ambiguity(a);
}

test "nesting syntax style attributes still return declarations only" {
    // Preservation pin: this API deliberately drops nested rules and
    // keeps all declarations, unlike a style rule's ordered child list.
    const declarations = try css.rules.parseDeclarationList(a, "color: red; & { width: 2px; } color: green;");
    defer css.rules.freeDeclarationList(a, declarations);
    try std.testing.expectEqual(@as(usize, 2), declarations.len);
    try std.testing.expectEqualStrings("red", declarations[0].value);
    try std.testing.expectEqualStrings("green", declarations[1].value);
}

test "nesting syntax unwinds every allocation failure" {
    try std.testing.checkAllAllocationFailures(a, runs, .{});
    try std.testing.checkAllAllocationFailures(a, recovery, .{});
    try std.testing.checkAllAllocationFailures(a, ambiguity, .{});
}
