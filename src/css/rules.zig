//! A style sheet's rules, as CSS Syntax parses them: "parse a stylesheet's
//! contents", for the CSSOM objects that wrap them (src/dom/cssom.zig) -
//! CSSStyleSheet's replaceSync() and replace(), and so HTML's CSS module
//! scripts.
//!
//! What a rule keeps is what the CSSOM reads back: a qualified rule's
//! prelude (a style rule's selector) and the declarations of its block; an
//! at-rule's name and prelude. Each is kept as its component values
//! serialized - identifiers and strings as CSSOM serializes them, whitespace
//! and comments collapsed to one space, trimmed - which is what selectorText
//! and a declared value read, as far as nothing here parses a selector or a
//! property's grammar.
//!
//! Stated deviations: a declaration's value is its component values
//! serialized, not the property's parsed value serialized canonically
//! (`color: RED` reads back as `RED`); nested style rules and at-rules inside
//! a style rule's block are dropped; an at-rule's block is skipped, not
//! parsed.
//!
//! Spec: https://drafts.csswg.org/css-syntax-3/#parse-stylesheet-contents
//! Spec: https://drafts.csswg.org/cssom-1/#serialize-an-identifier
//! Spec: https://encoding.spec.whatwg.org/#utf-8-decode

const std = @import("std");
const Allocator = std.mem.Allocator;
const tokenizer = @import("tokenizer.zig");
const Tokenizer = tokenizer.Tokenizer;
const Token = tokenizer.Token;
const TokenType = tokenizer.TokenType;

/// A declaration of a rule's block.
pub const Declaration = struct {
    /// The property name: decoded, and ASCII-lowercased unless it is a
    /// custom property (`--x`), whose name is case-sensitive.
    name: []u8,
    /// The value's component values, serialized, without `!important`.
    value: []u8,
    important: bool,
};

/// One rule of a style sheet's top level.
pub const Rule = struct {
    kind: Kind,
    /// An at-rule's name, decoded and ASCII-lowercased; empty for a
    /// qualified rule.
    name: []u8,
    /// The prelude's component values, serialized: a style rule's selector.
    prelude: []u8,
    /// The declarations of a qualified rule's block. Empty for an at-rule.
    declarations: []Declaration,
    /// The rule ended in a {}-block (an at-rule may end in `;` instead).
    has_block: bool,

    pub const Kind = enum { qualified, at_rule };

    fn deinit(self: *Rule, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.prelude);
        for (self.declarations) |d| {
            allocator.free(d.name);
            allocator.free(d.value);
        }
        allocator.free(self.declarations);
    }
};

/// A style sheet's top-level rules, in order. Owned: `deinit`.
pub const Rules = struct {
    allocator: Allocator,
    items: []Rule,

    pub fn deinit(self: *Rules) void {
        for (self.items) |*rule| rule.deinit(self.allocator);
        self.allocator.free(self.items);
        self.items = &.{};
    }
};

/// CSS Syntax "parse a stylesheet's contents" from `text` (UTF-8, already
/// decoded): "consume a stylesheet's contents" - a list of rules at the top
/// level. A rule the syntax drops (a qualified rule cut off by EOF) is not
/// in the list; nothing here decides whether a rule is VALID - a selector,
/// an at-rule's grammar - which is the caller's.
pub fn parseStyleSheetContents(allocator: Allocator, text: []const u8) Allocator.Error!Rules {
    var parser: Parser = .{ .allocator = allocator, .tokens = Tokenizer.init(text) };
    var rules: std.ArrayList(Rule) = .empty;
    errdefer {
        for (rules.items) |*rule| rule.deinit(allocator);
        rules.deinit(allocator);
    }
    // "Consume a stylesheet's contents": consume a list of rules, with
    // nested false.
    while (true) {
        const token = parser.peek();
        switch (token.token_type) {
            .eof => break,
            // Whitespace, and at the top level <CDO-token> and <CDC-token>,
            // are discarded.
            .whitespace, .cdo, .cdc => _ = parser.next(),
            .at_keyword => {
                var rule = try parser.consumeAtRule();
                errdefer rule.deinit(allocator);
                try rules.append(allocator, rule);
            },
            else => {
                if (try parser.consumeQualifiedRule()) |rule| {
                    var owned = rule;
                    errdefer owned.deinit(allocator);
                    try rules.append(allocator, owned);
                }
            },
        }
    }
    return .{ .allocator = allocator, .items = try rules.toOwnedSlice(allocator) };
}

