//! var() and env() in longhands and shorthands (lane vars1): a value with
//! an arbitrary substitution function is valid at parse time and pending
//! (Values 5 "Resolving in Properties"); at computed-value time it is
//! substituted and parsed with the property's grammar, and a failure is
//! invalid at computed-value time - unset, not the cascade's previous
//! value ("Invalid Substitution"). A shorthand's pending value is
//! substituted once and distributed to its longhands. Declaration blocks
//! read a pending longhand as its text and one set by a shorthand as ""
//! ("Substitution in Shorthand Properties"). Cases from css/css-variables/
//! variable-substitution-basic.html, -shorthands.html, variable-cssText.html,
//! revert-in-fallback.html and variable-reference.html.
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const cascade_mod = css.cascade;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const Longhand = css.properties.Longhand;

const Sheet = struct {
    text: []const u8,
    origin: cascade_mod.Origin = .author,
    layer: u16 = cascade_mod.unlayered,
    order: u32 = 0,
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
        for (sheets, blocks.items) |sheet, *block| try matched.append(self.allocator, .{ .block = block, .source = .{ .origin = sheet.origin, .layer = sheet.layer, .order = sheet.order } });
        const parent: ?*const ComputedStyle = if (self.styles.items.len == 0) null else self.styles.items[self.styles.items.len - 1];
        try self.styles.ensureUnusedCapacity(self.allocator, 1);
        const style = try cascade_mod.cascade(.{ .allocator = self.allocator, .parent = parent, .is_root = parent == null, .environment = self.environment }, matched.items);
        self.styles.appendAssumeCapacity(style);
        return style;
    }
};

fn expectResolved(style: *const ComputedStyle, l: Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("{s}\n", .{l.name()});
        return err;
    };
}

test "var() substitutes into a longhand and parses with its grammar" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    const style = try tree.element(&.{.{ .text = "--a: 10px; --c: rgb(0, 128, 0); --n: --a; width: var(--a); height: calc(var(--a) * 2 + 1px); color: var(--c); min-width: var(var(--n)); max-width: var(--missing, 7px)" }});
    try expectResolved(style, .width, "10px");
    try expectResolved(style, .height, "21px");
    try expectResolved(style, .color, "rgb(0, 128, 0)");
    try expectResolved(style, .min_width, "10px");
    try expectResolved(style, .max_width, "7px");
}

test "an invalid substitution is invalid at computed-value time: unset, not the earlier declaration" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "color: rgb(255, 0, 0); --not-a-color: 20px; --gap: 20" }});
    const style = try tree.element(&.{
        .{ .text = "background-color: rgb(255, 0, 0); width: 5px; color: blue", .order = 1 },
        .{ .text = "background-color: var(--not-a-color); width: var(--undefined); color: var(--not-a-color); height: var(--gap)px; margin-left: var(--gap) px", .order = 2 },
    });
    // Non-inherited: the initial value.
    try expectResolved(style, .background_color, "rgba(0, 0, 0, 0)");
    try expectResolved(style, .width, "auto");
    // Inherited: the parent's value.
    try expectResolved(style, .color, "rgb(255, 0, 0)");
    // Substitution is at token boundaries: `20` and `px` stay two tokens.
    try expectResolved(style, .height, "auto");
    try expectResolved(style, .margin_left, "0px");
}

test "a shorthand's pending value substitutes once into every longhand" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    const style = try tree.element(&.{.{ .text = "--m: 1px 2px 3px 4px; --bad: red; margin: var(--m); padding: var(--bad); border-top: var(--b, 2px solid rgb(0, 0, 255))" }});
    try expectResolved(style, .margin_top, "1px");
    try expectResolved(style, .margin_right, "2px");
    try expectResolved(style, .margin_bottom, "3px");
    try expectResolved(style, .margin_left, "4px");
    try expectResolved(style, .padding_top, "0px");
    try expectResolved(style, .padding_left, "0px");
    try expectResolved(style, .border_top_width, "2px");
    try expectResolved(style, .border_top_style, "solid");
    try expectResolved(style, .border_top_color, "rgb(0, 0, 255)");
}

