//! An arbitrary substitution function left open at the end of a
//! declaration list (CSSOM cssText, a style attribute) reads back as
//! authored, unclosed - integrator probe 1026b (tmp/analysis/
//! integrator-probes-1026b/RULINGS.md): Chrome 155 and Safari 27 give
//! "var(--x" for style.cssText = 'color: var(--x', setProperty and the IDL
//! attribute setter alike; Firefox 158 closes it. Golden rule 2: the
//! majority. A style SHEET's text keeps closing what EOF cuts off
//! (css-syntax/escaped-eof.html; vars1_original_text_test.zig).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectCssText(text: []const u8, expected: []const u8) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings(expected, out.items);
}

test "cssText: an unclosed var() or attr() at the end reads back as authored" {
    try expectCssText("color: var(--x", "color: var(--x;");
    // attr() reads the same once it is an arbitrary substitution function
    // (Codex row 122); here it is not one yet.
    try expectCssText("--y: var(--x", "--y: var(--x;");
    try expectCssText("margin: 1px var(--x", "margin: 1px var(--x;");
}

test "cssText: a closed value and one followed by another declaration are unchanged" {
    try expectCssText("color: var(--x); width: 1px", "color: var(--x); width: 1px;");
    try expectCssText("--y: var(--x)", "--y: var(--x);");
}
