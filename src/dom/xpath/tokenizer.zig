//! XPath 1.0 Tokenizer
//!
//! This module implements tokenization for XPath 1.0 expressions as specified by
//! the W3C XPath 1.0 Recommendation and referenced by WHATWG DOM Standard §6.4.
//!
//! ## W3C XPath 1.0 Specification
//!
//! - **XPath 1.0**: https://www.w3.org/TR/xpath-10/
//! - **§3.7 Lexical Structure**: https://www.w3.org/TR/xpath-10/#exprlex
//! - **Grammar**: https://www.w3.org/TR/xpath-10/#NT-ExprToken
//!
//! ## WHATWG DOM Specification
//!
//! - **§6.4 XPath**: https://dom.spec.whatwg.org/#xpath
//! - **XPathEvaluator**: https://dom.spec.whatwg.org/#xpathevaluator
//!
//! ## Core Features
//!
//! ### Lexical Analysis
//! Convert XPath expression string into token stream:
//! ```zig
//! const input = "child::para[position()=1]";
//! var tokenizer = Tokenizer.init(input);
//!
//! while (try tokenizer.next()) |token| {
//!     // Token{ .tag = .axis_name, .value = "child", ... }
//!     // Token{ .tag = .double_colon, ... }
//!     // Token{ .tag = .name_test, .value = "para", ... }
//!     // ... etc
//! }
//! ```
//!
//! ### XPath 1.0 Tokens
//! All tokens from XPath 1.0 specification:
//! ```zig
//! // Location paths
//! "child::para"       → axis_name + double_colon + name_test
//! "//"                → slash_slash
//! ".."                → dot_dot
//! "@attr"             → at_sign + name_test
//!
//! // Operators
//! "and", "or"         → operator_name
//! "+", "-", "*"       → operator
//! "=", "!=", "<="     → operator
//!
//! // Literals
//! "'text'"            → literal
//! "123.45"            → number
//! "$var"              → variable_reference
//!
//! // Functions & Node Tests
//! "position()"        → function_name + lparen + rparen
//! "text()"            → node_type + lparen + rparen
//! ```
//!
//! ### Context-Sensitive Tokenization
//! XPath requires lookahead and context for disambiguation:
//! - `*` can be MultiplyOperator OR NameTest (wildcard)
//! - NCName can be AxisName, NodeType, FunctionName, or NameTest
//! - Determined by following characters and preceding token
//!
//! ## Tokenization Rules (XPath 1.0 §3.7)
//!
//! Special disambiguation rules applied in order:
//!
//! 1. **Asterisk disambiguation**: If preceding token is NOT `@`, `::`, `(`, `[`, `,`,
//!    or an Operator, then `*` must be recognized as MultiplyOperator
//!
//! 2. **Function/NodeType**: If character following NCName (after whitespace) is `(`,
//!    then token must be NodeType or FunctionName
//!
//! 3. **AxisName**: If two characters following NCName (after whitespace) are `::`,
//!    then token must be AxisName
//!
//! 4. **Otherwise**: Token must NOT be MultiplyOperator, OperatorName, NodeType,
//!    FunctionName, or AxisName
//!
//! ## Memory Management
//!
//! Tokenizer uses zero-copy design:
//! ```zig
//! const input = "child::para";
//! var tokenizer = Tokenizer.init(input);
//! // No allocation - tokenizer is stack struct
//! // Tokens reference input string
//! ```
//!
//! ## Implementation Notes
//!
//! - Single-pass left-to-right scan
//! - Zero-copy token values (slices into input)
//! - Longest-match tokenization
//! - Whitespace freely allowed between tokens
//! - UTF-8 aware for international names

const std = @import("std");

