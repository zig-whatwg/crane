//! The @import rules a style sheet starts with.
//!
//! A style sheet's @import rules are its critical subresources: HTML waits
//! for them before it fires `load` or `error` at the `link` or `style`
//! element that owns the sheet (HTML 4.2.4.3, 4.2.6), and CSS Cascade fetches
//! each one ("fetch an @import"). This finds them: it reads the sheet's
//! tokens (tokenizer.zig), consumes its top-level rules as CSS Syntax's
//! "consume a stylesheet's contents" does, and keeps the URL of every valid
//! @import rule.
//!
//! An @import rule is valid only before every other rule except @charset
//! and @layer statements (CSS Cascade 5 section 2: "Any @import rules must
//! precede all other valid at-rules and style rules in a style sheet
//! (ignoring @charset and @layer statement rules) ... or else the @import
//! rule is invalid"). Its prelude starts with a URL: a <url-token>, a url()
//! function whose argument is a string, or a <string-token>.
//!
//! Not modelled, stated: whether a rule after the imports is itself valid.
//! Selectors and at-rule preludes are not parsed here, so any qualified rule
//! or other at-rule ends the imports - an @import after a rule that CSS would
//! drop as invalid is dropped too. The import's supports() condition and
//! media query list are not evaluated: every import is fetched, as browsers
//! fetch imports whose media does not match.
//!
//! The input is the sheet's bytes as UTF-8: bytes at or above 0x80 are
//! non-ASCII code points, which CSS treats as name code points, so a sheet in
//! another ASCII-compatible encoding yields the same rules. The URLs are
//! returned as written - escapes decoded, not yet parsed or resolved.
//!
//! Spec: https://drafts.csswg.org/css-syntax-3/#consume-stylesheet-contents
//! Spec: https://drafts.csswg.org/css-cascade-5/#at-import

const std = @import("std");
const Allocator = std.mem.Allocator;
const tokenizer = @import("tokenizer.zig");
const Tokenizer = tokenizer.Tokenizer;
const Token = tokenizer.Token;
const TokenType = tokenizer.TokenType;

/// The URL of every valid @import rule at the start of `sheet`, in order.
/// Owned by the caller: free with `freeUrls`.
pub fn importUrls(allocator: Allocator, sheet: []const u8) Allocator.Error![][]u8 {
    var urls: std.ArrayList([]u8) = .empty;
    errdefer {
        for (urls.items) |url| allocator.free(url);
        urls.deinit(allocator);
    }
    var tokens = Tokenizer.init(sheet);
    // Whether an @import here is still before every other rule.
    var imports_allowed = true;
    // "Consume a stylesheet's contents": consume a list of rules, with the
    // top-level flag set.
    while (true) {
        const token = tokens.next();
        switch (token.token_type) {
            .eof => break,
            // Whitespace, and at the top level <CDO-token> and <CDC-token>,
            // are skipped.
            .whitespace, .cdo, .cdc => {},
            .at_keyword => {
                const rule = consumeAtRule(&tokens);
                if (tokenizer.nameEql(token.value, "import")) {
                    // An @import with a {} block is invalid; so is one with
                    // no URL. Neither ends the imports: an invalid rule is
                    // dropped as if it were not there.
                    if (!imports_allowed or rule.has_block) continue;
                    const url = try importUrl(allocator, sheet, rule.prelude) orelse continue;
                    urls.append(allocator, url) catch |err| {
                        allocator.free(url);
                        return err;
                    };
                } else if (tokenizer.nameEql(token.value, "charset")) {
                    // @charset is ignored where it stands.
                } else if (tokenizer.nameEql(token.value, "layer") and !rule.has_block) {
                    // A @layer statement may precede the imports.
                } else {
                    imports_allowed = false;
                }
            },
            else => {
                // A qualified rule: its prelude, then its {} block.
                consumeQualifiedRule(&tokens, token);
                imports_allowed = false;
            },
        }
    }
    return urls.toOwnedSlice(allocator);
}

