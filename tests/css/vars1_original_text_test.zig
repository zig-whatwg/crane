//! A custom property's value, and a value with an arbitrary substitution
//! function, keep their ORIGINAL TEXT (lane vars1): CSS Syntax 3 "consume a
//! declaration" keeps a custom property's "original text", css-variables-1
//! §4.1 serializes specified values "exactly as specified by the author",
//! and every browser writes a pending-substitution value back as its source
//! (css/css-variables/variable-cssText.html target11). The segment runs from
//! the first to the last non-whitespace token: whitespace and comments at
//! either end are trimmed, `!important` is not part of it. Every other value
//! keeps the rule parser's serialization.
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const rules = css.rules;

fn expectValue(text: []const u8, index: usize, name: []const u8, value: []const u8, important: bool) !void {
    const declarations = try rules.parseDeclarationList(testing.allocator, text);
    defer rules.freeDeclarationList(testing.allocator, declarations);
    try testing.expect(index < declarations.len);
    try testing.expectEqualStrings(name, declarations[index].name);
    try testing.expectEqualStrings(value, declarations[index].value);
    try testing.expectEqual(important, declarations[index].important);
}

test "a custom property keeps its source text between its first and last tokens" {
    try expectValue("--x:  a   /* c */  b  ", 0, "--x", "a   /* c */  b", false);
    try expectValue("--x: value1  value2", 0, "--x", "value1  value2", false);
    try expectValue("--var:value ", 0, "--var", "value", false);
    try expectValue("--var:  value", 0, "--var", "value", false);
    try expectValue("--uuid: 12345678-12e3-8d9b-a456-426614174000", 0, "--uuid", "12345678-12e3-8d9b-a456-426614174000", false);
    try expectValue("--u: url(path/to/image.png?q=1&v=2#frag)", 0, "--u", "url(path/to/image.png?q=1&v=2#frag)", false);
    try expectValue("--u: url(~icons+set!v2)", 0, "--u", "url(~icons+set!v2)", false);
    try expectValue("--s: 'a  b'  \"c\"", 0, "--s", "'a  b'  \"c\"", false);
    try expectValue("--Case: MiXeD", 0, "--Case", "MiXeD", false);
    try expectValue("--b: { a; b }", 0, "--b", "{ a; b }", false);
    try expectValue("--x: /* lead */ a /* trail */", 0, "--x", "a", false);
}

test "an empty custom property is an empty value" {
    try expectValue("--x:;", 0, "--x", "", false);
    try expectValue("--x: ;", 0, "--x", "", false);
    try expectValue("--x:  /* c */  ;", 0, "--x", "", false);
}

test "!important is taken off before the segment is cut" {
    try expectValue("--var:value1 !important;", 0, "--var", "value1", true);
    try expectValue("--var:value1!important;--var:value2;", 0, "--var", "value1", true);
    try expectValue("--var: a  b  ! important", 0, "--var", "a  b", true);
}

test "a standard property with var() or env() keeps its source text" {
    try expectValue(
        "color: /* comment that must not be preserved */ var(--prop)  /* kept comment */ var(--prop); /* another stripped comment */ /* indeed */ ",
        0,
        "color",
        "var(--prop)  /* kept comment */ var(--prop)",
        false,
    );
    try expectValue("margin:  var(--a)   1px  !important", 0, "margin", "var(--a)   1px", true);
    try expectValue("width: calc( 1px  +  env(test) )", 0, "width", "calc( 1px  +  env(test) )", false);
    try expectValue("font-family: random-item(--k,  a, b)", 0, "font-family", "random-item(--k,  a, b)", false);
}

test "every other value keeps the rule parser's serialization" {
    try expectValue("color:  red  /* c */", 0, "color", "red", false);
    try expectValue("margin: 1px    2px", 0, "margin", "1px 2px", false);
    try expectValue("background: url( a.png )", 0, "background", "url(\"a.png\")", false);
    try expectValue("content: 'var(--x)'", 0, "content", "\"var(--x)\"", false);
}

test "style rules keep the original text too" {
    var sheet = try rules.parseStyleSheetContents(testing.allocator, "p { --x:  1  2 ; color: var(--x)  ; } @keyframes k { to { --y:  a  b; width:  var(--y) } }");
    defer sheet.deinit();
    const p = sheet.items[0];
    try testing.expectEqualStrings("1  2", p.declarations[0].value);
    try testing.expectEqualStrings("var(--x)", p.declarations[1].value);
    const frame = sheet.items[1].children[0];
    try testing.expectEqualStrings("a  b", frame.declarations[0].value);
    try testing.expectEqualStrings("var(--y)", frame.declarations[1].value);
}

test "a name is still decoded" {
    try expectValue("--\\78:  a  ", 0, "--x", "a", false);
}

fn parseAll(allocator: std.mem.Allocator) !void {
    const declarations = try rules.parseDeclarationList(allocator, "--x:  a /* c */ b; color: var(--x)  !important; width: 1px; --y: url(a b)");
    rules.freeDeclarationList(allocator, declarations);
    var sheet = try rules.parseStyleSheetContents(allocator, "p { --x: 1  2; margin: var(--x) }");
    sheet.deinit();
}

test "allocation failure frees what was taken" {
    try testing.checkAllAllocationFailures(testing.allocator, parseAll, .{});
}

test "a value cut off by the end of the sheet: escaped EOF is U+FFFD, open strings, urls and blocks close (escaped-eof.html)" {
    // Chrome 156 and Safari 27 pass css/css-syntax/escaped-eof.html; Firefox
    // 158 does not (golden rule 2: the majority). The tokens say the same:
    // an escaped EOF is U+FFFD, EOF ends a string, a url and every block.
    var sheet = try rules.parseStyleSheetContents(testing.allocator, "foo { --foo:foo\\");
    defer sheet.deinit();
    try testing.expectEqualStrings("foo\u{FFFD}", sheet.items[0].declarations[0].value);
    for ([_][2][]const u8{
        .{ "foo { --foo:1foo\\", "1foo\u{FFFD}" },
        .{ "foo { --foo:url(foo\\", "url(foo\u{FFFD})" },
        .{ "foo { --foo:\"foo\\", "\"foo\"" },
        .{ "foo { --foo:'a b", "'a b'" },
        .{ "foo { --foo:f(a [b {c", "f(a [b {c}])" },
        .{ "foo { --foo:var(--x, 1px", "var(--x, 1px)" },
        // Not at the end of the sheet: as written (the escape's space is
        // part of its token).
        .{ "foo { --foo:a\\62  b }", "a\\62  b" },
    }) |case| {
        var other = try rules.parseStyleSheetContents(testing.allocator, case[0]);
        defer other.deinit();
        try testing.expectEqualStrings(case[1], other.items[0].declarations[0].value);
    }
    // A style attribute ends at its own end: the same rule - except that a
    // pending value there keeps its authored text, unclosed (integrator
    // probe 1026b: Chrome and Safari read cssText 'color: var(--x' back as
    // "var(--x"; vars2_cssText_eof_test.zig).
    try expectValue("--x: a\\", 0, "--x", "a\u{FFFD}", false);
    try expectValue("color: var(--x", 0, "color", "var(--x", false);
}
