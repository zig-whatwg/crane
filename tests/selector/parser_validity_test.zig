//! Which selector strings are valid: Selectors 4 16 over CSS Syntax 3 tokens,
//! "parse a selector" (17.1). querySelector and matches() throw SyntaxError
//! for exactly the invalid ones, so each line here is a WPT dom/nodes case
//! (selectors.js, ParentNode-querySelector-escapes,
//! -namespace-tagname-attribute, Element-matches-namespaced-elements,
//! -host-pseudo-class, -case-insensitive-attribute-flag) or a rule they rest
//! on, grouped by construct.

const std = @import("std");
const selector = @import("selector");

fn isValid(input: []const u8) !bool {
    var tokenizer = selector.Tokenizer.init(std.testing.allocator, input);
    var parser = selector.Parser.init(std.testing.allocator, &tokenizer) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return false,
    };
    defer parser.deinit();
    var list = parser.parse() catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return false,
    };
    list.deinit();
    return true;
}

fn expectAll(expected: bool, inputs: []const []const u8) !void {
    var wrong: usize = 0;
    for (inputs) |input| {
        if (try isValid(input) != expected) {
            std.debug.print("expected {s}: \"{s}\"\n", .{ if (expected) "valid" else "invalid", input });
            wrong += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), wrong);
}

test "namespace prefixes: *| and | are valid, any named prefix is undeclared" {
    try expectAll(true, &.{ "*|div", "|div", "*|*", "|*", "#no-namespace |div", "#any-namespace *|div", "#no-namespace |*", ":not(*|*)", "[*|title]", "[*|TiTlE]", "[|title]", "*|coreProperties", ":is(cp|coreProperties)", ":is([xml|lang])", "[foo|=bar]" });
    try expectAll(false, &.{ "ns|div", ":not(ns|div)", "cp|coreProperties", "[xml|lang]", "^|div", "$|div", "[*=test]", "[*|*=test]", "*|", "|", "div|", "[|]" });
}

test "CSS escapes in ids, classes and attribute values" {
    try expectAll(true, &.{ "#\\30 nextIsWhiteSpace", "#\\30nextIsNotHexLetters", "#\\000030connectHexMoreThan6Hex", "#zero\\0", "#\\d83d surrogateFirst", "#outOfRange\\110030", "#eof\\", "#\\.comma", "#\\-minus", "#\\g", "#\\61 BMPRegular", "#spac\\65\r\ns", "#te\\s\\t", "#spaces\\ in\\\tident", "#\\.\\,\\:\\!", "#\\00DFFFsurrogate", "#-\\6d", "#\x00", "#ab\x00c", ".foo\\:bar", ".test\\.foo\\[5\\]bar", "#\\#foo\\:bar", "#test\\.foo\\[5\\]bar", "[data-attr-value=\"\\e9\"]", "[data-attr-whitespace~=\"\\0000e9\"]", "#--", "#--11", "#\u{2003}", "#\u{A0}" });
    try expectAll(false, &.{ "#", "#5cm", "#-5", ".5cm", "#a\\\nb" });
}

test "An+B: CSS Syntax 3 6.2 over tokens" {
    try expectAll(true, &.{ ":nth-child(4n-1)", ":nth-last-child(4n-1)", "span:nth-of-type(2n-1)", "span:nth-last-of-type(2n-1)", ":nth-child(4n \t\n- \t\n1)", ":nth-child(odd)", ":nth-child(EVEN)", ":nth-child(n)", ":nth-child(+n)", ":nth-child(-n+3)", ":nth-child(-n + 3)", ":nth-child(N- 1)", ":nth-child(-n- 1)", ":nth-child(2n -1)", ":nth-child(2n+0)", ":nth-child(+5)", ":nth-child(-5)", ":nth-child( 3 )", ":nth-child(-n-3)", ":nth-child(n-3)", ":nth-child(2 of .a, .b)", ":nth-child(1 of :nth-child(2))" });
    try expectAll(false, &.{ ":nth-child(3 n)", ":nth-child(+ 2n)", ":nth-child(+ 2)", ":nth-child(3n + -6)", ":nth-child(2.5)", ":nth-child(2px)", ":nth-child()", ":nth-child(2 of)", ":nth-child(2 of ::before)", ":nth-of-type(2 of .a)", ":nth-child(n- -1)", ":nth-child(--n)" });
}