/// Free what `importUrls` returned.
pub fn freeUrls(allocator: Allocator, urls: [][]u8) void {
    for (urls) |url| allocator.free(url);
    allocator.free(urls);
}

/// A byte range of the sheet.
const Span = struct { start: usize, end: usize };

/// An at-rule, as "consume an at-rule" leaves it: the span of its prelude,
/// and whether it ended with a {} block rather than a semicolon or EOF.
const AtRule = struct {
    prelude: Span,
    has_block: bool,
};

/// "Consume an at-rule", its at-keyword consumed: the prelude runs to a
/// semicolon, a {} block (consumed with it) or EOF.
fn consumeAtRule(tokens: *Tokenizer) AtRule {
    const start = tokens.pos;
    while (true) {
        const before = tokens.pos;
        const token = tokens.next();
        switch (token.token_type) {
            .semicolon, .eof => return .{ .prelude = .{ .start = start, .end = before }, .has_block = false },
            .left_brace => {
                consumeBlockContents(tokens, .right_brace);
                return .{ .prelude = .{ .start = start, .end = before }, .has_block = true };
            },
            else => consumeComponentValue(tokens, token),
        }
    }
}

/// "Consume a qualified rule" whose first token is `first`: its prelude up
/// to and including its {} block, or to EOF (a parse error; the rule is
/// dropped).
fn consumeQualifiedRule(tokens: *Tokenizer, first: Token) void {
    var token = first;
    while (true) {
        switch (token.token_type) {
            .eof => return,
            .left_brace => {
                consumeBlockContents(tokens, .right_brace);
                return;
            },
            else => consumeComponentValue(tokens, token),
        }
        token = tokens.next();
    }
}

/// "Consume a component value" that starts with `token`: a simple block's
/// contents through its closing token. (A function's "(" is the token after
/// its name, and opens a block of its own.)
fn consumeComponentValue(tokens: *Tokenizer, token: Token) void {
    switch (token.token_type) {
        .left_paren => consumeBlockContents(tokens, .right_paren),
        .left_bracket => consumeBlockContents(tokens, .right_bracket),
        .left_brace => consumeBlockContents(tokens, .right_brace),
        else => {},
    }
}

/// "Consume a simple block", after its opening token: nested component
/// values through `close`, or to EOF.
fn consumeBlockContents(tokens: *Tokenizer, close: TokenType) void {
    while (true) {
        const token = tokens.next();
        if (token.token_type == close or token.token_type == .eof) return;
        consumeComponentValue(tokens, token);
    }
}

/// The URL an @import rule's prelude starts with, as the spec's value
/// (escapes decoded); null when it starts with none: `[ <url> | <string> ]`,
/// where <url> is a <url-token> or url( <string> ).
fn importUrl(allocator: Allocator, sheet: []const u8, prelude: Span) Allocator.Error!?[]u8 {
    var tokens = Tokenizer.init(sheet[0..prelude.end]);
    tokens.pos = prelude.start;
    const first = nextNonWhitespace(&tokens);
    switch (first.token_type) {
        .url => return try tokenizer.decode(allocator, first.value),
        .string => return try tokenizer.decode(allocator, first.stringContents()),
        .function => {
            if (!tokenizer.nameEql(first.value, "url")) return null;
            if (tokens.next().token_type != .left_paren) return null;
            const argument = nextNonWhitespace(&tokens);
            if (argument.token_type != .string) return null;
            const close = nextNonWhitespace(&tokens);
            if (close.token_type != .right_paren and close.token_type != .eof) return null;
            return try tokenizer.decode(allocator, argument.stringContents());
        },
        else => return null,
    }
}

fn nextNonWhitespace(tokens: *Tokenizer) Token {
    var token = tokens.next();
    while (token.token_type == .whitespace) token = tokens.next();
    return token;
}

