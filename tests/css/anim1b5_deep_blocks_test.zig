//! Lane anim1 batch 5 (crash fixed on main): simple blocks nested past any
//! native stack. WPT css/css-syntax/crashtests/unclosed-open-brackets.html
//! (crbug 41343497) sets a style attribute to `content: ` and 60,000 "(" -
//! one native frame per nesting level in rules.zig's consume-a-component-
//! value overflowed the stack (SIGSEGV in collectComponentValue). CSS
//! Syntax 3 5.5.9 "consume a simple block" has no depth limit, and Blink
//! (CSSTokenizer block_stack_) and Gecko (cssparser
//! consume_until_end_of_block) consume blocks over an explicit stack, so a
//! deep value parses - and is then simply invalid for `content`.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Far deeper than any native stack holds one frame per level.
const depth = 300_000;

fn repeated(allocator: Allocator, prefix: []const u8, unit: []const u8, n: usize, suffix: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, prefix);
    for (0..n) |_| try out.appendSlice(allocator, unit);
    try out.appendSlice(allocator, suffix);
    return out.toOwnedSlice(allocator);
}

test "anim1b5: a declaration list of 300,000 unclosed ( parses, as the crashtest's style attribute" {
    const a = testing.allocator;
    const text = try repeated(a, "content: ", "(", depth, "\";");
    defer a.free(text);
    const list = try css.rules.parseDeclarationList(a, text);
    defer css.rules.freeDeclarationList(a, list);
    try testing.expectEqual(@as(usize, 1), list.len);
    try testing.expectEqualStrings("content", list[0].name);
}

test "anim1b5: a style sheet whose rule holds 300,000 nested [ ends at EOF without a crash" {
    const a = testing.allocator;
    const text = try repeated(a, "a { color: red } b { x: ", "[", depth, "");
    defer a.free(text);
    var rules = try css.rules.parseStyleSheetContents(a, text);
    defer rules.deinit();
    try testing.expectEqual(@as(usize, 2), rules.items.len);
}

test "anim1b5: the @import pre-scan skips 300,000 nested {} blocks" {
    const a = testing.allocator;
    const text = try repeated(a, "@import url(first.css); a { b: ", "{", depth, "");
    defer a.free(text);
    const urls = try css.import_rules.importUrls(a, text);
    defer css.import_rules.freeUrls(a, urls);
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expectEqualStrings("first.css", urls[0]);
}

test "anim1b5: only the expected closing token ends a block; another kind inside is an ordinary token" {
    const a = testing.allocator;
    // The "]" inside "( ... )" does not end it (5.5.9), so the ";" after
    // ")" ends the first declaration and "b" is a second one.
    const list = try css.rules.parseDeclarationList(a, "a: ( ] [ { ) } ] ); b: c");
    defer css.rules.freeDeclarationList(a, list);
    try testing.expectEqual(@as(usize, 2), list.len);
    try testing.expectEqualStrings("a", list[0].name);
    try testing.expectEqualStrings("b", list[1].name);
    try testing.expectEqualStrings("c", list[1].value);
}

fn deepUnderAllocationFailure(a: Allocator) !void {
    const text = try repeated(a, "content: ", "(", 200, ";");
    defer a.free(text);
    const list = try css.rules.parseDeclarationList(a, text);
    defer css.rules.freeDeclarationList(a, list);
    const urls = try css.import_rules.importUrls(a, "@import 'x.css'; a { b: ((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((( }");
    css.import_rules.freeUrls(a, urls);
}

test "anim1b5: deep blocks under every allocation failure (the closer stack spills to the heap past 64)" {
    try testing.checkAllAllocationFailures(testing.allocator, deepUnderAllocationFailure, .{});
}