/// Token types in XPath 1.0 expressions (§3.7 ExprToken)
pub const Token = struct {
    tag: Tag,
    value: []const u8,
    start: usize,
    end: usize,

    pub const Tag = enum {
        // Delimiters
        lparen, // (
        rparen, // )
        lbracket, // [
        rbracket, // ]

        // Single-character operators
        dot, // .
        at_sign, // @
        comma, // ,
        slash, // /
        pipe, // |
        plus, // +
        minus, // -
        equals, // =
        less_than, // <
        greater_than, // >

        // Multi-character operators
        dot_dot, // ..
        double_colon, // ::
        slash_slash, // //
        not_equals, // !=
        less_than_or_equal, // <=
        greater_than_or_equal, // >=

        // Operator keywords (OperatorName)
        operator_and, // and
        operator_or, // or
        operator_mod, // mod
        operator_div, // div

        // Multiply operator (context-sensitive!)
        multiply, // *

        // Node types (NodeType)
        node_type_comment, // comment
        node_type_text, // text
        node_type_processing_instruction, // processing-instruction
        node_type_node, // node

        // Axis names (AxisName) - 13 axes
        axis_ancestor,
        axis_ancestor_or_self,
        axis_attribute,
        axis_child,
        axis_descendant,
        axis_descendant_or_self,
        axis_following,
        axis_following_sibling,
        axis_namespace,
        axis_parent,
        axis_preceding,
        axis_preceding_sibling,
        axis_self,

        // Literals
        literal, // "..." or '...'
        number, // Digits | Digits.Digits | .Digits

        // Identifiers
        name_test, // NCName | QName | * | NCName:*
        function_name, // QName (followed by '(')

        // Variables
        variable_reference, // $QName

        // End of input
        eof,
    };
};

