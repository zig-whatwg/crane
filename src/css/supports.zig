//! CSS Conditional Rules Level 3, "The CSS namespace, and the supports()
//! function": CSS.supports(property, value) and CSS.supports(conditionText),
//! with <supports-condition> as Level 3 defines it and Level 4's selector().
//!
//! https://drafts.csswg.org/css-conditional-3/#the-css-namespace
//! https://drafts.csswg.org/css-conditional-3/#at-supports
//! https://drafts.csswg.org/css-conditional-4/#typedef-supports-selector-fn
//!
//! A declaration is "supported" when Crane parses it: a property PropertyParser
//! knows (property_parser.zig - the color and length properties) with a value
//! that parses for it, or a custom property with a valid <declaration-value>.
//! Neither function ever fails: anything that does not parse is false.

const std = @import("std");
const tokenizer_mod = @import("tokenizer.zig");
const Tokenizer = tokenizer_mod.Tokenizer;
const Token = tokenizer_mod.Token;
const property_parser = @import("property_parser.zig");
const PropertyParser = property_parser.PropertyParser;
const ParserContext = @import("context.zig").ParserContext;

/// Does the UA support the selector `text` - does it parse as one
/// <complex-selector>? Supplied by the caller (src/selector is not a
/// dependency of this module). Null: every selector() is false.
pub const SelectorCheck = *const fn (allocator: std.mem.Allocator, text: []const u8) bool;

/// CSS.supports(property, value): "If property is an ASCII case-insensitive
/// match for any defined CSS property that the UA supports, or is a custom
/// property name string, and value successfully parses according to that
/// property's grammar, return true. Otherwise, return false." No whitespace
/// or escape processing is done on `property`, and !important is not part
/// of any property's grammar.
pub fn supportsDeclaration(allocator: std.mem.Allocator, property: []const u8, value: []const u8) bool {
    if (isCustomPropertyName(property)) return isDeclarationValue(value);

    var name_buf: [64]u8 = undefined;
    if (property.len == 0 or property.len > name_buf.len) return false;
    const name = std.ascii.lowerString(&name_buf, property);
    if (PropertyParser.getPropertyType(name) == .unknown) return false;

    var ctx = ParserContext.noQuirks(allocator);
    defer ctx.deinit();
    var tok = Tokenizer.init(value);
    _ = PropertyParser.parse(&tok, name, &ctx) catch return false;
    tok.skipWhitespace();
    return tok.peek().isEof();
}

/// CSS.supports(conditionText): "If conditionText, parsed and evaluated as a
/// <supports-condition>, would return true, return true. Otherwise, If
/// conditionText, wrapped in parentheses and then parsed and evaluated as a
/// <supports-condition>, would return true, return true. Otherwise, return
/// false."
pub fn supportsCondition(allocator: std.mem.Allocator, condition_text: []const u8, selector_check: ?SelectorCheck) bool {
    const evaluator: Evaluator = .{ .allocator = allocator, .selector_check = selector_check };
    if (evaluator.condition(condition_text) orelse false) return true;
    const wrapped = std.fmt.allocPrint(allocator, "({s})", .{condition_text}) catch return false;
    defer allocator.free(wrapped);
    return evaluator.condition(wrapped) orelse false;
}

/// "A custom property name string": starts with two dashes.
fn isCustomPropertyName(name: []const u8) bool {
    return name.len > 2 and name[0] == '-' and name[1] == '-';
}

