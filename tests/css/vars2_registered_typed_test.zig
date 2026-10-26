//! Registered custom properties' typed computed values (lane vars1b2;
//! CSS Properties and Values API 1 §2.4, §2.5; Values 5 "Invalid
//! Substitution"; design sections 4.2-5): the substituted value is parsed
//! against the registration's syntax and computed, var() substitutes the
//! computed value, a value that does not match is invalid at computed-value
//! time (unset: inherited or initial), and font-relative units make
//! font-size/line-height a dependency - a cycle when font-size refers back
//! (cases from css-properties-values-api/registered-property-computation,
//! var-reference-registered-properties and unit-cycles).
const std = @import("std");
const css = @import("css");
const support = @import("vars2_support.zig");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const Tree = support.Tree;
const expectCustom = support.expectCustom;

const defs = [_]support.Def{
    .{ .name = "--len", .syntax = "<length>", .inherits = false, .initial = "0px" },
    .{ .name = "--inh", .syntax = "<length>", .inherits = true, .initial = "0px" },
    .{ .name = "--angle", .syntax = "<angle>", .inherits = false, .initial = "0deg" },
    .{ .name = "--color", .syntax = "<color>", .inherits = false, .initial = "black" },
    .{ .name = "--list", .syntax = "<length>+", .inherits = false, .initial = "0px" },
    .{ .name = "--any", .syntax = "*", .inherits = false, .initial = "x" },
};

fn tree(allocator: Allocator) !Tree {
    return .{ .allocator = allocator, .registered = try support.snapshotOf(allocator, .{}, &defs) };
}

fn endTree(t: *Tree) void {
    t.deinit();
    if (t.registered) |r| r.release();
}

fn expectLonghand(style: *const css.computed_style.ComputedStyle, l: css.properties.Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "a registered value is parsed against its syntax and computed" {
    var t = try tree(testing.allocator);
    defer endTree(&t);
    const root = try t.element("font-size: 10px; --len: calc(1px + 2em); --angle: 0.5turn; --color: red; --list: 1em 2px; --any: 2em  y");
    try expectCustom(root, "--len", "21px");
    try expectCustom(root, "--angle", "180deg");
    try expectCustom(root, "--color", "rgb(255, 0, 0)");
    try expectCustom(root, "--list", "10px 2px");
    // The universal syntax keeps the substituted tokens.
    try expectCustom(root, "--any", "2em  y");
}

test "var() of a registered property substitutes its computed value" {
    var t = try tree(testing.allocator);
    defer endTree(&t);
    _ = try t.element("font-size: 20px");
    const child = try t.element("font-size: 10px; --len: 10em; --u: var(--len); --any: var(--len); margin-bottom: var(--len)");
    try expectCustom(child, "--u", "100px");
    // Values are absolutized when substituting into the universal syntax.
    try expectCustom(child, "--any", "100px");
    try expectLonghand(child, .margin_bottom, "100px");
}

test "a value that does not match its syntax is invalid at computed-value time: unset" {
    var t = try tree(testing.allocator);
    defer endTree(&t);
    _ = try t.element("--inh: 30px; --len: 40px");
    const child = try t.element("--len: red; --inh: red; --u: var(--len)");
    // Not inherited: the initial value; inherited: the parent's.
    try expectCustom(child, "--len", "0px");
    try expectCustom(child, "--inh", "30px");
    // var() of it reads that value (all three browsers: "0px"; the WPT
    // expectation of "" in var-reference-registered-properties.html fails
    // in Chrome, Firefox and Safari alike).
    try expectCustom(child, "--u", "0px");
    // A failed substitution is invalid at computed-value time too.
    const grandchild = try t.element("--inh: var(--missing); --len: var(--missing)");
    try expectCustom(grandchild, "--inh", "30px");
    try expectCustom(grandchild, "--len", "0px");
}

test "font-size referring to an em-dependent registered property is a cycle: both unset" {
    var t = try tree(testing.allocator);
    defer endTree(&t);
    _ = try t.element("font-size: 20px; --inh: 7px");
    const child = try t.element("--len: 2em; --inh: 3em; font-size: var(--len, 42px); line-height: 13px");
    // font-size is unset (inherited: 20px), and no fallback is taken.
    try expectLonghand(child, .font_size, "20px");
    try expectCustom(child, "--len", "0px");
    // --inh is inherited: the cycle leaves the parent's value (here the
    // previous element's, 3em computed at 20px).
    try expectCustom(child, "--inh", "60px");
    const other = try t.element("--inh: 3em; font-size: var(--inh)");
    try expectLonghand(other, .font_size, "20px");
    try expectCustom(other, "--inh", "60px");
}

test "an em-dependent registered property not referred to by font-size uses the element's font-size" {
    var t = try tree(testing.allocator);
    defer endTree(&t);
    _ = try t.element("font-size: 20px");
    const child = try t.element("--len: 2em; font-size: 11px");
    try expectCustom(child, "--len", "22px");
    // A px value is no dependency.
    const px = try t.element("--len: 42px; font-size: var(--len)");
    try expectLonghand(px, .font_size, "42px");
    try expectCustom(px, "--len", "42px");
}

test "rem: a dependency of font-size only on the root element" {
    var t = try tree(testing.allocator);
    defer endTree(&t);
    const root = try t.element("--len: 2rem; font-size: var(--len)");
    try expectLonghand(root, .font_size, "16px");
    try expectCustom(root, "--len", "0px");
    const child = try t.element("--len: 2rem; font-size: var(--len)");
    try expectLonghand(child, .font_size, "32px");
    try expectCustom(child, "--len", "32px");
}

test "lh: line-height referring to an lh-dependent registered property is a cycle" {
    var t = try tree(testing.allocator);
    defer endTree(&t);
    _ = try t.element("font-size: 10px");
    const child = try t.element("--len: 2lh; line-height: var(--len)");
    try expectLonghand(child, .line_height, "normal");
    try expectCustom(child, "--len", "0px");
    const lh = try t.element("--len: 2lh; line-height: 13px");
    try expectCustom(lh, "--len", "26px");
    // font-size referring to lh is a cycle too (lh depends on font-size).
    const via_font = try t.element("--len: 2lh; font-size: var(--len)");
    try expectCustom(via_font, "--len", "0px");
}

test "a cycle through an unregistered property: every participant is invalid" {
    var t = try tree(testing.allocator);
    defer endTree(&t);
    _ = try t.element("font-size: 20px");
    const child = try t.element("--u: 10em; --len: var(--u); font-size: var(--len)");
    try expectLonghand(child, .font_size, "20px");
    try expectCustom(child, "--len", "0px");
    // --u itself does not depend on font-size: it keeps its tokens.
    try expectCustom(child, "--u", "10em");
}

fn typedUnderOom(allocator: Allocator) !void {
    var t = try tree(allocator);
    defer endTree(&t);
    _ = try t.element("font-size: 20px; --inh: 3px");
    const child = try t.element("--len: calc(1px + 2em); --u: var(--len); --inh: red; --list: 1em 2px; --color: red; font-size: var(--len)");
    _ = child;
}

test "typed computation survives every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, typedUnderOom, .{});
}