test "a later longhand overrides one longhand of a var() shorthand, the others stay pending (Q207 2a)" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    const style = try tree.element(&.{.{ .text = "--m: 5px; margin: var(--m); margin-top: 10px" }});
    try expectResolved(style, .margin_top, "10px");
    try expectResolved(style, .margin_right, "5px");
    try expectResolved(style, .margin_left, "5px");
}

test "the winning pending value crosses blocks like any declaration (Q224)" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    const style = try tree.element(&.{
        .{ .text = "margin-top: 3px; --m: 9px", .order = 1 },
        .{ .text = "margin: var(--m)", .order = 2 },
        .{ .text = "padding: 4px", .order = 3 },
        .{ .text = "padding-left: var(--missing)", .order = 4 },
    });
    try expectResolved(style, .margin_top, "9px");
    try expectResolved(style, .padding_top, "4px");
    try expectResolved(style, .padding_left, "0px");
}

test "high-priority longhands substitute too: font-size feeds em, color feeds currentcolor" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    const style = try tree.element(&.{.{ .text = "--fs: 20px; --c: rgb(0, 0, 255); --wm: vertical-rl; font-size: var(--fs); width: 2em; color: var(--c); border-top-color: currentcolor; writing-mode: var(--wm); margin-inline-start: var(--fs)" }});
    try expectResolved(style, .font_size, "20px");
    try expectResolved(style, .width, "40px");
    try expectResolved(style, .border_top_color, "rgb(0, 0, 255)");
    try expectResolved(style, .writing_mode, "vertical-rl");
    // margin-inline-start maps to margin-top in vertical-rl, ltr.
    try expectResolved(style, .margin_top, "20px");
}

test "a CSS-wide keyword from a fallback is that keyword, revert included (revert-in-fallback.html)" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "color: rgb(255, 0, 0)" }});
    const style = try tree.element(&.{
        .{ .text = "color: rgb(0, 0, 255); display: block", .origin = .user_agent },
        .{ .text = "width: 5px", .layer = 0, .order = 1 },
        .{ .text = "width: var(--undefined, revert-layer)", .layer = 1, .order = 2 },
        .{ .text = "color: var(--undefined, revert); display: var(--undefined, initial); margin-left: var(--undefined, inherit)", .order = 3 },
    });
    try expectResolved(style, .color, "rgb(0, 0, 255)");
    try expectResolved(style, .display, "inline");
    try expectResolved(style, .width, "5px");
    try expectResolved(style, .margin_left, "0px");
}

fn environmentLookup(_: *const anyopaque, allocator: Allocator, name: []const u8, indices: []const u32) Allocator.Error!?[]u8 {
    if (std.mem.eql(u8, name, "test-inset") and indices.len == 0) return try allocator.dupe(u8, "4px");
    return null;
}
var environment_marker: u8 = 0;

test "env() in longhands: the host's value, the fallback, else unset" {
    var tree: Tree = .{ .allocator = testing.allocator, .environment = .{ .context = &environment_marker, .lookup = environmentLookup } };
    defer tree.deinit();
    const style = try tree.element(&.{.{ .text = "width: env(test-inset); height: env(unknown, 6px); min-width: env(unknown); padding: env(test-inset) 1px" }});
    try expectResolved(style, .width, "4px");
    try expectResolved(style, .height, "6px");
    try expectResolved(style, .min_width, "auto");
    try expectResolved(style, .padding_top, "4px");
    try expectResolved(style, .padding_right, "1px");
}

fn expectValue(block: *const DeclarationBlock, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue(name, &out);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("{s}\n", .{name});
        return err;
    };
}

fn expectCssText(text: []const u8, expected: []const u8) !void {
    var block = try DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings(expected, out.items);
}

