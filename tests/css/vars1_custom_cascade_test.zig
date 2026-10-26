//! Custom properties in the cascade (lane vars1): CSS Variables 1 §2
//! (ordinary cascade and inheritance, CSS-wide keywords), §3 (var() in
//! custom properties), Values 5 Appendix A (cycles: every participant is
//! guaranteed-invalid; a CSS-wide keyword after substitution), and the
//! shared computed record (an unchanged inherited map is the parent's).
//! Cases from css/css-variables/variable-substitution-variable-
//! declaration.html, variable-cycles.html, variable-css-wide-keywords.html
//! and variable-definition-cascading.html.
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const cascade_mod = css.cascade;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;

const Sheet = struct {
    text: []const u8,
    origin: cascade_mod.Origin = .author,
    layer: u16 = cascade_mod.unlayered,
    order: u32 = 0,
    element_attached: bool = false,
};

const Tree = struct {
    allocator: Allocator,
    styles: std.ArrayList(*ComputedStyle) = .empty,
    environment: ?css.substitution.Environment = null,

    fn deinit(self: *Tree) void {
        var i = self.styles.items.len;
        while (i > 0) {
            i -= 1;
            self.styles.items[i].destroy();
        }
        self.styles.deinit(self.allocator);
    }

    /// The style of a child of the last element styled (the root first).
    fn element(self: *Tree, sheets: []const Sheet) !*ComputedStyle {
        var blocks: std.ArrayList(DeclarationBlock) = .empty;
        defer {
            for (blocks.items) |*b| b.deinit();
            blocks.deinit(self.allocator);
        }
        var matched: std.ArrayList(cascade_mod.Matched) = .empty;
        defer matched.deinit(self.allocator);
        try blocks.ensureTotalCapacity(self.allocator, sheets.len);
        for (sheets) |sheet| blocks.appendAssumeCapacity(try DeclarationBlock.parse(.{ .allocator = self.allocator }, sheet.text));
        for (sheets, blocks.items) |sheet, *block| try matched.append(self.allocator, .{ .block = block, .source = .{
            .origin = sheet.origin,
            .layer = sheet.layer,
            .order = sheet.order,
            .element_attached = sheet.element_attached,
        } });
        const parent: ?*const ComputedStyle = if (self.styles.items.len == 0) null else self.styles.items[self.styles.items.len - 1];
        try self.styles.ensureUnusedCapacity(self.allocator, 1);
        const style = try cascade_mod.cascade(.{
            .allocator = self.allocator,
            .parent = parent,
            .is_root = parent == null,
            .environment = self.environment,
        }, matched.items);
        self.styles.appendAssumeCapacity(style);
        return style;
    }
};

fn expectCustom(style: *const ComputedStyle, name: []const u8, expected: ?[]const u8) !void {
    const got = style.customValue(name);
    if (expected) |e| {
        if (got == null) {
            std.debug.print("{s}: expected \"{s}\", got the guaranteed-invalid value\n", .{ name, e });
            return error.TestExpectedEqual;
        }
        try testing.expectEqualStrings(e, got.?.bytes);
    } else if (got) |g| {
        std.debug.print("{s}: expected the guaranteed-invalid value, got \"{s}\"\n", .{ name, g.bytes });
        return error.TestExpectedEqual;
    }
}

test "custom properties inherit; an unchanged map is the parent's record, not a copy" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    const root = try tree.element(&.{.{ .text = "--a: 1; --b: x  y" }});
    const child = try tree.element(&.{.{ .text = "color: red" }});
    try expectCustom(child, "--a", "1");
    try expectCustom(child, "--b", "x  y");
    try testing.expectEqual(root.custom.?, child.custom.?);
    const grandchild = try tree.element(&.{.{ .text = "--c: 3" }});
    try expectCustom(grandchild, "--a", "1");
    try expectCustom(grandchild, "--c", "3");
    try expectCustom(child, "--c", null);
}