const Parser = struct {
    allocator: Allocator,
    tokens: Tokenizer,
    peeked: ?Token = null,

    fn next(self: *Parser) Token {
        if (self.peeked) |token| {
            self.peeked = null;
            return token;
        }
        return self.tokens.next();
    }

    fn peek(self: *Parser) Token {
        if (self.peeked) |token| return token;
        const token = self.tokens.next();
        self.peeked = token;
        return token;
    }

    /// "Consume an at-rule" at the top level (nested false). The block of
    /// an at-rule is skipped: the CSSOM objects that would read it are not
    /// made yet.
    fn consumeAtRule(self: *Parser) Allocator.Error!Rule {
        const keyword = self.next();
        const name = try tokenizer.decode(self.allocator, keyword.value);
        errdefer self.allocator.free(name);
        _ = std.ascii.lowerString(name, name);
        var prelude: Serializer = .{ .allocator = self.allocator };
        errdefer prelude.deinit();
        var has_block = false;
        while (true) {
            const token = self.peek();
            switch (token.token_type) {
                // <semicolon-token>: the rule ends. <EOF-token>: a parse
                // error; the rule ends.
                .semicolon => {
                    _ = self.next();
                    break;
                },
                .eof => break,
                // <{-token>: consume a block; the rule ends.
                .left_brace => {
                    _ = self.next();
                    try self.skipBlock(.right_brace);
                    has_block = true;
                    break;
                },
                // <}-token> at the top level: a parse error, appended to
                // the prelude.
                .right_brace => try prelude.token(self.next()),
                else => try self.consumeComponentValue(&prelude),
            }
        }
        return .{
            .kind = .at_rule,
            .name = name,
            .prelude = try prelude.finish(),
            .declarations = &.{},
            .has_block = has_block,
        };
    }

    /// "Consume a qualified rule" at the top level (nested false, no stop
    /// token): its prelude up to a {}-block, whose contents are its
    /// declarations. Null for a rule EOF cut off.
    fn consumeQualifiedRule(self: *Parser) Allocator.Error!?Rule {
        var prelude: Serializer = .{ .allocator = self.allocator };
        defer prelude.deinit();
        while (true) {
            const token = self.peek();
            switch (token.token_type) {
                // A parse error: nothing.
                .eof => return null,
                // <}-token> at the top level: a parse error, appended to
                // the prelude.
                .right_brace => try prelude.token(self.next()),
                .left_brace => {
                    _ = self.next();
                    const declarations = try self.consumeDeclarationList();
                    errdefer freeDeclarations(self.allocator, declarations);
                    return .{
                        .kind = .qualified,
                        .name = try self.allocator.alloc(u8, 0),
                        .prelude = try prelude.finish(),
                        .declarations = declarations,
                        .has_block = true,
                    };
                },
                else => try self.consumeComponentValue(&prelude),
            }
        }
    }

    /// "Consume a block's contents", as far as its declarations: the block
    /// is consumed to its closing `}` (or EOF). A nested rule or at-rule is
    /// consumed and dropped.
    fn consumeDeclarationList(self: *Parser) Allocator.Error![]Declaration {
        var declarations: std.ArrayList(Declaration) = .empty;
        errdefer {
            for (declarations.items) |d| {
                self.allocator.free(d.name);
                self.allocator.free(d.value);
            }
            declarations.deinit(self.allocator);
        }
        while (true) {
            const token = self.peek();
            switch (token.token_type) {
                .whitespace, .semicolon => _ = self.next(),
                .eof => break,
                .right_brace => {
                    _ = self.next();
                    break;
                },
                .at_keyword => {
                    // A nested at-rule: consumed, and not kept.
                    var rule = try self.consumeNestedAtRule();
                    rule.deinit(self.allocator);
                },
                else => {
                    // "Mark the token stream. Consume a declaration. If
                    // anything was returned, append it. Otherwise, restore
                    // the token stream" and consume a nested qualified rule
                    // with `;` as its stop token - dropped here.
                    if (token.token_type == .ident) {
                        const mark = self.markStream();
                        if (try self.consumeDeclaration()) |declaration| {
                            try declarations.append(self.allocator, declaration);
                            continue;
                        }
                        self.restoreStream(mark);
                    }
                    try self.skipNestedQualifiedRule();
                },
            }
        }
        return declarations.toOwnedSlice(self.allocator);
    }

    const Mark = struct { tokens: Tokenizer, peeked: ?Token };

    fn markStream(self: *const Parser) Mark {
        return .{ .tokens = self.tokens, .peeked = self.peeked };
    }

    fn restoreStream(self: *Parser, mark: Mark) void {
        self.tokens = mark.tokens;
        self.peeked = mark.peeked;
    }

    /// "Consume a declaration" (nested): its component values up to a `;`
    /// (consumed), the block's `}` or EOF (left). Null - nothing - when they
    /// are no declaration.
    fn consumeDeclaration(self: *Parser) Allocator.Error!?Declaration {
        var list: std.ArrayList(Token) = .empty;
        defer list.deinit(self.allocator);
        while (true) {
            const t = self.peek();
            switch (t.token_type) {
                .eof, .right_brace => break,
                .semicolon => {
                    _ = self.next();
                    break;
                },
                else => try self.collectComponentValue(&list),
            }
        }
        return self.declarationFrom(list.items);
    }

    /// A nested "consume a qualified rule" with `;` as its stop token,
    /// consumed and dropped: it ends at the stop token, at the enclosing
    /// block's `}` (left), at EOF, or after its own {}-block.
    fn skipNestedQualifiedRule(self: *Parser) Allocator.Error!void {
        var sink: Serializer = .{ .allocator = self.allocator, .discard = true };
        while (true) {
            const t = self.peek();
            switch (t.token_type) {
                .eof, .right_brace => return,
                .semicolon => {
                    _ = self.next();
                    return;
                },
                .left_brace => {
                    _ = self.next();
                    try self.skipBlock(.right_brace);
                    return;
                },
                else => try self.consumeComponentValue(&sink),
            }
        }
    }

    /// A nested "consume an at-rule": ends at `;`, at a {}-block, or at the
    /// enclosing block's `}` (left for the caller).
    fn consumeNestedAtRule(self: *Parser) Allocator.Error!Rule {
        const keyword = self.next();
        const name = try tokenizer.decode(self.allocator, keyword.value);
        errdefer self.allocator.free(name);
        var prelude: Serializer = .{ .allocator = self.allocator };
        errdefer prelude.deinit();
        while (true) {
            const token = self.peek();
            switch (token.token_type) {
                .semicolon => {
                    _ = self.next();
                    break;
                },
                .eof, .right_brace => break,
                .left_brace => {
                    _ = self.next();
                    try self.skipBlock(.right_brace);
                    break;
                },
                else => try self.consumeComponentValue(&prelude),
            }
        }
        return .{ .kind = .at_rule, .name = name, .prelude = try prelude.finish(), .declarations = &.{}, .has_block = false };
    }

    /// "Consume a declaration" from its component values: an ident, then
    /// optional whitespace, then a colon - or nothing. The value is the rest,
    /// its trailing `!important` taken off, whitespace trimmed. A value that
    /// holds a top-level {}-block beside anything else is no declaration,
    /// unless the property is a custom one.
    fn declarationFrom(self: *Parser, list: []const Token) Allocator.Error!?Declaration {
        if (list.len == 0 or list[0].token_type != .ident) return null;
        const raw_name = list[0].value;
        var i: usize = 1;
        while (i < list.len and list[i].token_type == .whitespace) i += 1;
        if (i >= list.len or list[i].token_type != .colon) return null;
        i += 1;

        // The last two non-whitespace tokens "!" and "important" (ASCII
        // case-insensitive) make it important, and leave the value.
        var end = list.len;
        var important = false;
        if (lastNonWhitespace(list[i..end])) |last| {
            const last_index = i + last;
            if (list[last_index].token_type == .ident and tokenizer.nameEql(list[last_index].value, "important")) {
                if (lastNonWhitespace(list[i..last_index])) |bang| {
                    const bang_index = i + bang;
                    if (list[bang_index].token_type == .delim and std.mem.eql(u8, list[bang_index].value, "!")) {
                        important = true;
                        end = bang_index;
                    }
                }
            }
        }

        const name = try tokenizer.decode(self.allocator, raw_name);
        errdefer self.allocator.free(name);
        const custom = std.mem.startsWith(u8, name, "--");
        if (!custom) {
            _ = std.ascii.lowerString(name, name);
            if (holdsBlockBesideOthers(list[i..end])) {
                self.allocator.free(name);
                return null;
            }
        }
        var value: Serializer = .{ .allocator = self.allocator };
        errdefer value.deinit();
        for (list[i..end]) |token| try value.token(token);
        return .{ .name = name, .value = try value.finish(), .important = important };
    }

    /// "Consume a component value" into `out`: a token, or a whole block (a
    /// function's arguments are the ()-block after its name).
    fn consumeComponentValue(self: *Parser, out: *Serializer) Allocator.Error!void {
        const token = self.next();
        try out.token(token);
        const closing: ?TokenType = switch (token.token_type) {
            .left_brace => .right_brace,
            .left_bracket => .right_bracket,
            .left_paren => .right_paren,
            else => null,
        };
        const close = closing orelse return;
        while (true) {
            const inner = self.peek();
            if (inner.token_type == .eof) return;
            if (inner.token_type == close) {
                try out.token(self.next());
                return;
            }
            try self.consumeComponentValue(out);
        }
    }

    /// As consumeComponentValue, collecting the tokens instead.
    fn collectComponentValue(self: *Parser, list: *std.ArrayList(Token)) Allocator.Error!void {
        const token = self.next();
        try list.append(self.allocator, token);
        const closing: ?TokenType = switch (token.token_type) {
            .left_brace => .right_brace,
            .left_bracket => .right_bracket,
            .left_paren => .right_paren,
            else => null,
        };
        const close = closing orelse return;
        while (true) {
            const inner = self.peek();
            if (inner.token_type == .eof) return;
            if (inner.token_type == close) {
                try list.append(self.allocator, self.next());
                return;
            }
            try self.collectComponentValue(list);
        }
    }

    /// Consume the rest of a block whose opening token has been consumed,
    /// through its closing token.
    fn skipBlock(self: *Parser, close: TokenType) Allocator.Error!void {
        var sink: Serializer = .{ .allocator = self.allocator, .discard = true };
        while (true) {
            const inner = self.peek();
            if (inner.token_type == .eof) return;
            if (inner.token_type == close) {
                _ = self.next();
                return;
            }
            try self.consumeComponentValue(&sink);
        }
    }
};