/// XPath 1.0 Tokenizer
///
/// Implements lexical analysis per XPath 1.0 §3.7.
/// Uses zero-copy design with tokens as slices into input string.
pub const Tokenizer = struct {
    input: []const u8,
    pos: usize,
    prev_token_tag: ?Token.Tag, // For context-sensitive tokenization

    pub fn init(input: []const u8) Tokenizer {
        return .{
            .input = input,
            .pos = 0,
            .prev_token_tag = null,
        };
    }

    /// Get next token from input
    pub fn next(self: *Tokenizer) !?Token {
        // Skip whitespace
        self.skipWhitespace();

        if (self.pos >= self.input.len) {
            return Token{
                .tag = .eof,
                .value = "",
                .start = self.pos,
                .end = self.pos,
            };
        }

        const start = self.pos;
        const c = self.input[self.pos];

        // Try multi-character operators first (longest match)
        const token = try self.scanToken(start, c);
        self.prev_token_tag = token.tag;
        return token;
    }

    fn scanToken(self: *Tokenizer, start: usize, c: u8) !Token {
        // Multi-character operators (check first for longest match)
        if (c == '.') {
            if (self.peek(1) == '.') {
                self.pos += 2;
                return self.makeToken(.dot_dot, start);
            }
            // Check if it's start of a number (.Digits)
            if (self.peek(1)) |next_c| {
                if (std.ascii.isDigit(next_c)) {
                    return try self.scanNumber(start);
                }
            }
            self.pos += 1;
            return self.makeToken(.dot, start);
        }

        if (c == ':') {
            if (self.peek(1) == ':') {
                self.pos += 2;
                return self.makeToken(.double_colon, start);
            }
            // Single ':' is part of QName, not a token
            return error.UnexpectedColon;
        }

        if (c == '/') {
            if (self.peek(1) == '/') {
                self.pos += 2;
                return self.makeToken(.slash_slash, start);
            }
            self.pos += 1;
            return self.makeToken(.slash, start);
        }

        if (c == '!') {
            if (self.peek(1) == '=') {
                self.pos += 2;
                return self.makeToken(.not_equals, start);
            }
            return error.UnexpectedExclamation;
        }

        if (c == '<') {
            if (self.peek(1) == '=') {
                self.pos += 2;
                return self.makeToken(.less_than_or_equal, start);
            }
            self.pos += 1;
            return self.makeToken(.less_than, start);
        }

        if (c == '>') {
            if (self.peek(1) == '=') {
                self.pos += 2;
                return self.makeToken(.greater_than_or_equal, start);
            }
            self.pos += 1;
            return self.makeToken(.greater_than, start);
        }

        // Single-character delimiters
        const single_char_tokens = .{
            .{ '(', Token.Tag.lparen },
            .{ ')', Token.Tag.rparen },
            .{ '[', Token.Tag.lbracket },
            .{ ']', Token.Tag.rbracket },
            .{ '@', Token.Tag.at_sign },
            .{ ',', Token.Tag.comma },
            .{ '|', Token.Tag.pipe },
            .{ '+', Token.Tag.plus },
            .{ '-', Token.Tag.minus },
            .{ '=', Token.Tag.equals },
        };

        inline for (single_char_tokens) |pair| {
            if (c == pair[0]) {
                self.pos += 1;
                return self.makeToken(pair[1], start);
            }
        }

        // Asterisk (context-sensitive!)
        if (c == '*') {
            return try self.scanAsterisk(start);
        }

        // String literals
        if (c == '"' or c == '\'') {
            return try self.scanLiteral(start, c);
        }

        // Numbers (Digits.Digits? or .Digits handled above)
        if (std.ascii.isDigit(c)) {
            return try self.scanNumber(start);
        }

        // Variable reference
        if (c == '$') {
            return try self.scanVariableReference(start);
        }

        // NCName-based tokens (axis, node type, function, name test)
        if (isNCNameStart(c)) {
            return try self.scanNCName(start);
        }

        // Unknown character
        return error.UnexpectedCharacter;
    }

    /// Scan asterisk with context-sensitive disambiguation (XPath 1.0 §3.7)
    ///
    /// Rule: If preceding token is NOT one of @, ::, (, [, ,, or Operator,
    /// then * must be MultiplyOperator
    fn scanAsterisk(self: *Tokenizer, start: usize) !Token {
        self.pos += 1;

        // Check if this should be multiply operator based on previous token
        if (self.prev_token_tag) |prev| {
            const allows_name_test = switch (prev) {
                .at_sign, .double_colon, .lparen, .lbracket, .comma => true,
                // Any operator allows name test (not multiply)
                .slash,
                .pipe,
                .plus,
                .minus,
                .equals,
                .less_than,
                .greater_than,
                .slash_slash,
                .not_equals,
                .less_than_or_equal,
                .greater_than_or_equal,
                .operator_and,
                .operator_or,
                .operator_mod,
                .operator_div,
                => true,
                else => false,
            };

            if (!allows_name_test) {
                return self.makeToken(.multiply, start);
            }
        }

        // Check if followed by : for NCName:* pattern
        self.skipWhitespace();
        if (self.pos < self.input.len and self.input[self.pos] == ':') {
            // This is actually part of a NameTest like "NCName:*"
            // Back up and re-scan as name test
            return error.InvalidNameTest; // Caller should handle
        }

        return self.makeToken(.name_test, start);
    }

    /// Scan string literal (Literal production)
    fn scanLiteral(self: *Tokenizer, start: usize, quote: u8) !Token {
        self.pos += 1; // Skip opening quote
        const lit_start = self.pos;

        while (self.pos < self.input.len) {
            if (self.input[self.pos] == quote) {
                const lit_end = self.pos;
                self.pos += 1; // Skip closing quote
                return Token{
                    .tag = .literal,
                    .value = self.input[lit_start..lit_end],
                    .start = start,
                    .end = self.pos,
                };
            }
            self.pos += 1;
        }

        return error.UnterminatedLiteral;
    }

    /// Scan number (Number production: Digits | Digits.Digits | .Digits)
    fn scanNumber(self: *Tokenizer, start: usize) !Token {
        // Optional leading digits
        while (self.pos < self.input.len and std.ascii.isDigit(self.input[self.pos])) {
            self.pos += 1;
        }

        // Optional decimal point with trailing digits
        if (self.pos < self.input.len and self.input[self.pos] == '.') {
            self.pos += 1;
            while (self.pos < self.input.len and std.ascii.isDigit(self.input[self.pos])) {
                self.pos += 1;
            }
        }

        return self.makeToken(.number, start);
    }

    /// Scan variable reference ($QName)
    fn scanVariableReference(self: *Tokenizer, start: usize) !Token {
        self.pos += 1; // Skip $

        if (self.pos >= self.input.len or !isNCNameStart(self.input[self.pos])) {
            return error.InvalidVariableReference;
        }

        // Scan QName (NCName:NCName or NCName)
        while (self.pos < self.input.len and isNCNameChar(self.input[self.pos])) {
            self.pos += 1;
        }

        // Optional :NCName for qualified name
        if (self.pos < self.input.len and self.input[self.pos] == ':') {
            self.pos += 1;
            if (self.pos >= self.input.len or !isNCNameStart(self.input[self.pos])) {
                return error.InvalidVariableReference;
            }
            while (self.pos < self.input.len and isNCNameChar(self.input[self.pos])) {
                self.pos += 1;
            }
        }

        return self.makeToken(.variable_reference, start);
    }

    /// Scan NCName-based token (axis, node type, function, or name test)
    ///
    /// Uses lookahead to disambiguate (XPath 1.0 §3.7 special rules 2-4)
    fn scanNCName(self: *Tokenizer, start: usize) !Token {
        // Scan NCName
        while (self.pos < self.input.len and isNCNameChar(self.input[self.pos])) {
            self.pos += 1;
        }

        const name = self.input[start..self.pos];

        // Look ahead for disambiguation
        const saved_pos = self.pos;
        self.skipWhitespace();

        // Rule 3: If followed by '::', it's an AxisName
        if (self.pos + 1 < self.input.len and
            self.input[self.pos] == ':' and
            self.input[self.pos + 1] == ':')
        {
            self.pos = saved_pos;
            return try self.classifyAxisName(name, start);
        }

        // Rule 2: If followed by '(', it's NodeType or FunctionName
        if (self.pos < self.input.len and self.input[self.pos] == '(') {
            self.pos = saved_pos;
            return try self.classifyNodeTypeOrFunction(name, start);
        }

        // Check for QName (NCName:NCName) or NameTest (NCName:*)
        if (self.pos < self.input.len and self.input[self.pos] == ':') {
            self.pos = saved_pos;
            return try self.scanQualifiedName(start);
        }

        // Rule 4: Otherwise, check if it's an OperatorName
        self.pos = saved_pos;
        if (std.mem.eql(u8, name, "and")) {
            return self.makeToken(.operator_and, start);
        }
        if (std.mem.eql(u8, name, "or")) {
            return self.makeToken(.operator_or, start);
        }
        if (std.mem.eql(u8, name, "mod")) {
            return self.makeToken(.operator_mod, start);
        }
        if (std.mem.eql(u8, name, "div")) {
            return self.makeToken(.operator_div, start);
        }

        // Default: NameTest
        return self.makeToken(.name_test, start);
    }

    /// Classify NCName as an AxisName (XPath 1.0 §2.2)
    fn classifyAxisName(self: *Tokenizer, name: []const u8, start: usize) !Token {
        const axis_map = .{
            .{ "ancestor", Token.Tag.axis_ancestor },
            .{ "ancestor-or-self", Token.Tag.axis_ancestor_or_self },
            .{ "attribute", Token.Tag.axis_attribute },
            .{ "child", Token.Tag.axis_child },
            .{ "descendant", Token.Tag.axis_descendant },
            .{ "descendant-or-self", Token.Tag.axis_descendant_or_self },
            .{ "following", Token.Tag.axis_following },
            .{ "following-sibling", Token.Tag.axis_following_sibling },
            .{ "namespace", Token.Tag.axis_namespace },
            .{ "parent", Token.Tag.axis_parent },
            .{ "preceding", Token.Tag.axis_preceding },
            .{ "preceding-sibling", Token.Tag.axis_preceding_sibling },
            .{ "self", Token.Tag.axis_self },
        };

        inline for (axis_map) |pair| {
            if (std.mem.eql(u8, name, pair[0])) {
                return self.makeToken(pair[1], start);
            }
        }

        return error.InvalidAxisName;
    }

    /// Classify NCName as NodeType or FunctionName (XPath 1.0 §2.3, §3.2)
    fn classifyNodeTypeOrFunction(self: *Tokenizer, name: []const u8, start: usize) !Token {
        // Check if it's a NodeType
        if (std.mem.eql(u8, name, "comment")) {
            return self.makeToken(.node_type_comment, start);
        }
        if (std.mem.eql(u8, name, "text")) {
            return self.makeToken(.node_type_text, start);
        }
        if (std.mem.eql(u8, name, "processing-instruction")) {
            return self.makeToken(.node_type_processing_instruction, start);
        }
        if (std.mem.eql(u8, name, "node")) {
            return self.makeToken(.node_type_node, start);
        }

        // Otherwise it's a FunctionName
        return self.makeToken(.function_name, start);
    }

    /// Scan qualified name (NCName:NCName or NCName:*)
    fn scanQualifiedName(self: *Tokenizer, start: usize) !Token {
        // We've already scanned the first NCName
        // Now scan : and second part
        self.pos += 1; // Skip ':'

        if (self.pos >= self.input.len) {
            return error.InvalidQName;
        }

        // Second part can be * or NCName
        if (self.input[self.pos] == '*') {
            self.pos += 1;
            return self.makeToken(.name_test, start);
        }

        if (!isNCNameStart(self.input[self.pos])) {
            return error.InvalidQName;
        }

        while (self.pos < self.input.len and isNCNameChar(self.input[self.pos])) {
            self.pos += 1;
        }

        return self.makeToken(.name_test, start);
    }

    fn makeToken(self: *Tokenizer, tag: Token.Tag, start: usize) Token {
        return Token{
            .tag = tag,
            .value = self.input[start..self.pos],
            .start = start,
            .end = self.pos,
        };
    }

    fn skipWhitespace(self: *Tokenizer) void {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    fn peek(self: *Tokenizer, offset: usize) ?u8 {
        const index = self.pos + offset;
        if (index >= self.input.len) return null;
        return self.input[index];
    }
};

/// Check if character can start an NCName (XML Namespaces §2)
fn isNCNameStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_' or c >= 0x80; // Simplified for ASCII + high bit
}