test "attribute selectors: whitespace between the parts, case modifiers in any case" {
    try expectAll(true, &.{ "#attr-begins [class^= apple]", "#attr-contains [class*= apple]", "#attr-contains [class*= banana ]", "[ title ]", "[title = 'x' i ]", "div[class=CasE I]", "div[class=CasE i]", "[a=b s]", "[a=b S]", "[class^=\"\"]" });
    try expectAll(false, &.{ "[class= space unquoted ]", "[a=b c]", "[a=b i s]", "[a|=]", "[a = ]", "[a ^ = b]", "[5]", "[a='b' 'c']", "[a=\"b\nc\"]" });
}

test "unclosed blocks are closed by the end of the input" {
    try expectAll(true, &.{ "#attr-value [align=\"center\"", "[foo", ":nth-child(1", ":not(.a", ":is(.a, .b", "[a=\"b" });
}

test "pseudo-elements: legacy one-colon forms, known names, -webkit- quirk, position" {
    try expectAll(true, &.{ "#pseudo-element:after", "#pseudo-element:before", "#pseudo-element:first-letter", "#pseudo-element:first-line", "div::before", "::after", "::MARKER", "::-webkit-foo", "::before::marker", "::slotted(span)", "::part(foo bar)", "::before:hover", "::placeholder", "div ::selection" });
    try expectAll(false, &.{ "div::example", "::example", ":::before", ":: before", "::before div", "::before.a", "::before > a", ":not(::before)", ":has(::before)", "::-webkit-jkl()", "::before:first-child", "::before::before", "::slotted(.a .b)", "::part()", ":first-child::before::after" });
}

test "pseudo-classes: names are ASCII case-insensitive; unknown ones are invalid" {
    try expectAll(true, &.{ ":FIRST-CHILD", ":Not(a)", ":Is(a)", ":LINK", ":-webkit-autofill", ":autofill", ":dir(ltr)", ":dir(foo)", ":lang(en)", ":lang(en, \"fr\")", ":lang(\\*-CH)", ":state(--x)", ":heading(1, +2)" });
    try expectAll(false, &.{ "div:example", ":example", "div:linkexample", ":dir()", ":dir(ltr rtl)", ":lang()", ":lang(en,)", ":lang(5)", ":state(1)", ":nth-child", ":not", "a:hover:" });
}

test "logical combinations: :is/:where forgive, :not/:has do not, :has does not nest" {
    // :has(:is(:has(*))) is valid in Firefox and Safari (the forgiving :is()
    // drops the nested :has), not in Chrome: wpt.fyi cc74d2669f,
    // css/selectors/parsing/parse-has-forgiving-selector.html. Majority.
    try expectAll(true, &.{ ":is()", ":where()", ":is(%, .a)", ":where(.a, ::before)", ":is(:has(a))", ":has(:is(:has(a)))", ":has(:where(:has(*)))", "p:has(span)", "dd:not(:has(dd))", "dd:not(dd:has(dd))", ":has(> .a, + .b, ~ .c, .d)", ":not(.a, .b)" });
    try expectAll(false, &.{ ":not()", ":has()", ":has(:has(a))", ".a:has(.b:has(.c))", ":has(:not(:has(a)))", ":has(123)", ":has(.a, 123)", ":not(%)", ":has(> )", ":not(.a, )" });
}

test ":scope and the shadow-tree pseudo-classes" {
    try expectAll(true, &.{ ":scope", ":scope > p", ":scope > p, :scope > div", ":scope [data-side]:not(:scope [data-item] [data-item] [data-side])", ":host", ":host > article", ":host(.a)", ":host(div.a[b])" });
    // :host-context() is Chrome's alone (Firefox and Safari reject it).
    try expectAll(false, &.{ ":host()", ":host(.a .b)", ":host(::before)", ":host-context(.a)", ":host-context()", ":host-context(a > b)" });
}

test "selector lists and combinators" {
    try expectAll(true, &.{ "div, p", " div ", "div ,p", "div\t>\np", "div+p", "div~p", "div/**/.a", "/* c */ div", "a > b ~ c + d e" });
    try expectAll(false, &.{ "", " ", "div,", ",div", "div,,p", "[", "]", "(", ")", "{", "}", "<", ">", ".", "..test", ".foo..quux", ".bar.", "div % address, p", "div ++ address, p", "div ~~ address, p", ">*", "div >", "div > > p", "div p)", "div;", "a b(c)", "div*", "*div" });
}