/// Whether a value's top-level component values hold a {}-block and any
/// other non-whitespace value.
fn holdsBlockBesideOthers(list: []const Token) bool {
    var depth: usize = 0;
    var block = false;
    var other = false;
    for (list) |t| {
        switch (t.token_type) {
            .left_brace, .left_bracket, .left_paren => {
                if (depth == 0) {
                    if (t.token_type == .left_brace) block = true else other = true;
                }
                depth += 1;
            },
            .right_brace, .right_bracket, .right_paren => depth -|= 1,
            .whitespace => {},
            else => if (depth == 0) {
                other = true;
            },
        }
    }
    return block and other;
}

fn lastNonWhitespace(list: []const Token) ?usize {
    var k = list.len;
    while (k > 0) {
        k -= 1;
        if (list[k].token_type != .whitespace) return k;
    }
    return null;
}

fn freeDeclarations(allocator: Allocator, declarations: []Declaration) void {
    for (declarations) |d| {
        allocator.free(d.name);
        allocator.free(d.value);
    }
    allocator.free(declarations);
}

/// Component values as text: each token serialized, a run of whitespace
/// (and the comments in it) one space, none at either end.
const Serializer = struct {
    allocator: Allocator,
    out: std.ArrayList(u8) = .empty,
    pending_space: bool = false,
    discard: bool = false,

    fn deinit(self: *Serializer) void {
        self.out.deinit(self.allocator);
    }

    fn finish(self: *Serializer) Allocator.Error![]u8 {
        return self.out.toOwnedSlice(self.allocator);
    }

    fn token(self: *Serializer, t: Token) Allocator.Error!void {
        if (self.discard) return;
        if (t.token_type == .whitespace) {
            self.pending_space = self.out.items.len > 0;
            return;
        }
        if (self.pending_space) {
            try self.out.append(self.allocator, ' ');
            self.pending_space = false;
        }
        const a = self.allocator;
        switch (t.token_type) {
            .ident, .function => try self.identifier(t.value),
            .at_keyword => {
                try self.out.append(a, '@');
                try self.identifier(t.value);
            },
            .hash => {
                try self.out.append(a, '#');
                try self.identifier(t.value[1..]);
            },
            .string, .bad_string => try self.string(t.stringContents()),
            .url => {
                try self.out.appendSlice(a, "url(");
                try self.string(t.value);
                try self.out.append(a, ')');
            },
            .bad_url => try self.out.appendSlice(a, "url()"),
            .cdo => try self.out.appendSlice(a, "<!--"),
            .cdc => try self.out.appendSlice(a, "-->"),
            .colon => try self.out.append(a, ':'),
            .semicolon => try self.out.append(a, ';'),
            .comma => try self.out.append(a, ','),
            .left_bracket => try self.out.append(a, '['),
            .right_bracket => try self.out.append(a, ']'),
            .left_paren => try self.out.append(a, '('),
            .right_paren => try self.out.append(a, ')'),
            .left_brace => try self.out.append(a, '{'),
            .right_brace => try self.out.append(a, '}'),
            // Numbers, percentages, dimensions and delims as written.
            .number, .percentage, .dimension, .delim => try self.out.appendSlice(a, t.value),
            .whitespace, .eof => {},
        }
    }

    /// CSSOM "serialize an identifier" of the name `raw` (escapes as
    /// written, decoded first).
    fn identifier(self: *Serializer, raw: []const u8) Allocator.Error!void {
        const a = self.allocator;
        const name = try tokenizer.decode(a, raw);
        defer a.free(name);
        const view = std.unicode.Utf8View.init(name) catch {
            try self.out.appendSlice(a, name);
            return;
        };
        var it = view.iterator();
        var index: usize = 0;
        var first: u21 = 0;
        while (it.nextCodepoint()) |c| : (index += 1) {
            if (index == 0) first = c;
            if (c == 0) {
                try self.out.appendSlice(a, "\u{FFFD}");
            } else if ((c >= 0x1 and c <= 0x1F) or c == 0x7F or
                (index == 0 and c >= '0' and c <= '9') or
                (index == 1 and c >= '0' and c <= '9' and first == '-'))
            {
                try self.out.print(a, "\\{x} ", .{c});
            } else if (index == 0 and c == '-' and name.len == 1) {
                try self.out.appendSlice(a, "\\-");
            } else if (c >= 0x80 or c == '-' or c == '_' or std.ascii.isAlphanumeric(@intCast(c))) {
                try appendCodepoint(&self.out, a, c);
            } else {
                try self.out.append(a, '\\');
                try appendCodepoint(&self.out, a, c);
            }
        }
    }

    /// CSSOM "serialize a string" of `raw` (escapes as written, decoded
    /// first): double quotes, with `"` and `\` escaped.
    fn string(self: *Serializer, raw: []const u8) Allocator.Error!void {
        const a = self.allocator;
        const text = try tokenizer.decode(a, raw);
        defer a.free(text);
        try self.out.append(a, '"');
        const view = std.unicode.Utf8View.init(text) catch {
            try self.out.appendSlice(a, text);
            try self.out.append(a, '"');
            return;
        };
        var it = view.iterator();
        while (it.nextCodepoint()) |c| {
            if (c == 0) {
                try self.out.appendSlice(a, "\u{FFFD}");
            } else if ((c >= 0x1 and c <= 0x1F) or c == 0x7F) {
                try self.out.print(a, "\\{x} ", .{c});
            } else if (c == '"' or c == '\\') {
                try self.out.append(a, '\\');
                try self.out.append(a, @intCast(c));
            } else {
                try appendCodepoint(&self.out, a, c);
            }
        }
        try self.out.append(a, '"');
    }
};