/// Check if character can continue an NCName
fn isNCNameChar(c: u8) bool {
    return isNCNameStart(c) or std.ascii.isDigit(c) or c == '-' or c == '.';
}

// ============================================================================
// Tests
// ============================================================================

test "tokenizer - single characters" {
    const test_cases = .{
        .{ "(", Token.Tag.lparen },
        .{ ")", Token.Tag.rparen },
        .{ "[", Token.Tag.lbracket },
        .{ "]", Token.Tag.rbracket },
        .{ "@", Token.Tag.at_sign },
        .{ ",", Token.Tag.comma },
        .{ "/", Token.Tag.slash },
        .{ "|", Token.Tag.pipe },
        .{ "+", Token.Tag.plus },
        .{ "-", Token.Tag.minus },
        .{ "=", Token.Tag.equals },
        .{ "<", Token.Tag.less_than },
        .{ ">", Token.Tag.greater_than },
    };

    inline for (test_cases) |tc| {
        var tokenizer = Tokenizer.init(tc[0]);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(tc[1], token.tag);
        try std.testing.expectEqualStrings(tc[0], token.value);
    }
}

test "tokenizer - multi-character operators" {
    const test_cases = .{
        .{ "..", Token.Tag.dot_dot },
        .{ "::", Token.Tag.double_colon },
        .{ "//", Token.Tag.slash_slash },
        .{ "!=", Token.Tag.not_equals },
        .{ "<=", Token.Tag.less_than_or_equal },
        .{ ">=", Token.Tag.greater_than_or_equal },
    };

    inline for (test_cases) |tc| {
        var tokenizer = Tokenizer.init(tc[0]);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(tc[1], token.tag);
        try std.testing.expectEqualStrings(tc[0], token.value);
    }
}

