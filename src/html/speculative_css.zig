//! The speculative HTML parser's look into a `<style>` element's text (HTML
//! 13.2.8 "Speculative HTML parsing": "Which kinds of resources to
//! speculatively fetch is implementation-defined"): the URL of each @import
//! rule at the start of the style sheet, which a style element the normal
//! parser makes would fetch as a critical subresource.
//!
//! The browsers' design, reproduced (not copied): Blink's CSSPreloadScanner
//! (third_party/blink/renderer/core/html/parser/css_preload_scanner.cc,
//! Tokenize / HasFinishedRuleValue / ParseCSSStringOrURL /
//! CanPreloadImportRule, BSD) and WebKit's (Source/WebCore/html/parser/
//! CSSPreloadScanner.cpp, tokenize / hasValidImportConditions, BSD) read the
//! text one character at a time: comments and whitespace are skipped, an
//! @import whose value is a string or url() is found, @charset and @layer
//! statements may come before it, and the first other rule - or a block -
//! ends the scan, as the @import rules of a style sheet must come first (CSS
//! Cascade 5 6.1). An import with conditions is preloaded only when its
//! condition is a cascade layer ("layer" or "layer(...)"): media queries and
//! supports() are not evaluated (both engines; Blink crbug.com/1277771).
//! Gecko's speculative tree builder queues an import style load per @import
//! URL too (nsHtml5TreeBuilderCppSupplement.h, InitImportStyle; reference
//! only, MPL).
//!
//! One difference, stated: Blink and WebKit emit a rule still open at the end
//! of each chunk of characters they are handed; here the style element's end
//! tag (`finish`) closes it - a rule cannot continue past it - so a URL split
//! across two of Crane's text tokens is never fetched half-read.

const std = @import("std");

/// The scanner's state between characters (Blink's State).
const State = enum {
    initial,
    maybe_comment,
    comment,
    maybe_comment_end,
    rule_start,
    rule,
    after_rule,
    rule_value,
    after_rule_value,
    maybe_layer_value,
    after_maybe_layer_value,
    done_parsing_import_rules,
};

/// One @import rule's URL, as written in the style sheet (quotes and url()
/// taken off, not resolved). BORROWED until the next character is fed.
pub const Import = struct {
    url: []const u8,
};

