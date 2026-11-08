//! Lane crash1: nested CSS rules past Firefox 159's 75-nested-block bound.
//!
//! Crane crashed at 1,000 nested rules (`&{`, @media, @supports, @layer,
//! @container, @scope alike): rules.zig consumeBlockContents <->
//! consumeQualified/consumeAtRule recursed once per level, and so did every
//! walker of the rule tree after it. The user's ruling (2026-11-08): Firefox's
//! bound over the spec's unlimited depth - cssparser's
//! REASONABLE_NESTED_BLOCK_LIMIT (75; servo/rust-cssparser src/parser.rs
//! `parse_nested_block`): a block that would be the 76th open one is not
//! entered - its rule is dropped and its contents are read by the enclosing
//! block - and a qualified rule whose prelude reaches past 75 open blocks
//! (the enclosing rule blocks included) is dropped with its block. Every
//! expectation below is Firefox 159's, measured with tmp/crash1/probe/
//! boundary.html (2026-11-08).
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Rule = css.rules.Rule;

fn repeated(a: Allocator, parts: []const []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    for (parts) |part| try out.appendSlice(a, part);
    return out.toOwnedSlice(a);
}

fn times(a: Allocator, unit: []const u8, n: usize) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    for (0..n) |_| try out.appendSlice(a, unit);
    return out.toOwnedSlice(a);
}

/// `:root{` + `&{` x (n - 1) + `inner` + `}` x n: n nested style rules.
fn ampChain(a: Allocator, n: usize, inner: []const u8) ![]u8 {
    const opens = try times(a, "&{", n - 1);
    defer a.free(opens);
    const closes = try times(a, "}", n);
    defer a.free(closes);
    return repeated(a, &.{ ":root{", opens, inner, closes });
}

/// The last rule child of `rule` (a nested rule, not a declaration run).
fn lastRuleChild(rule: *const Rule) ?*const Rule {
    var i = rule.children.len;
    while (i > 0) {
        i -= 1;
        if (rule.children[i].kind != .declarations) return &rule.children[i];
    }
    return null;
}

/// How many rules nest from `top` down its last rule child, and the deepest.
fn chain(top: *const Rule) struct { depth: usize, deepest: *const Rule } {
    var depth: usize = 1;
    var rule = top;
    while (lastRuleChild(rule)) |child| : (depth += 1) rule = child;
    return .{ .depth = depth, .deepest = rule };
}

fn hasDeclaration(rule: *const Rule, name: []const u8) bool {
    for (rule.declarations) |d| if (std.mem.eql(u8, d.name, name)) return true;
    return false;
}

test "crash1: 75 nested style rules are kept, with the innermost declarations" {
    const a = testing.allocator;
    const text = try ampChain(a, 75, "--p:1");
    defer a.free(text);
    var rules = try css.rules.parseStyleSheetContents(a, text);
    defer rules.deinit();
    try testing.expectEqual(@as(usize, 1), rules.items.len);
    const c = chain(&rules.items[0]);
    try testing.expectEqual(@as(usize, 75), c.depth);
    try testing.expect(hasDeclaration(c.deepest, "--p"));
}

test "crash1: the 76th nested rule is dropped and its declarations go to the 75th (Firefox 159)" {
    const a = testing.allocator;
    for ([_]usize{ 76, 77, 1_000, 60_000 }) |n| {
        const text = try ampChain(a, n, "--p:1");
        defer a.free(text);
        var rules = try css.rules.parseStyleSheetContents(a, text);
        defer rules.deinit();
        try testing.expectEqual(@as(usize, 1), rules.items.len);
        const c = chain(&rules.items[0]);
        try testing.expectEqual(@as(usize, 75), c.depth);
        try testing.expect(hasDeclaration(c.deepest, "--p"));
    }
}

test "crash1: past the bound, declarations before and after the dropped rule stay in order" {
    const a = testing.allocator;
    // ':root{' + '&{' x 74 + '--a:1; &{--p:1} --b:2' + '}' x 75: Firefox
    // keeps --a and --p in the 75th rule and --b in a nested declarations
    // rule after it, in the 74th.
    const text = try ampChain(a, 75, "--a:1; &{--p:1} --b:2");
    defer a.free(text);
    var rules = try css.rules.parseStyleSheetContents(a, text);
    defer rules.deinit();
    var parent: *const Rule = &rules.items[0];
    for (0..73) |_| parent = lastRuleChild(parent).?;
    // `parent` is the 74th rule: its children are the 75th rule, then --b.
    try testing.expectEqual(@as(usize, 2), parent.children.len);
    const seventy_fifth = &parent.children[0];
    try testing.expectEqual(Rule.Kind.qualified, seventy_fifth.kind);
    try testing.expect(hasDeclaration(seventy_fifth, "--a"));
    try testing.expect(hasDeclaration(seventy_fifth, "--p"));
    try testing.expectEqual(@as(usize, 0), seventy_fifth.children.len);
    try testing.expectEqual(Rule.Kind.declarations, parent.children[1].kind);
    try testing.expect(hasDeclaration(&parent.children[1], "--b"));
}

test "crash1: the closers left over past the bound end the outer rules; a rule after them is consumed with them" {
    const a = testing.allocator;
    // The dropped 76th block's "}" ends the 75th rule, so one "}" is left at
    // the top level: Firefox reads it as the prelude of the next rule
    // ("} :root"), which is then an invalid selector - only one rule stays
    // well formed.
    const chain_text = try ampChain(a, 76, "--p:1");
    defer a.free(chain_text);
    const text = try repeated(a, &.{ chain_text, " :root{--q:2}" });
    defer a.free(text);
    var rules = try css.rules.parseStyleSheetContents(a, text);
    defer rules.deinit();
    try testing.expectEqual(@as(usize, 2), rules.items.len);
    try testing.expectEqualStrings("} :root", rules.items[1].prelude);
}