test "tokenizer - operator keywords" {
    const test_cases = .{
        .{ "and", Token.Tag.operator_and },
        .{ "or", Token.Tag.operator_or },
        .{ "mod", Token.Tag.operator_mod },
        .{ "div", Token.Tag.operator_div },
    };

    inline for (test_cases) |tc| {
        var tokenizer = Tokenizer.init(tc[0]);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(tc[1], token.tag);
        try std.testing.expectEqualStrings(tc[0], token.value);
    }
}

test "tokenizer - literals" {
    var tokenizer = Tokenizer.init("\"hello world\"");
    const tok1 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.literal, tok1.tag);
    try std.testing.expectEqualStrings("hello world", tok1.value);

    tokenizer = Tokenizer.init("'single quotes'");
    const tok2 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.literal, tok2.tag);
    try std.testing.expectEqualStrings("single quotes", tok2.value);
}

test "tokenizer - numbers" {
    const test_cases = .{
        "123",
        "123.45",
        ".5",
        "0.001",
    };

    inline for (test_cases) |input| {
        var tokenizer = Tokenizer.init(input);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(Token.Tag.number, token.tag);
        try std.testing.expectEqualStrings(input, token.value);
    }
}

test "tokenizer - variable reference" {
    var tokenizer = Tokenizer.init("$myVar");
    const token = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.variable_reference, token.tag);
    try std.testing.expectEqualStrings("$myVar", token.value);
}