fn appendCodepoint(out: *std.ArrayList(u8), allocator: Allocator, c: u21) Allocator.Error!void {
    var buffer: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(c, &buffer) catch {
        try out.appendSlice(allocator, "\u{FFFD}");
        return;
    };
    try out.appendSlice(allocator, buffer[0..len]);
}

/// Encoding "UTF-8 decode" of `bytes`, to UTF-8: a leading BOM removed, and
/// every invalid sequence U+FFFD, as the Encoding Standard's UTF-8 decoder
/// replaces them (one per maximal subpart). Owned by the caller.
///
/// Spec: https://encoding.spec.whatwg.org/#utf-8-decode
/// Spec: https://encoding.spec.whatwg.org/#utf-8-decoder
pub fn decodeUtf8(allocator: Allocator, bytes: []const u8) Allocator.Error![]u8 {
    var input = bytes;
    if (std.mem.startsWith(u8, input, "\xEF\xBB\xBF")) input = input[3..];
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, input.len);
    var needed: u8 = 0;
    var seen: u8 = 0;
    var code_point: u21 = 0;
    var lower: u8 = 0x80;
    var upper: u8 = 0xBF;
    var i: usize = 0;
    while (i < input.len) {
        const byte = input[i];
        if (needed == 0) {
            i += 1;
            switch (byte) {
                0x00...0x7F => try out.append(allocator, byte),
                0xC2...0xDF => {
                    needed = 1;
                    code_point = byte & 0x1F;
                },
                0xE0...0xEF => {
                    if (byte == 0xE0) lower = 0xA0;
                    if (byte == 0xED) upper = 0x9F;
                    needed = 2;
                    code_point = byte & 0xF;
                },
                0xF0...0xF4 => {
                    if (byte == 0xF0) lower = 0x90;
                    if (byte == 0xF4) upper = 0x8F;
                    needed = 3;
                    code_point = byte & 0x7;
                },
                else => try out.appendSlice(allocator, "\u{FFFD}"),
            }
            continue;
        }
        if (byte < lower or byte > upper) {
            // An invalid continuation: U+FFFD, and the byte is read again.
            needed = 0;
            seen = 0;
            code_point = 0;
            lower = 0x80;
            upper = 0xBF;
            try out.appendSlice(allocator, "\u{FFFD}");
            continue;
        }
        i += 1;
        lower = 0x80;
        upper = 0xBF;
        code_point = (code_point << 6) | (byte & 0x3F);
        seen += 1;
        if (seen != needed) continue;
        try appendCodepoint(&out, allocator, code_point);
        needed = 0;
        seen = 0;
        code_point = 0;
    }
    // EOF with a sequence unfinished.
    if (needed != 0) try out.appendSlice(allocator, "\u{FFFD}");
    return out.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "parseStyleSheetContents: style rules, their selectors and declarations" {
    var rules = try parseStyleSheetContents(testing.allocator,
        \\/* a comment */ div  >  p.x , #id{ color : red ; content: 'a"b' !IMPORTANT; }
        \\#test { background-color: #FF0000 }
    );
    defer rules.deinit();
    try testing.expectEqual(@as(usize, 2), rules.items.len);
    const first = rules.items[0];
    try testing.expectEqual(Rule.Kind.qualified, first.kind);
    try testing.expectEqualStrings("div > p.x , #id", first.prelude);
    try testing.expectEqual(@as(usize, 2), first.declarations.len);
    try testing.expectEqualStrings("color", first.declarations[0].name);
    try testing.expectEqualStrings("red", first.declarations[0].value);
    try testing.expect(!first.declarations[0].important);
    try testing.expectEqualStrings("content", first.declarations[1].name);
    try testing.expectEqualStrings("\"a\\\"b\"", first.declarations[1].value);
    try testing.expect(first.declarations[1].important);
    try testing.expectEqualStrings("#test", rules.items[1].prelude);
    try testing.expectEqualStrings("background-color", rules.items[1].declarations[0].name);
    try testing.expectEqualStrings("#FF0000", rules.items[1].declarations[0].value);
}