test "crash1: insertRule's parse-a-rule of a 76-deep rule is a syntax error (Firefox 159: SyntaxError)" {
    const a = testing.allocator;
    const text = try ampChain(a, 76, "--p:1");
    defer a.free(text);
    try testing.expect((try css.rules.parseRule(a, text)) == null);
    const ok = try ampChain(a, 75, "--p:1");
    defer a.free(ok);
    var rule = (try css.rules.parseRule(a, ok)).?;
    rule.deinitOwned(a);
}

test "crash1: group rules nest to 75; the 76th block's rule is dropped, its contents read by the 75th" {
    const a = testing.allocator;
    inline for (.{ "@media all{", "@supports (color:red){", "@layer{", "@container (width >= 0px){", "@scope (:root){" }) |open| {
        for ([_]usize{ 74, 75, 1_000 }) |n| {
            const opens = try times(a, open, n);
            defer a.free(opens);
            const closes = try times(a, "}", n);
            defer a.free(closes);
            const text = try repeated(a, &.{ opens, ":root{--p:1}", closes });
            defer a.free(text);
            var rules = try css.rules.parseStyleSheetContents(a, text);
            defer rules.deinit();
            const c = chain(&rules.items[0]);
            if (n == 74) {
                // 74 group rules and the style rule: 75 blocks.
                try testing.expectEqual(@as(usize, 75), c.depth);
                try testing.expectEqual(Rule.Kind.qualified, c.deepest.kind);
            } else {
                // 75 group rules; the style rule's block is the 76th.
                try testing.expectEqual(@as(usize, 75), c.depth);
                try testing.expectEqual(Rule.Kind.at_rule, c.deepest.kind);
                // Its "--p:1" is read by the 75th group rule's block, as a
                // declaration run (which the rule model drops there).
                try testing.expectEqual(@as(usize, 1), c.deepest.children.len);
                try testing.expectEqual(Rule.Kind.declarations, c.deepest.children[0].kind);
            }
        }
    }
}

test "crash1: an at-rule block past the bound is dropped; its declarations join the 75th style rule" {
    const a = testing.allocator;
    inline for (.{ "@media all{--p:1}", "@font-face{font-family:x}" }) |inner| {
        const text = try ampChain(a, 75, inner);
        defer a.free(text);
        var rules = try css.rules.parseStyleSheetContents(a, text);
        defer rules.deinit();
        const c = chain(&rules.items[0]);
        try testing.expectEqual(@as(usize, 75), c.depth);
        try testing.expectEqual(Rule.Kind.qualified, c.deepest.kind);
        try testing.expectEqual(@as(usize, 0), c.deepest.children.len);
        try testing.expect(hasDeclaration(c.deepest, "--p") or hasDeclaration(c.deepest, "font-family"));
    }
}

test "crash1: a nested rule whose selector reaches past 75 open blocks is dropped with its block" {
    const a = testing.allocator;
    // Ten nested rules, then a selector of 65 or 66 nested :is(): Firefox
    // keeps the 65 (10 + 65 = 75 blocks) and drops the 66.
    for ([_]usize{ 65, 66 }) |n| {
        const outer = try times(a, ".y, :root{", 10);
        defer a.free(outer);
        const opens = try times(a, ":is(", n);
        defer a.free(opens);
        const parens = try times(a, ")", n);
        defer a.free(parens);
        const closes = try times(a, "}", 10);
        defer a.free(closes);
        const text = try repeated(a, &.{ outer, opens, ":root", parens, "{--p:1}", closes });
        defer a.free(text);
        var rules = try css.rules.parseStyleSheetContents(a, text);
        defer rules.deinit();
        const c = chain(&rules.items[0]);
        try testing.expectEqual(@as(usize, if (n == 65) 11 else 10), c.depth);
    }
    // At the top level the bound is the selector's own: 75 kept, 76 dropped.
    for ([_]usize{ 75, 76, 10_000 }) |n| {
        const opens = try times(a, ":is(", n);
        defer a.free(opens);
        const parens = try times(a, ")", n);
        defer a.free(parens);
        const text = try repeated(a, &.{ opens, ":root", parens, "{--p:1} b{c:d}" });
        defer a.free(text);
        var rules = try css.rules.parseStyleSheetContents(a, text);
        defer rules.deinit();
        try testing.expectEqual(@as(usize, if (n == 75) 2 else 1), rules.items.len);
    }
}

test "crash1: values keep their depth - the bound is for rules and selectors only" {
    const a = testing.allocator;
    // Chrome and Safari accept 10,000 nested parentheses in a custom
    // property; the ruling covers nesting of rules and selectors, so a
    // value deeper than 75 blocks still parses (anim1's explicit stack).
    const opens = try times(a, "(", 10_000);
    defer a.free(opens);
    const closes = try times(a, ")", 10_000);
    defer a.free(closes);
    const text = try repeated(a, &.{ ":root{--v:", opens, "x", closes, "}" });
    defer a.free(text);
    var rules = try css.rules.parseStyleSheetContents(a, text);
    defer rules.deinit();
    try testing.expect(hasDeclaration(&rules.items[0], "--v"));
}