test "tokenizer - axis names" {
    var tokenizer = Tokenizer.init("child::para");

    const tok1 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.axis_child, tok1.tag);

    const tok2 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.double_colon, tok2.tag);

    const tok3 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.name_test, tok3.tag);
    try std.testing.expectEqualStrings("para", tok3.value);
}

test "tokenizer - node types" {
    const test_cases = .{
        .{ "text()", Token.Tag.node_type_text },
        .{ "comment()", Token.Tag.node_type_comment },
        .{ "node()", Token.Tag.node_type_node },
    };

    inline for (test_cases) |tc| {
        var tokenizer = Tokenizer.init(tc[0]);
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(tc[1], token.tag);
    }
}

test "tokenizer - function calls" {
    var tokenizer = Tokenizer.init("position()");
    const tok1 = (try tokenizer.next()).?;
    try std.testing.expectEqual(Token.Tag.function_name, tok1.tag);
    try std.testing.expectEqualStrings("position", tok1.value);
}

test "tokenizer - asterisk disambiguation" {
    // After operator - should be name test
    var tokenizer1 = Tokenizer.init("/ *");
    _ = try tokenizer1.next(); // /
    const tok1 = (try tokenizer1.next()).?;
    try std.testing.expectEqual(Token.Tag.name_test, tok1.tag);

    // After name - should be multiply
    var tokenizer2 = Tokenizer.init("5 * 3");
    _ = try tokenizer2.next(); // 5
    const tok2 = (try tokenizer2.next()).?;
    try std.testing.expectEqual(Token.Tag.multiply, tok2.tag);
}

test "tokenizer - complex expression" {
    const input = "child::para[position()=1]";
    var tokenizer = Tokenizer.init(input);

    const expected = [_]Token.Tag{
        .axis_child,
        .double_colon,
        .name_test,
        .lbracket,
        .function_name,
        .lparen,
        .rparen,
        .equals,
        .number,
        .rbracket,
        .eof,
    };

    for (expected) |expected_tag| {
        const token = (try tokenizer.next()).?;
        try std.testing.expectEqual(expected_tag, token.tag);
    }
}
