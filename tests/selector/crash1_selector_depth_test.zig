//! Lane crash1: selectors nested past Firefox 159's 75-nested-block bound.
//!
//! Crane crashed at 10,000 nested :is() (and :where/:not/:nth-child(of)/
//! :has(:is)): the parser recursed six frames per level, and every walker of
//! the selector tree after it. The user's ruling (2026-11-08): Firefox's
//! bound over the spec's unlimited depth - cssparser's
//! REASONABLE_NESTED_BLOCK_LIMIT (75; servo/rust-cssparser src/parser.rs
//! `parse_nested_block`). A function block (a functional pseudo-class or
//! pseudo-element) that would be the 76th open block makes the whole
//! selector invalid - Firefox leaves its ")" unmatched, so no forgiving list
//! recovers it - and an attribute selector there is an invalid item, which
//! :is()/:where() forgive. Every expectation is Firefox 159's, measured with
//! tmp/crash1/probe/boundary.html (2026-11-08).
const std = @import("std");
const selector = @import("selector");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn build(a: Allocator, open: []const u8, n: usize, middle: []const u8, close: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    for (0..n) |_| try out.appendSlice(a, open);
    try out.appendSlice(a, middle);
    for (0..n) |_| try out.appendSlice(a, close);
    return out.toOwnedSlice(a);
}

/// Whether `source` parses as a selector list (querySelector's parse).
fn valid(source: []const u8) !bool {
    var list = selector.parser.parseSelectorList(testing.allocator, source) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return false,
    };
    list.deinit();
    return true;
}

fn chainValid(open: []const u8, n: usize, middle: []const u8) !bool {
    const text = try build(testing.allocator, open, n, middle, ")");
    defer testing.allocator.free(text);
    return valid(text);
}

test "crash1: 75 nested :is() parse; the 76th makes the selector invalid" {
    try testing.expect(try chainValid(":is(", 75, "#t"));
    try testing.expect(!try chainValid(":is(", 76, "#t"));
}

test "crash1: 10,000 and 60,000 nested selectors are invalid, not a crash" {
    inline for (.{ ":is(", ":where(", ":not(", ":nth-child(1 of " }) |open| {
        for ([_]usize{ 10_000, 60_000 }) |n| try testing.expect(!try chainValid(open, n, "#t"));
    }
}

test "crash1: every functional pseudo-class counts one block, on the same 75/76 boundary" {
    inline for (.{ ":where(", ":not(", ":nth-child(1 of " }) |open| {
        try testing.expect(try chainValid(open, 75, "#t"));
        try testing.expect(!try chainValid(open, 76, "#t"));
    }
    // :nth-child(1) is a block of its own: 74 :is() + it = 75.
    try testing.expect(try chainValid(":is(", 74, ":nth-child(1)"));
    try testing.expect(!try chainValid(":is(", 75, ":nth-child(1)"));
    // :has() too: #t:has( + 74 :is() = 75 blocks.
    const a = testing.allocator;
    for ([_]usize{ 74, 75 }) |n| {
        const inner = try build(a, ":is(", n, "#c", ")");
        defer a.free(inner);
        const text = try std.mem.concat(a, u8, &.{ "#t:has(", inner, ")" });
        defer a.free(text);
        try testing.expectEqual(n == 74, try valid(text));
    }
}

test "crash1: a too-deep block is not forgiven by :is() or :where()" {
    const a = testing.allocator;
    const deep = try build(a, ":is(", 75, "#c", ")");
    defer a.free(deep);
    // ":is(#t, <75 more :is()>)" opens 76 blocks.
    const first = try std.mem.concat(a, u8, &.{ ":is(#t, ", deep, ")" });
    defer a.free(first);
    try testing.expect(!try valid(first));
    const last = try std.mem.concat(a, u8, &.{ ":is(", deep, ", #t)" });
    defer a.free(last);
    try testing.expect(!try valid(last));
    // A 76th block inside :not(:where()) pairs.
    const pairs = try build(a, ":not(:where(", 38, "#u", "))");
    defer a.free(pairs);
    try testing.expect(!try valid(pairs));
}

test "crash1: an attribute selector at the 76th block is an invalid item that :is() forgives" {
    // Firefox: ':is(' x 75 + '[id]' parses (querySelector returns null - the
    // innermost :is() is empty); ':is(' x 74 + '[id]' matches.
    try testing.expect(try chainValid(":is(", 74, "[id]"));
    try testing.expect(try chainValid(":is(", 75, "[id]"));
    // :not() forgives nothing, so the same item makes it invalid (follows
    // from the two measured cases; not probed on its own).
    try testing.expect(!try chainValid(":not(", 75, "[id]"));
}

test "crash1: selector() counts its own block (CSS.supports, @supports)" {
    const a = testing.allocator;
    // Firefox: CSS.supports('selector(' + ':is(' x 74 + '#t' + ...) is true,
    // x 75 false - selector( is the first block.
    for ([_]usize{ 74, 75 }) |n| {
        const text = try build(a, ":is(", n, "#t", ")");
        defer a.free(text);
        try testing.expectEqual(n == 74, try selector.parser.isSupported(a, text, .{}));
    }
}