test "re-declaring the inherited value keeps sharing the parent's record" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    // A Tailwind-style `*` rule: the same declaration on every element.
    var star = try DeclarationBlock.parse(.{ .allocator = testing.allocator }, "--tw-a: 0; --tw-b: none");
    defer star.deinit();
    const root = try cascade_mod.cascade(.{ .allocator = testing.allocator, .parent = null, .is_root = true }, &.{.{ .block = &star, .source = .{ .origin = .author } }});
    defer root.destroy();
    const child = try cascade_mod.cascade(.{ .allocator = testing.allocator, .parent = root }, &.{.{ .block = &star, .source = .{ .origin = .author } }});
    defer child.destroy();
    try testing.expectEqual(root.custom.?, child.custom.?);
    // Equal text from another declaration is unchanged too.
    const other = try tree.element(&.{.{ .text = "--x: 1" }});
    const same = try tree.element(&.{.{ .text = "--x: 1" }});
    try testing.expectEqual(other.custom.?, same.custom.?);
}

test "the cascade picks the winner: importance, attachment, layers, order" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    const style = try tree.element(&.{
        .{ .text = "--a: rule; --b: rule !important; --c: early", .order = 1 },
        .{ .text = "--a: inline; --b: inline; --d: layered", .element_attached = true, .order = 2 },
        .{ .text = "--c: late; --d: unlayered-wins", .order = 3 },
        .{ .text = "--d: layer", .layer = 0, .order = 4 },
    });
    try expectCustom(style, "--a", "inline");
    try expectCustom(style, "--b", "rule");
    try expectCustom(style, "--c", "late");
    try expectCustom(style, "--d", "layered");
}

test "CSS-wide keywords (variable-css-wide-keywords.html)" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "--is-initial: initial; --should-not-inherit: tomato; --should-inherit: lightgreen; --r: ua-parent" }});
    const style = try tree.element(&.{
        .{ .text = "--r: from-ua", .origin = .user_agent },
        .{ .text = "--layered: lightgreen", .layer = 0, .order = 1 },
        .{ .text = "--layered: revert-layer", .layer = 1, .order = 2 },
        .{ .text = "--should-not-inherit: initial; --should-inherit: inherit; --u: unset; --r: revert; --is-initial: inherit", .order = 3 },
    });
    try expectCustom(style, "--should-not-inherit", null);
    try expectCustom(style, "--should-inherit", "lightgreen");
    try expectCustom(style, "--u", null);
    // revert rolls the author value back to the user-agent declaration.
    try expectCustom(style, "--r", "from-ua");
    try expectCustom(style, "--layered", "lightgreen");
    // The parent's guaranteed-invalid value inherits as itself.
    try expectCustom(style, "--is-initial", null);
}

test "revert in the user-agent origin acts as unset (inherit)" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "--x: parent" }});
    const style = try tree.element(&.{.{ .text = "--x: revert", .origin = .user_agent }});
    try expectCustom(style, "--x", "parent");
}

test "var() in custom properties (variable-substitution-variable-declaration.html target1/3/9)" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    const style = try tree.element(&.{.{ .text = "--var2: var(--var1) 10px; --var1: var(--var0) 13px 17px; --var0: 23px; --t3b: var(--t3a, 3px); --t3a: var(--t3z, 5px); --varA: good; --varB: very var(--varA, var(--varC)); --varC: var(--varB)" }});
    try expectCustom(style, "--var2", "23px 13px 17px 10px");
    try expectCustom(style, "--t3a", "5px");
    try expectCustom(style, "--t3b", "5px");
    try expectCustom(style, "--varA", "good");
    try expectCustom(style, "--varB", "very good");
    try expectCustom(style, "--varC", "very good");
}

test "an invalid reference is the guaranteed-invalid value, never the inherited one" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "--a: parent; --n: --a; --d: parent" }});
    const style = try tree.element(&.{.{ .text = "--a: var(--missing); --b: var(var(--n)); --c: var(--missing, initial); --d: var(--missing, inherit); --e: [var(--missing,)]" }});
    try expectCustom(style, "--a", null);
    // --b reads THIS element's --a, which is guaranteed-invalid.
    try expectCustom(style, "--b", null);
    // A CSS-wide keyword after substitution is that keyword.
    try expectCustom(style, "--c", null);
    try expectCustom(style, "--d", "parent");
    try expectCustom(style, "--e", "[]");
}