test "parseStyleSheetContents: at-rules, a stray } in a prelude, and EOF" {
    var rules = try parseStyleSheetContents(testing.allocator,
        \\@import "a.css";
        \\@MEDIA screen { p { color: red } }
        \\#test4 } {
        \\    background-color: #FF0000;
        \\}
        \\#test4b { background-color: #00FF00; }
        \\p { color: blue
    );
    defer rules.deinit();
    // The rule EOF cuts off inside its block is kept: its block ends at EOF.
    try testing.expectEqual(@as(usize, 5), rules.items.len);
    try testing.expectEqual(Rule.Kind.at_rule, rules.items[0].kind);
    try testing.expectEqualStrings("import", rules.items[0].name);
    try testing.expectEqualStrings("\"a.css\"", rules.items[0].prelude);
    try testing.expect(!rules.items[0].has_block);
    try testing.expectEqualStrings("media", rules.items[1].name);
    try testing.expect(rules.items[1].has_block);
    // At the top level a } is part of the prelude, which no selector parses.
    try testing.expectEqualStrings("#test4 }", rules.items[2].prelude);
    try testing.expectEqualStrings("#test4b", rules.items[3].prelude);
    try testing.expectEqualStrings("p", rules.items[4].prelude);
    try testing.expectEqualStrings("blue", rules.items[4].declarations[0].value);
}