test "declaration blocks read pending values as Values 5 Appendix A says (variable-cssText.html)" {
    try expectCssText("margin: var(--prop);", "margin: var(--prop);");
    try expectCssText("background: var(--prop);", "background: var(--prop);");
    try expectCssText("margin: var(--prop) !important;", "margin: var(--prop) !important;");
    try expectCssText("background: var(--prop); background: green;", "background: green;");
    try expectCssText("background: green; background: var(--prop);", "background: var(--prop);");
    try expectCssText("color: green; color: var(--prop);", "color: var(--prop);");
    try expectCssText("margin: var(--prop); margin-top: 10px", "margin-right: ; margin-bottom: ; margin-left: ; margin-top: 10px;");
    try expectCssText("color: /* comment that must not be preserved */ var(--prop)  /* kept comment */ var(--prop); /* another stripped comment */ /* indeed */ ", "color: var(--prop)  /* kept comment */ var(--prop);");
    var block = try DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin: var(--m); width: calc(var(--w) + 1px)");
    defer block.deinit();
    try expectValue(&block, "margin", "var(--m)");
    try expectValue(&block, "margin-top", "");
    try expectValue(&block, "width", "calc(var(--w) + 1px)");
}

test "var() and env() are valid at parse time in every recognized longhand and shorthand" {
    // Generic over the property table: no per-property list. Every
    // supported property accepts a valid var() value, and rejects an invalid
    // one (var-parsing.html's test_invalid_value names).
    // The unrolled loops grow with the property table; Codex rows 124/125's
    // properties pass Zig's default 1,000-branch comptime quota.
    @setEvalBranchQuota(100_000);
    inline for (@typeInfo(Longhand).@"enum".field_values) |field_value| {
        const l: Longhand = @fromBackingInt(@intCast(field_value));
        var list: std.ArrayList(css.properties.Assignment) = .empty;
        defer list.deinit(testing.allocator);
        try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = l }, "var(--x)", &list));
        for (list.items) |a| a.value.release();
        list.clearRetainingCapacity();
        try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = l }, "env(safe-area-inset-top, 1px)", &list));
        for (list.items) |a| a.value.release();
        list.clearRetainingCapacity();
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = l }, "var()", &list));
    }
    inline for (@typeInfo(css.properties.Shorthand).@"enum".field_values) |field_value| {
        const s: css.properties.Shorthand = @fromBackingInt(@intCast(field_value));
        var list: std.ArrayList(css.properties.Assignment) = .empty;
        defer list.deinit(testing.allocator);
        try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .shorthand = s }, "var(--x) var(--y)", &list));
        try testing.expectEqual(s.longhands().len, list.items.len);
        for (list.items) |a| a.value.release();
    }
}

fn cascadeAll(allocator: Allocator) !void {
    var tree: Tree = .{ .allocator = allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "--m: 1px 2px; --c: red; color: var(--c)" }});
    _ = try tree.element(&.{.{ .text = "margin: var(--m); width: calc(var(--x, 3px) * 2); border: var(--b, 1px solid); color: var(--m); padding: var(--undefined, 4px) 5px" }});
}

test "allocation failure leaks nothing through substitution into longhands" {
    try testing.checkAllAllocationFailures(testing.allocator, cascadeAll, .{});
}

test "revert-rule rolls back to the cascade without the current rule (Cascade 5 7.3.6; revert-rule-in-fallback.html)" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    // Chrome 156 and Safari 27 pass revert-rule-in-fallback.html.
    const style = try tree.element(&.{
        .{ .text = "width: 1px; margin: 1px; --x: earlier; height: 2px", .order = 1 },
        .{ .text = "width: var(--unknown, revert-rule); margin: var(--unknown, revert-rule); --x: var(--unknown, revert-rule); height: revert-rule", .order = 2 },
    });
    try expectResolved(style, .width, "1px");
    try expectResolved(style, .margin_top, "1px");
    try expectResolved(style, .margin_left, "1px");
    try expectResolved(style, .height, "2px");
    try testing.expectEqualStrings("earlier", style.customValue("--x").?.bytes);
}

test "revert-rule with no earlier rule is the default" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element(&.{.{ .text = "color: rgb(1, 2, 3)" }});
    const style = try tree.element(&.{.{ .text = "width: revert-rule; color: revert-rule", .order = 1 }});
    try expectResolved(style, .width, "auto");
    try expectResolved(style, .color, "rgb(1, 2, 3)");
}