test "cycles make every participant guaranteed-invalid, fallback or not (variable-cycles.html)" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    const style = try tree.element(&.{.{
        .text =
        // target4: a 2-cycle, and a property that only reads it.
        "--A4: var(--B4); --B4: var(--A4); --C4: var(--B4, 13px);" ++
            // target5: --C5 is in the cycle through --B5.
            "--A5: var(--B5); --B5: var(--A5) var(--C5); --C5: var(--B5, 13px);" ++
            // target6: --C6 joins the cycle through --B6's evaluated fallback
            // (the spec, Firefox 158 and Safari 27; Chrome 156 says 13px).
            "--A6: var(--B6); --B6: var(--A6) var(--undefined, var(--C6)); --C6: var(--B6, 13px);" ++
            // target7: a fallback that is not evaluated is no edge.
            "--exists: 5px; --A7: var(--B7); --B7: var(--A7) var(--exists, var(--C7)); --C7: var(--B7, 13px);" ++
            // target8: a self-reference; a reader of it.
            "--A8: var(--A8, 9px); --B8: var(--A8, 7px);" ++
            // A 3-cycle with a fallback on one edge.
            "--one: var(--two); --two: var(--three, baz); --three: var(--one);",
    }});
    for ([_][]const u8{ "--A4", "--B4", "--A5", "--B5", "--C5", "--A6", "--B6", "--C6", "--A7", "--B7", "--A8", "--one", "--two", "--three" }) |name| try expectCustom(style, name, null);
    try expectCustom(style, "--C4", "13px");
    try expectCustom(style, "--C7", "13px");
    try expectCustom(style, "--B8", "7px");
}

test "a cycle on the child does not fall back to the parent's values (target10)" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "--varA: good; --varB: Also good; --varC: another good one" }});
    const style = try tree.element(&.{.{ .text = "--varA: var(--varB); --varB: var(--varA); --varC: var(--varB)" }});
    try expectCustom(style, "--varA", null);
    try expectCustom(style, "--varB", null);
    try expectCustom(style, "--varC", null);
}

test "a cycle across the parent is not one: the parent's value is computed already" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "--a: 1; --b: var(--a) 2" }});
    const child = try tree.element(&.{.{ .text = "--a: var(--b) 3" }});
    try expectCustom(child, "--a", "1 2 3");
    try expectCustom(child, "--b", "1 2");
}

fn environmentLookup(_: *const anyopaque, allocator: Allocator, name: []const u8, indices: []const u32) Allocator.Error!?[]u8 {
    if (std.mem.eql(u8, name, "test-inset") and indices.len == 0) return try allocator.dupe(u8, "4px");
    return null;
}
var environment_marker: u8 = 0;

test "env() in custom properties: the host's value, else the fallback" {
    var tree: Tree = .{ .allocator = testing.allocator, .environment = .{ .context = &environment_marker, .lookup = environmentLookup } };
    defer tree.deinit();
    const style = try tree.element(&.{.{ .text = "--a: env(test-inset); --b: env(unknown, 10px); --c: env(unknown); --d: env(unknown, /* comment */ 10px)" }});
    try expectCustom(style, "--a", "4px");
    try expectCustom(style, "--b", "10px");
    try expectCustom(style, "--c", null);
    try expectCustom(style, "--d", "10px");
    var plain: Tree = .{ .allocator = testing.allocator };
    defer plain.deinit();
    const undefined_env = try plain.element(&.{.{ .text = "--a: env(test-inset, 1px)" }});
    try expectCustom(undefined_env, "--a", "1px");
}

test "computed enumeration: valid values, after inheritance, in code-point order" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "--parent: p; --gone: g" }});
    const style = try tree.element(&.{.{ .text = "--b: 1; --a: 2; --gone: initial; --cyc: var(--cyc)" }});
    const names = try style.customNames(testing.allocator);
    defer testing.allocator.free(names);
    try testing.expectEqual(@as(usize, 3), names.len);
    try testing.expectEqualStrings("--a", names[0]);
    try testing.expectEqualStrings("--b", names[1]);
    try testing.expectEqualStrings("--parent", names[2]);
}

fn cascadeAll(allocator: Allocator) !void {
    var tree: Tree = .{ .allocator = allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "--a: 1; --n: --a; --p: x" }});
    _ = try tree.element(&.{
        .{ .text = "--r: ua", .origin = .user_agent },
        .{ .text = "--b: var(--a) 2; --c: var(var(--n), z); --x: var(--y); --y: var(--x); --r: revert; --z: var(--missing, inherit); --p: var(--q, initial)" },
    });
}

test "allocation failure leaks nothing through the custom phase" {
    try testing.checkAllAllocationFailures(testing.allocator, cascadeAll, .{});
}