test "parseStyleSheetContents: a prelude EOF cuts off is no rule" {
    var rules = try parseStyleSheetContents(testing.allocator, "p { color: red } div");
    defer rules.deinit();
    try testing.expectEqual(@as(usize, 1), rules.items.len);
}

test "parseStyleSheetContents: nested blocks and functions stay in their value" {
    var rules = try parseStyleSheetContents(testing.allocator, "a{background:url( x.png ) , rgb(1, 2,3);grid-area:[a] / b;--Custom:{ x ; y }}");
    defer rules.deinit();
    const d = rules.items[0].declarations;
    try testing.expectEqual(@as(usize, 3), d.len);
    try testing.expectEqualStrings("url(\"x.png\") , rgb(1, 2,3)", d[0].value);
    try testing.expectEqualStrings("[a] / b", d[1].value);
    try testing.expectEqualStrings("--Custom", d[2].name);
    try testing.expectEqualStrings("{ x ; y }", d[2].value);
}

test "parseStyleSheetContents: a declaration without a colon, and a nested rule, are dropped" {
    var rules = try parseStyleSheetContents(testing.allocator, "a { color red; & b { x: y } width: 1px }");
    defer rules.deinit();
    const d = rules.items[0].declarations;
    try testing.expectEqual(@as(usize, 1), d.len);
    try testing.expectEqualStrings("width", d[0].name);
    try testing.expectEqualStrings("1px", d[0].value);
}