/// <declaration-value>?, as a custom property's value may be: "any sequence
/// of one or more tokens, so long as the sequence does not contain
/// <bad-string-token>, <bad-url-token>, unmatched <)-token>, <]-token>, or
/// <}-token>, or top-level <semicolon-token> tokens or <delim-token> tokens
/// with a value of "!"" - or nothing (an empty custom property is valid).
fn isDeclarationValue(value: []const u8) bool {
    var tok = Tokenizer.init(value);
    var closers: [64]tokenizer_mod.TokenType = undefined;
    var depth: usize = 0;
    while (true) {
        const t = tok.next();
        switch (t.token_type) {
            .eof => return true,
            .bad_string, .bad_url => return false,
            .semicolon => if (depth == 0) return false,
            .delim => if (depth == 0 and std.mem.eql(u8, t.value, "!")) return false,
            .left_paren, .function, .left_bracket, .left_brace => {
                if (depth == closers.len) return false;
                closers[depth] = closerOf(t.token_type);
                depth += 1;
            },
            .right_paren, .right_bracket, .right_brace => {
                if (depth == 0 or closers[depth - 1] != t.token_type) return false;
                depth -= 1;
            },
            else => {},
        }
    }
}

fn closerOf(opener: tokenizer_mod.TokenType) tokenizer_mod.TokenType {
    return switch (opener) {
        .left_bracket => .right_bracket,
        .left_brace => .right_brace,
        else => .right_paren,
    };
}

const Evaluator = struct {
    allocator: std.mem.Allocator,
    selector_check: ?SelectorCheck,

    /// <supports-condition> = not <supports-in-parens>
    ///   | <supports-in-parens> [ and <supports-in-parens> ]*
    ///   | <supports-in-parens> [ or <supports-in-parens> ]*
    /// The whole of `text`; null when it does not parse.
    fn condition(self: Evaluator, text: []const u8) ?bool {
        var tok = Tokenizer.init(text);
        tok.skipWhitespace();

        if (tok.peek().isIdent("not")) {
            _ = tok.next();
            // "White space (or a comment) is required after" not, and, or.
            if (!followedBySpace(&tok)) return null;
            tok.skipWhitespace();
            const operand = self.inParens(&tok) orelse return null;
            tok.skipWhitespace();
            if (!tok.peek().isEof()) return null;
            // "The result is the negation of the <supports-in-parens> term."
            return !operand;
        }

        var result = self.inParens(&tok) orelse return null;
        tok.skipWhitespace();
        if (tok.peek().isEof()) return result;

        // Mixing and and or needs a layer of parentheses: one operator only.
        const first = tok.peek();
        const op: []const u8 = if (first.isIdent("and")) "and" else if (first.isIdent("or")) "or" else return null;
        while (true) {
            const keyword = tok.next();
            if (!keyword.isIdent(op)) return null;
            if (!followedBySpace(&tok)) return null;
            tok.skipWhitespace();
            const operand = self.inParens(&tok) orelse return null;
            // and: "true if all of the <supports-in-parens> child terms are
            // true"; or: "false if all of them are false, and true otherwise".
            result = if (op[0] == 'a') result and operand else result or operand;
            tok.skipWhitespace();
            if (tok.peek().isEof()) return result;
        }
    }

    /// <supports-in-parens> = ( <supports-condition> ) | <supports-feature>
    ///   | <general-enclosed>
    /// <supports-feature> = <supports-selector-fn> | <supports-decl>
    /// <supports-decl> = ( <declaration> )
    /// <supports-selector-fn> = selector( <complex-selector> )
    /// <general-enclosed> = [ <function-token> <any-value>? ) ]
    ///   | [ ( <any-value>? ) ]  - "The result is false."
    fn inParens(self: Evaluator, tok: *Tokenizer) ?bool {
        const open = tok.next();
        switch (open.token_type) {
            .left_paren => {
                const inner = block(tok) orelse return null;
                if (self.condition(inner)) |result| return result;
                if (self.declaration(inner)) |result| return result;
                return false;
            },
            .function => {
                const inner = block(tok) orelse return null;
                if (tokenizer_mod.nameEql(open.value, "selector")) {
                    const check = self.selector_check orelse return false;
                    return check(self.allocator, std.mem.trim(u8, inner, " \t\n\r\x0C"));
                }
                return false;
            },
            else => return null,
        }
    }

    /// `inner` as `<ident> : <declaration-value> [! important]?`, evaluated
    /// as supportsDeclaration; null when it is not a declaration.
    fn declaration(self: Evaluator, inner: []const u8) ?bool {
        var tok = Tokenizer.init(inner);
        tok.skipWhitespace();
        const name = tok.next();
        if (name.token_type != .ident) return null;
        tok.skipWhitespace();
        if (tok.next().token_type != .colon) return null;
        var value = inner[tok.pos..];
        // "A trailing !important is allowed inside @supports, though it
        // won't change the validity of the declaration."
        value = stripImportant(value);
        return supportsDeclaration(self.allocator, name.value, value);
    }
};

