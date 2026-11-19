//! Lane maj1: CSSOM 5.2 "serialize a selector" for what the parser
//! understood - combinators with one space around them, ", " between the
//! items of a selector list with no space inside its parentheses, an
//! attribute selector's value as a string and its modifier after a space, a
//! legacy one-colon pseudo-element with two colons, and a type or universal
//! selector without the namespace prefix the default namespace makes
//! redundant (the universal one dropped when the compound has more). The
//! expectations are what Chrome, Firefox and Safari return (wpt.fyi
//! 2358bd4835: css/cssom/serialize-namespaced-type-selectors.html,
//! CSSStyleRule-set-selectorText.html, selectorSerialize.html,
//! css/selectors/parsing/parse-*.html,
//! attribute-selectors/attribute-case/cssom.html). A forgiven invalid item
//! keeps its text (tests/selector/cp1_anb_serialization_test.zig).
const std = @import("std");
const selector = @import("selector");

fn expectText(input: []const u8, expected: []const u8) !void {
    try expectTextWith(input, expected, null);
}

const Namespaces = struct {
    default: ?[]const u8,

    fn resolve(context: ?*const anyopaque, prefix: []const u8) ?[]const u8 {
        _ = context;
        if (std.mem.eql(u8, prefix, "ns")) return "ns";
        if (std.mem.eql(u8, prefix, "nsdefault")) return "default_ns";
        return null;
    }
};

fn expectTextWith(input: []const u8, expected: []const u8, default_ns: ?[]const u8) !void {
    const a = std.testing.allocator;
    const resolver: ?selector.parser.NamespaceResolver = if (default_ns) |d| .{ .resolve = Namespaces.resolve, .default = d } else .{ .resolve = Namespaces.resolve };
    var result = try selector.parseCssomOwned(a, try a.dupe(u8, input), .{ .namespaces = resolver });
    defer a.free(result.text);
    defer result.selectors.deinit();
    if (!std.mem.eql(u8, expected, result.text)) std.debug.print("\"{s}\" serialized as \"{s}\"\n", .{ input, result.text });
    try std.testing.expectEqualStrings(expected, result.text);
}

test "combinators have one space on each side; descendant one space" {
    try expectText("div ol>li p", "div ol > li p");
    try expectText("a+b~c", "a + b ~ c");
    try expectText("a   b", "a b");
    try expectText(":has(>a)", ":has(> a)");
}

test "a selector list's items are separated by a comma and a space, trimmed" {
    try expectText(":is(ul,ol,.list) > [hidden]", ":is(ul, ol, .list) > [hidden]");
    try expectText(":where(:hover,:focus)", ":where(:hover, :focus)");
    try expectText(":not([disabled],[selected])", ":not([disabled], [selected])");
    try expectText(":is(div )", ":is(div)");
    try expectText(":not( abc )", ":not(abc)");
    try expectText(":is(,,,)", ":is(, , , )");
    try expectText(":host(:where(,,,))", ":host(:where(, , , ))");
    try expectText("a,b", "a, b");
}

test "a non-list argument is trimmed" {
    try expectText(":lang( ja )", ":lang(ja)");
}

test "an attribute selector's value is a string and its modifier follows a space" {
    try expectText("[att=val]", "[att=\"val\"]");
    try expectText("a[hreflang=fr]", "a[hreflang=\"fr\"]");
    try expectText("[att~=val]", "[att~=\"val\"]");
    try expectText("[att|=val]", "[att|=\"val\"]");
    try expectText("[att^=val]", "[att^=\"val\"]");
    try expectText("[att$=val]", "[att$=\"val\"]");
    try expectText("[att*=val]", "[att*=\"val\"]");
    try expectText("[foo=\"bar\"i]", "[foo=\"bar\" i]");
    try expectText("[foo=\"bar\"S]", "[foo=\"bar\" s]");
    try expectText("[ foo = \"bar\" ]", "[foo=\"bar\"]");
    try expectText("[|att]", "[att]");
    try expectText("[*|att]", "[*|att]");
    try expectText("[att=\"a\\\"b\"]", "[att=\"a\\\"b\"]");
}

test "a legacy one-colon pseudo-element serializes with two colons" {
    try expectText(":before", "::before");
    try expectText("p:first-line", "p::first-line");
    try expectText("::after", "::after");
}

test "the universal selector and the namespace prefix CSSOM leaves out" {
    // No default namespace.
    try expectText("*", "*");
    try expectText("*.c", ".c");
    try expectText("*#i", "#i");
    try expectText("*:hover", ":hover");
    try expectText("*::before", "::before");
    try expectText("*[attr]", "[attr]");
    try expectText("*|*", "*");
    try expectText("*|e", "e");
    try expectText("*|*.c", ".c");
    try expectText("*|e:hover", "e:hover");
    try expectText("|e", "|e");
    try expectText("|*.c", "|*.c");
    try expectText("ns|*.c", "ns|*.c");
    try expectText("ns|e", "ns|e");
    try expectText("*:not(:active)", ":not(:active)");
    try expectText(":not(*|*)", ":not(*)");
    try expectText("*|*:not(*)", ":not(*)");
    try expectText(":has(*|*)", ":has(*)");
    // With a default namespace.
    try expectTextWith("*|e", "*|e", "default_ns");
    try expectTextWith("*|*.c", "*|*.c", "default_ns");
    try expectTextWith("*.c", ".c", "default_ns");
    try expectTextWith("nsdefault|e", "e", "default_ns");
    try expectTextWith("nsdefault|*", "*", "default_ns");
    try expectTextWith("nsdefault|*.c", ".c", "default_ns");
    try expectTextWith("ns|e", "ns|e", "default_ns");
}

test "canonical selectors read back unchanged" {
    for ([_][]const u8{ "div", "a > b", ".a.b#c", "a:not(.b, .c)", "[a=\"b\" i]", "::slotted(span)", ":nth-child(2n+1 of .x)", "::view-transition-new(*.a)" }) |text| try expectText(text, text);
}