test "Serializer: identifiers are serialized, NUL as U+FFFD" {
    var rules = try parseStyleSheetContents(testing.allocator, "\u{FFFD}\u{FFFD}\x00d\x00i\x00v\x00 \x00{}");
    defer rules.deinit();
    try testing.expectEqualStrings("\u{FFFD}\u{FFFD}\u{FFFD}d\u{FFFD}i\u{FFFD}v\u{FFFD} \u{FFFD}", rules.items[0].prelude);
}

test "decodeUtf8: BOM, invalid bytes and truncated sequences" {
    const a = testing.allocator;
    const plain = try decodeUtf8(a, "\xEF\xBB\xBFdiv \xC5\x9B");
    defer a.free(plain);
    try testing.expectEqualStrings("div \u{015B}", plain);
    const utf16 = try decodeUtf8(a, "\xFE\xFF\x00d");
    defer a.free(utf16);
    try testing.expectEqualStrings("\u{FFFD}\u{FFFD}\x00d", utf16);
    // A truncated three-byte sequence is one U+FFFD; the next byte is read
    // again.
    const cut = try decodeUtf8(a, "\xE2\x82x\xF0");
    defer a.free(cut);
    try testing.expectEqualStrings("\u{FFFD}x\u{FFFD}", cut);
    // A surrogate's encoding is not UTF-8.
    const surrogate = try decodeUtf8(a, "\xED\xA0\x80");
    defer a.free(surrogate);
    try testing.expectEqualStrings("\u{FFFD}\u{FFFD}\u{FFFD}", surrogate);
}