/// The text between an opening token (already consumed) and its matching
/// `)`, consuming that too. Null if the block holds a bad string, a bad url
/// or an unmatched closer; EOF closes every open block, as CSS Syntax's
/// "consume a simple block" does.
fn block(tok: *Tokenizer) ?[]const u8 {
    const start = tok.pos;
    var closers: [64]tokenizer_mod.TokenType = undefined;
    closers[0] = .right_paren;
    var depth: usize = 1;
    while (true) {
        const before = tok.pos;
        const t = tok.next();
        switch (t.token_type) {
            .eof => return tok.input[start..],
            .bad_string, .bad_url => return null,
            .left_paren, .function, .left_bracket, .left_brace => {
                if (depth == closers.len) return null;
                closers[depth] = closerOf(t.token_type);
                depth += 1;
            },
            .right_paren, .right_bracket, .right_brace => {
                if (closers[depth - 1] != t.token_type) return null;
                depth -= 1;
                if (depth == 0) return tok.input[start..before];
            },
            else => {},
        }
    }
}

/// Is the next code point white space or the start of a comment?
fn followedBySpace(tok: *Tokenizer) bool {
    const rest = tok.input[tok.pos..];
    if (rest.len == 0) return false;
    return switch (rest[0]) {
        ' ', '\t', '\n', '\r', '\x0C' => true,
        '/' => rest.len > 1 and rest[1] == '*',
        else => false,
    };
}