pub const Scanner = struct {
    allocator: std.mem.Allocator,
    state: State = .initial,
    rule: std.ArrayListUnmanaged(u8) = .empty,
    rule_value: std.ArrayListUnmanaged(u8) = .empty,
    maybe_layer_value: std.ArrayListUnmanaged(u8) = .empty,
    has_trailing_contents: bool = false,
    /// The imports found, in order, until `takeImports`.
    imports: std.ArrayListUnmanaged([]u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Scanner {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Scanner) void {
        self.rule.deinit(self.allocator);
        self.rule_value.deinit(self.allocator);
        self.maybe_layer_value.deinit(self.allocator);
        self.freeImports();
        self.imports.deinit(self.allocator);
    }

    /// A new `<style>` element's text starts (Blink's Reset).
    pub fn reset(self: *Scanner) void {
        self.state = .initial;
        self.rule.clearRetainingCapacity();
        self.rule_value.clearRetainingCapacity();
        self.maybe_layer_value.clearRetainingCapacity();
        self.has_trailing_contents = false;
    }

    /// Whether the scan has passed the @import rules: nothing more is read.
    pub fn done(self: *const Scanner) bool {
        return self.state == .done_parsing_import_rules;
    }

    /// The style element's next characters.
    pub fn feed(self: *Scanner, text: []const u8) !void {
        for (text) |c| {
            if (self.state == .done_parsing_import_rules) return;
            try self.tokenize(c);
        }
    }

    /// The style element's text has ended: a rule still open is complete.
    pub fn finish(self: *Scanner) !void {
        switch (self.state) {
            .rule_value, .after_rule_value, .after_maybe_layer_value, .maybe_layer_value => try self.emitRule(),
            else => {},
        }
        self.reset();
    }

    /// The URLs found since the last call, in order; the caller frees each
    /// and the slice with this scanner's allocator.
    pub fn takeImports(self: *Scanner) ![][]u8 {
        return self.imports.toOwnedSlice(self.allocator);
    }

    fn freeImports(self: *Scanner) void {
        for (self.imports.items) |url| self.allocator.free(url);
        self.imports.clearRetainingCapacity();
    }

    fn isSpace(c: u8) bool {
        return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '\x0c';
    }

    fn tokenize(self: *Scanner, c: u8) !void {
        switch (self.state) {
            .initial => {
                if (isSpace(c)) return;
                if (c == '@') {
                    self.state = .rule_start;
                } else if (c == '/') {
                    self.state = .maybe_comment;
                } else self.state = .done_parsing_import_rules;
            },
            .maybe_comment => self.state = if (c == '*') .comment else .initial,
            .comment => {
                if (c == '*') self.state = .maybe_comment_end;
            },
            .maybe_comment_end => {
                if (c == '*') return;
                self.state = if (c == '/') .initial else .comment;
            },
            .rule_start => {
                if (std.ascii.isAlphabetic(c)) {
                    self.rule.clearRetainingCapacity();
                    self.rule_value.clearRetainingCapacity();
                    try self.rule.append(self.allocator, c);
                    self.state = .rule;
                } else self.state = .initial;
            },
            .rule => {
                if (isSpace(c)) {
                    self.state = .after_rule;
                } else if (c == ';') {
                    self.state = .initial;
                } else try self.rule.append(self.allocator, c);
            },
            .after_rule => {
                if (isSpace(c)) return;
                if (c == ';') {
                    self.state = .initial;
                } else if (c == '{') {
                    self.state = .done_parsing_import_rules;
                } else {
                    self.state = .rule_value;
                    try self.rule_value.append(self.allocator, c);
                }
            },
            .rule_value => {
                if (isSpace(c)) {
                    self.state = .after_rule_value;
                    self.has_trailing_contents = false;
                } else if (c == ';') {
                    if (self.hasFinishedRuleValue()) try self.emitRule() else try self.rule_value.append(self.allocator, c);
                } else try self.rule_value.append(self.allocator, c);
            },
            .after_rule_value => {
                if (isSpace(c)) return;
                if (c == ';') {
                    try self.emitRule();
                } else if (c == '{') {
                    self.state = .done_parsing_import_rules;
                } else {
                    self.state = .maybe_layer_value;
                    self.maybe_layer_value.clearRetainingCapacity();
                    try self.maybe_layer_value.append(self.allocator, c);
                }
            },
            .maybe_layer_value => {
                if (isSpace(c)) {
                    self.state = .after_maybe_layer_value;
                    self.has_trailing_contents = false;
                } else if (c == ';') {
                    try self.emitRule();
                } else try self.maybe_layer_value.append(self.allocator, c);
            },
            .after_maybe_layer_value => {
                if (isSpace(c)) return;
                if (c == ';') {
                    try self.emitRule();
                } else if (c == '{') {
                    self.state = .done_parsing_import_rules;
                } else self.has_trailing_contents = true;
            },
            .done_parsing_import_rules => {},
        }
    }

    /// Blink's HasFinishedRuleValue: a ';' inside an unfinished string or
    /// url() is part of the value.
    fn hasFinishedRuleValue(self: *const Scanner) bool {
        if (!std.ascii.eqlIgnoreCase(self.rule.items, "import")) return true;
        const value = self.rule_value.items;
        if (value.len < 2 or value[value.len - 2] == '\\') return false;
        if (value[0] == '\'' or value[0] == '"') return value[0] == value[value.len - 1];
        return value[value.len - 1] == ')';
    }

    /// Blink's CanPreloadImportRule / WebKit's hasValidImportConditions: no
    /// condition, or a cascade layer only.
    fn canPreloadImportRule(self: *const Scanner) bool {
        if (self.has_trailing_contents) return false;
        const layer = self.maybe_layer_value.items;
        if (layer.len == 0) return true;
        if (std.ascii.eqlIgnoreCase(layer, "layer")) return true;
        return layer.len >= 8 and std.ascii.eqlIgnoreCase(layer[0..6], "layer(") and layer[layer.len - 1] == ')';
    }

    fn emitRule(self: *Scanner) !void {
        if (std.ascii.eqlIgnoreCase(self.rule.items, "import")) {
            if (self.canPreloadImportRule()) {
                const url = parseCssStringOrUrl(self.rule_value.items);
                if (url.len != 0) {
                    const owned = try self.allocator.dupe(u8, url);
                    errdefer self.allocator.free(owned);
                    try self.imports.append(self.allocator, owned);
                }
            }
            self.state = .initial;
        } else if (std.ascii.eqlIgnoreCase(self.rule.items, "charset") or std.ascii.eqlIgnoreCase(self.rule.items, "layer")) {
            self.state = .initial;
        } else self.state = .done_parsing_import_rules;
        self.rule.clearRetainingCapacity();
        self.rule_value.clearRetainingCapacity();
        self.maybe_layer_value.clearRetainingCapacity();
        self.has_trailing_contents = false;
    }
};

/// Blink's ParseCSSStringOrURL: the URL inside `url(...)` or quotes, with the
/// surrounding whitespace taken off. A slice of `value`.
fn parseCssStringOrUrl(value: []const u8) []const u8 {
    var s = std.mem.trim(u8, value, " \t\n\r\x0c");
    if (s.len >= 5 and std.ascii.eqlIgnoreCase(s[0..3], "url") and s[3] == '(' and s[s.len - 1] == ')') {
        s = s[4 .. s.len - 1];
    }
    s = std.mem.trim(u8, s, " \t\n\r\x0c");
    if (s.len >= 2 and s[0] == s[s.len - 1] and (s[0] == '\'' or s[0] == '"')) s = s[1 .. s.len - 1];
    return s;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn scanAll(text: []const u8) ![][]u8 {
    var scanner = Scanner.init(testing.allocator);
    defer scanner.deinit();
    try scanner.feed(text);
    try scanner.finish();
    return scanner.takeImports();
}

fn freeAll(urls: [][]u8) void {
    for (urls) |url| testing.allocator.free(url);
    testing.allocator.free(urls);
}

test "the @import rules at the start of a style sheet are found, url() and strings alike" {
    const urls = try scanAll(" /* c */ @charset \"utf-8\"; @import url( 'a.css' );\n@import \"b.css\";@import url(c.css);\n@layer x; @import url(d.css) layer(base); p { } @import url(e.css);");
    defer freeAll(urls);
    try testing.expectEqual(@as(usize, 4), urls.len);
    try testing.expectEqualStrings("a.css", urls[0]);
    try testing.expectEqualStrings("b.css", urls[1]);
    try testing.expectEqualStrings("c.css", urls[2]);
    try testing.expectEqualStrings("d.css", urls[3]);
}

test "an @import with a media or supports condition is not preloaded, and a rule ends the scan" {
    const urls = try scanAll("@import url(print.css) print; @import url(s.css) supports(display: grid); @import url(ok.css);");
    defer freeAll(urls);
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expectEqualStrings("ok.css", urls[0]);

    const none = try scanAll("p { color: red } @import url(late.css);");
    defer freeAll(none);
    try testing.expectEqual(@as(usize, 0), none.len);
}

test "an @import with no semicolon before the end of the style element's text is found at the end" {
    // resource-timing/render-blocking-status-link.html writes this shape.
    const urls = try scanAll("\n            @import url('resources/empty_style.css?x')\n        ");
    defer freeAll(urls);
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expectEqualStrings("resources/empty_style.css?x", urls[0]);
}

test "a semicolon inside an unfinished url() or string is part of the URL" {
    const urls = try scanAll("@import url(a;b.css); @import 'c;d.css';");
    defer freeAll(urls);
    try testing.expectEqual(@as(usize, 2), urls.len);
    try testing.expectEqualStrings("a;b.css", urls[0]);
    try testing.expectEqualStrings("c;d.css", urls[1]);
}

test "a URL fed in pieces is read whole" {
    var scanner = Scanner.init(testing.allocator);
    defer scanner.deinit();
    try scanner.feed("@import url(sp");
    try scanner.feed("lit.css)");
    try scanner.finish();
    const urls = try scanner.takeImports();
    defer freeAll(urls);
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expectEqualStrings("split.css", urls[0]);
}
