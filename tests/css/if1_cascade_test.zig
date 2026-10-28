//! if() with the actual cascade Host: ordinary custom-property lookup, cycle
//! marking, computed query operands and real var()/env() substitution.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn compute(allocator: std.mem.Allocator, text: []const u8, parent: ?*const css.computed_style.ComputedStyle) !*css.computed_style.ComputedStyle {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent, .is_root = parent == null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn check(text: []const u8, expected: ?[]const u8) !void {
    const style = try compute(testing.allocator, text, null);
    defer style.destroy();
    const got = style.customValue("--result");
    if (expected) |value| {
        try testing.expect(got != null);
        try testing.expectEqualStrings(value, got.?.bytes);
    } else try testing.expect(got == null);
}

test "if cascade: normal property guard marks self-query and visited value cycles" {
    try check("--result: if(style(--result): no; else:yes)", null);
    try check("--result: if(not style(--result): yes; else:no)", null);
    try check("--x: x; --result: if(style(not (--x: var(--result))):yes;else:no)", null);
    try check("--x: x; --result: if(style(not (--x: var(--missing))):yes;else:no)", "yes");
    try check("--x: x; --result: if(style((--x) or (--x: var(--result))):yes;else:no)", "yes");
    try check("--x: x; --result: if(style((--missing) and (--x:var(--result))):no;else:yes)", "yes");
}

test "if cascade: missing initial query differs from failed substitution (Q10)" {
    try check("--result: if(style(--missing: initial):yes;else:no)", "yes");
    try check("--result: if(style(--missing: var(--invalid)):no;else:yes)", "yes");
    try check("--x: x; --result: if(style(--x: initial):no;else:yes)", "yes");
    try check("--result: if(style(--missing:revert):no;else:yes)", "yes");
}

test "if cascade: plain computed custom values and numeric dimensions use Host" {
    try check("--x: red  blue; --result: if(style(--x:red blue):yes;else:no)", "yes");
    try check("--x: 2em; --result: if(style(--x = 32px):yes;else:no)", "yes");
    try check("--x: 1turn; --result: if(style(--x = 360deg):yes;else:no)", "yes");
    try check("--x: 1000ms; --result: if(style(--x = 1s):yes;else:no)", "yes");
    try check("--result: if(style(1khz = 1000hz):yes;else:no)", "yes");
    try check("--result: if(style(96dpi = 1dppx):yes;else:no)", "yes");
    try check("--result: if(style(20% < 30%):yes;else:no)", "yes");
    try check("--result: if(style(0 = 0px):yes;else:no)", "yes");
    try check("--result: if(style(0 = 0deg):no;else:yes)", "yes");
}

test "if cascade: actual media, supports and env fallback" {
    try check("--result: if(media(width > 10px):yes;else:no)", "yes");
    try check("--result: if(supports(color:red):yes;else:no)", "yes");
    try check("--result: if(not supports(nonsense):no;else:yes)", "yes");
    try check("--result: if(env(if1-undefined,else):var(--missing,yes);else:no)", "yes");
}