/// `value` without a trailing `! important` (any case, white space allowed
/// around the `!`).
fn stripImportant(value: []const u8) []const u8 {
    const trimmed = std.mem.trimEnd(u8, value, " \t\n\r\x0C");
    if (trimmed.len < "important".len) return value;
    const word = trimmed[trimmed.len - "important".len ..];
    if (!std.ascii.eqlIgnoreCase(word, "important")) return value;
    const before = std.mem.trimEnd(u8, trimmed[0 .. trimmed.len - word.len], " \t\n\r\x0C");
    if (before.len == 0 or before[before.len - 1] != '!') return value;
    return before[0 .. before.len - 1];
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn decl(property: []const u8, value: []const u8) bool {
    return supportsDeclaration(testing.allocator, property, value);
}

fn cond(text: []const u8) bool {
    return supportsCondition(testing.allocator, text, &testSelectorCheck);
}

/// A stand-in for src/selector: `div`, `.a`, `a > b` parse; anything with
/// `:unknown` or a comma does not.
fn testSelectorCheck(allocator: std.mem.Allocator, text: []const u8) bool {
    _ = allocator;
    if (text.len == 0) return false;
    return std.mem.indexOf(u8, text, ":unknown") == null and std.mem.indexOfScalar(u8, text, ',') == null;
}

test "supports(property, value): a property Crane parses, with a value that parses for it" {
    try testing.expect(decl("color", "red"));
    try testing.expect(decl("color", "#00ff00"));
    try testing.expect(decl("background-color", "rgb(1, 2, 3)"));
    try testing.expect(decl("width", "10px"));
    try testing.expect(decl("width", " 10px "));
    // CSS-wide keywords are valid for every property.
    try testing.expect(decl("color", "inherit"));
    // ASCII case-insensitive property names.
    try testing.expect(decl("COLOR", "red"));
}

test "supports(property, value): false for values that do not parse, unknown properties, whitespace and !important" {
    try testing.expect(!decl("color", "10px"));
    try testing.expect(!decl("width", "red"));
    try testing.expect(!decl("color", "red blue"));
    try testing.expect(!decl("color", ""));
    try testing.expect(!decl("not-a-property", "red"));
    // "No whitespace or escape processing is done on the name."
    try testing.expect(!decl(" width", "5px"));
    // "!important flags are not part of property grammars."
    try testing.expect(!decl("color", "red !important"));
    try testing.expect(!decl("", "red"));
}

test "supports(property, value): a custom property takes any valid <declaration-value>" {
    try testing.expect(decl("--foo", "bar"));
    try testing.expect(decl("--foo", "{ a b c } [ 1 ] ( 2 )"));
    try testing.expect(decl("--foo", ""));
    // "must return false for invalid custom property values"
    try testing.expect(!decl("--foo", "a ; b"));
    try testing.expect(!decl("--foo", "a ) b"));
    try testing.expect(!decl("--foo", "red !important"));
    try testing.expect(!decl("--foo", "'unterminated\n'"));
}

test "supports(conditionText): a declaration in parentheses" {
    try testing.expect(cond("(color: red)"));
    try testing.expect(cond("( color : red )"));
    try testing.expect(cond("(color: red !important)"));
    try testing.expect(!cond("(color: 10px)"));
    try testing.expect(!cond("(not-a-property: red)"));
}

test "supports(conditionText): retried in parentheses, so a bare declaration works" {
    try testing.expect(cond("color: red"));
    try testing.expect(!cond("color: 10px"));
}

test "supports(conditionText): not, and, or" {
    try testing.expect(cond("not (color: 10px)"));
    try testing.expect(!cond("not (color: red)"));
    try testing.expect(cond("(color: red) and (width: 1px)"));
    try testing.expect(!cond("(color: red) and (width: red)"));
    try testing.expect(cond("(color: 10px) or (width: 1px)"));
    try testing.expect(!cond("(color: 10px) or (width: red)"));
    try testing.expect(cond("((color: red) and (width: 1px)) or (color: 1px)"));
    try testing.expect(cond("not ((color: 10px) or (width: red))"));
    try testing.expect(cond("(color: red) and (width: 1px) and (height: 2px)"));
}

test "supports(conditionText): mixing and with or without parentheses is invalid" {
    try testing.expect(!cond("(color: red) and (width: 1px) or (height: 2px)"));
}

test "supports(conditionText): white space is required after not, and, or" {
    try testing.expect(!cond("not(color: 10px)"));
    try testing.expect(cond("not/**/(color: 10px)"));
    try testing.expect(!cond("(color: red) and(width: 1px)"));
    // Before them it is not required.
    try testing.expect(cond("(color: red)and (width: 1px)"));
}

test "supports(conditionText): general-enclosed is false, and not of it is true" {
    try testing.expect(!cond("(unknown stuff)"));
    try testing.expect(!cond("foo(bar)"));
    try testing.expect(cond("not (unknown stuff)"));
    try testing.expect(cond("(color: red) or (unknown stuff)"));
}

test "supports(conditionText): selector()" {
    try testing.expect(cond("selector(div)"));
    try testing.expect(cond("selector( a > b )"));
    try testing.expect(!cond("selector(:unknown)"));
    try testing.expect(!cond("selector(a, b)"));
    try testing.expect(cond("not selector(:unknown)"));
    // With no selector check, selector() is false.
    try testing.expect(!supportsCondition(testing.allocator, "selector(div)", null));
}

test "supports(conditionText): never fails - garbage is false" {
    try testing.expect(!cond(""));
    try testing.expect(!cond("("));
    try testing.expect(!cond(")"));
    try testing.expect(!cond("(color: red))"));
    try testing.expect(!cond("'bad\n"));
    try testing.expect(!cond("not"));
    try testing.expect(!cond("and (color: red)"));
}

test "supports(conditionText): a long condition" {
    const big = try testing.allocator.alloc(u8, 64 * 1024);
    defer testing.allocator.free(big);
    @memset(big, ' ');
    const text = "(color: red)";
    @memcpy(big[big.len - text.len ..], text);
    try testing.expect(cond(big));
}