// ============================================================================
// Tests
// ============================================================================

fn expectImports(sheet: []const u8, expected: []const []const u8) !void {
    const urls = try importUrls(std.testing.allocator, sheet);
    defer freeUrls(std.testing.allocator, urls);
    try std.testing.expectEqual(expected.len, urls.len);
    for (expected, urls) |want, got| try std.testing.expectEqualStrings(want, got);
}

test "an @import's URL: a url token, a url() string, or a string" {
    try expectImports("@import url(a.css);", &.{"a.css"});
    try expectImports("@import \"b.css\";", &.{"b.css"});
    try expectImports("@import 'c.css' screen;", &.{"c.css"});
    try expectImports("@import url(\"d.css\") screen and (min-width: 1px);", &.{"d.css"});
    try expectImports("@import url(  e.css  );", &.{"e.css"});
    try expectImports("@import url( 'f.css' );", &.{"f.css"});
    try expectImports("@import url(g.css) supports(display: grid) print;", &.{"g.css"});
}

test "@import is ASCII case-insensitive, and its name may be escaped" {
    try expectImports("@IMPORT url(a.css);", &.{"a.css"});
    try expectImports("@\\69mport \"b.css\";", &.{"b.css"});
    try expectImports("@import URL(c.css);", &.{"c.css"});
}

test "escapes in the URL are decoded" {
    try expectImports("@import url(a\\)b.css);", &.{"a)b.css"});
    try expectImports("@import \"\\62 .css\";", &.{"b.css"});
    try expectImports("@import \"c\\\"d.css\";", &.{"c\"d.css"});
}

test "imports come before every rule but @charset and @layer statements" {
    try expectImports("@charset \"utf-8\"; @import 'a.css'; @import url(b.css);body {color: green; }", &.{ "a.css", "b.css" });
    try expectImports("@layer base; @import 'c.css';", &.{"c.css"});
    try expectImports("body {} @import url(d.css);", &.{});
    try expectImports("@layer base {} @import 'e.css';", &.{});
    try expectImports("@media screen { @import 'f.css'; } @import 'g.css';", &.{});
    try expectImports("@namespace svg url(x); @import 'h.css';", &.{});
}

test "an @import without a URL, or with a block, is dropped and the next may follow" {
    try expectImports("@import; @import 'a.css';", &.{"a.css"});
    try expectImports("@import url(b .css); @import 'c.css';", &.{"c.css"});
    try expectImports("@import url(d.css) {} @import 'e.css';", &.{"e.css"});
    try expectImports("@import foo(bar); @import 'f.css';", &.{"f.css"});
}

test "comments, CDO and CDC are skipped; an unterminated rule ends at EOF" {
    try expectImports("/* @import url(x.css); */ @import url(a.css);", &.{"a.css"});
    try expectImports("<!-- @import \"b.css\"; -->", &.{"b.css"});
    try expectImports("@import \"c.css\"", &.{"c.css"});
    try expectImports("@import url(d.css", &.{"d.css"});
    try expectImports("", &.{});
    try expectImports("   \n\t", &.{});
}

test "a data: URL with an @import of its own is one URL" {
    try expectImports(
        "@import url(\"data:text/css,@import url('http://x/a.css')\");",
        &.{"data:text/css,@import url('http://x/a.css')"},
    );
    try expectImports(
        "@import url(\"http://x/slow.css\"); @import url(\"http://x/404.css\");",
        &.{ "http://x/slow.css", "http://x/404.css" },
    );
}

test "a block's contents never end the rule it is in" {
    // Braces, semicolons and quotes inside blocks, functions and strings.
    try expectImports("@import url(\"a;{b.css\");", &.{"a;{b.css"});
    try expectImports("@import 'c.css' supports(x: (y; z));@import 'd.css';", &.{ "c.css", "d.css" });
    try expectImports("a { content: '}'; } @import 'e.css';", &.{});
}
