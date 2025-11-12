const std = @import("std");
const Allocator = std.mem.Allocator;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const ArrayList = std.ArrayList;

// ============================================================================
// AST Node Types
// ============================================================================

/// Top-level selector list (comma-separated selectors)
pub const SelectorList = struct {
    selectors: []ComplexSelector,
    allocator: Allocator,

    pub fn deinit(self: *SelectorList) void {
        for (self.selectors) |*selector| {
            selector.deinit();
        }
        self.allocator.free(self.selectors);
    }
};

/// Complex selector (combinator chain)
pub const ComplexSelector = struct {
    compound: CompoundSelector,
    combinators: []CombinatorPair,
    allocator: Allocator,
    /// If true, this is a relative selector (starts with combinator)
    /// Used in :has() for relative matching
    is_relative: bool = false,
    /// For relative selectors, the initial combinator
    initial_combinator: ?Combinator = null,

    pub fn deinit(self: *ComplexSelector) void {
        self.compound.deinit();
        for (self.combinators) |*pair| {
            pair.compound.deinit();
        }
        self.allocator.free(self.combinators);
    }
};

/// Combinator with associated compound selector
pub const CombinatorPair = struct {
    combinator: Combinator,
    compound: CompoundSelector,
};

/// Combinator types
pub const Combinator = enum {
    Descendant, // space (whitespace)
    Child, // >
    NextSibling, // +
    SubsequentSibling, // ~
};

/// Compound selector (multiple simple selectors for same element)
pub const CompoundSelector = struct {
    simple_selectors: []SimpleSelector,
    allocator: Allocator,

    pub fn deinit(self: *CompoundSelector) void {
        for (self.simple_selectors) |*selector| {
            selector.deinit(self.allocator);
        }
        self.allocator.free(self.simple_selectors);
    }
};

/// Simple selector (atomic selector)
pub const SimpleSelector = union(enum) {
    Universal,
    Type: struct { tag_name: []const u8 },
    Class: struct { class_name: []const u8 },
    Id: struct { id: []const u8 },
    Attribute: AttributeSelector,
    PseudoClass: PseudoClassSelector,
    PseudoElement: PseudoElementSelector,

    pub fn deinit(self: *SimpleSelector, allocator: Allocator) void {
        switch (self.*) {
            .PseudoClass => |*pseudo| pseudo.deinit(allocator),
            .PseudoElement => |*pseudo| pseudo.deinit(allocator),
            else => {},
        }
    }
};

/// Attribute selector
pub const AttributeSelector = struct {
    name: []const u8,
    matcher: AttributeMatcher,
    case_sensitive: bool = true,
};

/// Attribute matching operators
pub const AttributeMatcher = union(enum) {
    Presence, // [attr]
    Exact: struct { value: []const u8 }, // [attr="value"]
    Prefix: struct { value: []const u8 }, // [attr^="value"]
    Suffix: struct { value: []const u8 }, // [attr$="value"]
    Substring: struct { value: []const u8 }, // [attr*="value"]
    Includes: struct { value: []const u8 }, // [attr~="value"]
    DashMatch: struct { value: []const u8 }, // [attr|="value"]
};

/// Pseudo-class selector
pub const PseudoClassSelector = struct {
    kind: PseudoClassKind,

    pub fn deinit(self: *PseudoClassSelector, allocator: Allocator) void {
        switch (self.kind) {
            .Not, .Is, .Where, .Has => |selector_list_ptr| {
                selector_list_ptr.deinit();
                allocator.destroy(selector_list_ptr);
            },
            else => {},
        }
    }
};

/// Direction for :dir() pseudo-class
pub const Direction = enum {
    ltr,
    rtl,
};

/// Pseudo-class types
pub const PseudoClassKind = union(enum) {
    // Structural pseudo-classes
    FirstChild,
    LastChild,
    OnlyChild,
    FirstOfType,
    LastOfType,
    OnlyOfType,
    Empty,
    Root,

    // Nth pseudo-classes
    NthChild: NthPattern,
    NthLastChild: NthPattern,
    NthOfType: NthPattern,
    NthLastOfType: NthPattern,

    // Link pseudo-classes
    AnyLink,
    Link,
    Visited,

    // User action pseudo-classes
    Hover,
    Active,
    Focus,
    FocusVisible,
    FocusWithin,

    // Input pseudo-classes
    Enabled,
    Disabled,
    ReadOnly,
    ReadWrite,
    Checked,

    // Language pseudo-classes
    Lang: []const u8,
    Dir: Direction,

    // Negation and matching
    Not: *SelectorList,
    Is: *SelectorList,
    Where: *SelectorList,
    Has: *SelectorList,
};

/// Nth pattern (an+b)
pub const NthPattern = struct {
    a: i32, // Coefficient
    b: i32, // Constant
};

/// Pseudo-element selector
pub const PseudoElementSelector = struct {
    name: []const u8,

    pub fn deinit(_: *PseudoElementSelector, _: Allocator) void {
        // No dynamic allocation, nothing to free
    }
};

// ============================================================================
// Parser Errors
// ============================================================================

pub const ParserError = error{
    UnexpectedToken,
    UnexpectedEOF,
    InvalidSelector,
    OutOfMemory,
};

// ============================================================================
// Parser
// ============================================================================

pub const Parser = struct {
    allocator: Allocator,
    tokenizer: *Tokenizer,
    current_token: ?Token = null,
    peeked_token: ?Token = null,

    pub fn init(allocator: Allocator, tokenizer: *Tokenizer) !Parser {
        var parser = Parser{
            .allocator = allocator,
            .tokenizer = tokenizer,
        };
        // Prime the parser with first token
        try parser.advance();
        return parser;
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
        // Parser doesn't own AST nodes after parse() returns
        // Caller responsible for calling SelectorList.deinit()
    }

    /// Parse complete selector list
    pub fn parse(self: *Parser) ParserError!SelectorList {
        return try self.parseSelectorList();
    }

    // ========================================================================
    // Grammar Rules
    // ========================================================================

    /// Parse selector list (comma-separated complex selectors)
    fn parseSelectorList(self: *Parser) ParserError!SelectorList {
        var selectors = ArrayList(ComplexSelector){};
        errdefer {
            for (selectors.items) |*selector| {
                selector.deinit();
            }
            selectors.deinit(self.allocator);
        }

        // Parse first complex selector
        try selectors.append(self.allocator, try self.parseComplexSelector());

        // Parse additional selectors (comma-separated)
        while (self.current_token) |token| {
            if (token.tag == .comma) {
                try self.advance();
                self.skipWhitespace();
                try selectors.append(self.allocator, try self.parseComplexSelector());
            } else {
                break;
            }
        }

        return SelectorList{
            .selectors = try selectors.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
        };
    }

    /// Parse complex selector (combinator chain)
    fn parseComplexSelector(self: *Parser) ParserError!ComplexSelector {
        var combinators = ArrayList(CombinatorPair){};
        errdefer {
            for (combinators.items) |*pair| {
                pair.compound.deinit();
            }
            combinators.deinit(self.allocator);
        }

        // Check for relative selector (starts with combinator)
        var is_relative = false;
        var initial_combinator: ?Combinator = null;

        // Peek ahead for combinator at start (relative selector)
        const first_combinator = try self.parseCombinator();
        if (first_combinator) |comb| {
            is_relative = true;
            initial_combinator = comb;
            self.skipWhitespace();
        }

        // Parse first compound selector
        const first_compound = try self.parseCompoundSelector();

        // Parse combinator chain
        while (true) {
            // Check for combinator
            const combinator = try self.parseCombinator();
            if (combinator == null) break;

            self.skipWhitespace();

            // Parse next compound selector
            const next_compound = try self.parseCompoundSelector();

            try combinators.append(self.allocator, CombinatorPair{
                .combinator = combinator.?,
                .compound = next_compound,
            });
        }

        return ComplexSelector{
            .compound = first_compound,
            .combinators = try combinators.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
            .is_relative = is_relative,
            .initial_combinator = initial_combinator,
        };
    }

    /// Parse combinator (>, +, ~, or whitespace)
    fn parseCombinator(self: *Parser) ParserError!?Combinator {
        const token = self.current_token orelse return null;

        return switch (token.tag) {
            .gt => blk: {
                try self.advance();
                break :blk Combinator.Child;
            },
            .plus => blk: {
                try self.advance();
                break :blk Combinator.NextSibling;
            },
            .tilde => blk: {
                try self.advance();
                break :blk Combinator.SubsequentSibling;
            },
            .whitespace => blk: {
                try self.advance();
                // Peek ahead - if next token is combinator, this whitespace is just spacing
                if (self.current_token) |next_token| {
                    if (next_token.tag == .gt or next_token.tag == .plus or next_token.tag == .tilde) {
                        return try self.parseCombinator();
                    }
                }
                // Whitespace followed by compound selector = descendant combinator
                if (self.isCompoundStart()) {
                    break :blk Combinator.Descendant;
                }
                // Whitespace at end of selector
                return null;
            },
            else => null,
        };
    }

    /// Parse compound selector (one or more simple selectors)
    fn parseCompoundSelector(self: *Parser) ParserError!CompoundSelector {
        var simple_selectors = ArrayList(SimpleSelector){};
        errdefer {
            for (simple_selectors.items) |*selector| {
                selector.deinit(self.allocator);
            }
            simple_selectors.deinit(self.allocator);
        }

        // Parse first simple selector
        try simple_selectors.append(self.allocator, try self.parseSimpleSelector());

        // Parse additional simple selectors (no whitespace between)
        while (self.isSimpleSelectorStart()) {
            try simple_selectors.append(self.allocator, try self.parseSimpleSelector());
        }

        if (simple_selectors.items.len == 0) {
            return error.InvalidSelector;
        }

        return CompoundSelector{
            .simple_selectors = try simple_selectors.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
        };
    }

    /// Parse simple selector
    fn parseSimpleSelector(self: *Parser) ParserError!SimpleSelector {
        const token = self.current_token orelse return error.UnexpectedEOF;

        return switch (token.tag) {
            .asterisk => blk: {
                try self.advance();
                break :blk SimpleSelector.Universal;
            },
            .ident => blk: {
                const tag_name = token.value;
                try self.advance();
                break :blk SimpleSelector{ .Type = .{ .tag_name = tag_name } };
            },
            .dot => blk: {
                try self.advance();
                const class_token = self.current_token orelse return error.UnexpectedEOF;
                if (class_token.tag != .ident) return error.InvalidSelector;
                const class_name = class_token.value;
                try self.advance();
                break :blk SimpleSelector{ .Class = .{ .class_name = class_name } };
            },
            .hash => blk: {
                const id = token.value;
                try self.advance();
                break :blk SimpleSelector{ .Id = .{ .id = id } };
            },
            .lbracket => blk: {
                break :blk SimpleSelector{ .Attribute = try self.parseAttribute() };
            },
            .colon => blk: {
                try self.advance();
                // Check for pseudo-element (::)
                if (self.current_token) |next_token| {
                    if (next_token.tag == .colon) {
                        try self.advance();
                        return try self.parsePseudoElement();
                    }
                }
                break :blk SimpleSelector{ .PseudoClass = try self.parsePseudoClass() };
            },
            else => error.InvalidSelector,
        };
    }

    /// Parse attribute selector
    fn parseAttribute(self: *Parser) ParserError!AttributeSelector {
        // Consume '['
        try self.expectToken(.lbracket);
        try self.advance();

        // Parse attribute name
        const name_token = self.current_token orelse return error.UnexpectedEOF;
        if (name_token.tag != .ident) return error.InvalidSelector;
        const name = name_token.value;
        try self.advance();

        // Check for matcher operator
        const token = self.current_token orelse return error.UnexpectedEOF;

        var matcher: AttributeMatcher = undefined;

        switch (token.tag) {
            .rbracket => {
                // [attr] - presence only
                matcher = AttributeMatcher.Presence;
            },
            .equals => {
                try self.advance();
                const value = try self.parseAttributeValue();
                matcher = AttributeMatcher{ .Exact = .{ .value = value } };
            },
            .prefix_match => {
                try self.advance();
                const value = try self.parseAttributeValue();
                matcher = AttributeMatcher{ .Prefix = .{ .value = value } };
            },
            .suffix_match => {
                try self.advance();
                const value = try self.parseAttributeValue();
                matcher = AttributeMatcher{ .Suffix = .{ .value = value } };
            },
            .substring_match => {
                try self.advance();
                const value = try self.parseAttributeValue();
                matcher = AttributeMatcher{ .Substring = .{ .value = value } };
            },
            .includes_match => {
                try self.advance();
                const value = try self.parseAttributeValue();
                matcher = AttributeMatcher{ .Includes = .{ .value = value } };
            },
            .dash_match => {
                try self.advance();
                const value = try self.parseAttributeValue();
                matcher = AttributeMatcher{ .DashMatch = .{ .value = value } };
            },
            else => return error.InvalidSelector,
        }

        // Consume ']'
        try self.expectToken(.rbracket);
        try self.advance();

        return AttributeSelector{
            .name = name,
            .matcher = matcher,
        };
    }

    /// Parse attribute value (string or identifier)
    fn parseAttributeValue(self: *Parser) ParserError![]const u8 {
        const token = self.current_token orelse return error.UnexpectedEOF;
        const value = switch (token.tag) {
            .string, .ident => token.value,
            else => return error.InvalidSelector,
        };
        try self.advance();
        return value;
    }

    /// Parse pseudo-class selector
    fn parsePseudoClass(self: *Parser) ParserError!PseudoClassSelector {
        const name_token = self.current_token orelse return error.UnexpectedEOF;
        if (name_token.tag != .ident) return error.InvalidSelector;
        const name = name_token.value;
        try self.advance();

        // Check for function pseudo-class (with parentheses)
        if (self.current_token) |token| {
            if (token.tag == .lparen) {
                return try self.parseFunctionalPseudoClass(name);
            }
        }

        // Simple pseudo-class (no arguments)
        const kind = try self.parsePseudoClassName(name);
        return PseudoClassSelector{ .kind = kind };
    }

    /// Parse pseudo-class name without arguments
    fn parsePseudoClassName(_: *Parser, name: []const u8) ParserError!PseudoClassKind {
        if (std.mem.eql(u8, name, "first-child")) return .FirstChild;
        if (std.mem.eql(u8, name, "last-child")) return .LastChild;
        if (std.mem.eql(u8, name, "only-child")) return .OnlyChild;
        if (std.mem.eql(u8, name, "first-of-type")) return .FirstOfType;
        if (std.mem.eql(u8, name, "last-of-type")) return .LastOfType;
        if (std.mem.eql(u8, name, "only-of-type")) return .OnlyOfType;
        if (std.mem.eql(u8, name, "empty")) return .Empty;
        if (std.mem.eql(u8, name, "root")) return .Root;
        if (std.mem.eql(u8, name, "any-link")) return .AnyLink;
        if (std.mem.eql(u8, name, "link")) return .Link;
        if (std.mem.eql(u8, name, "visited")) return .Visited;
        if (std.mem.eql(u8, name, "hover")) return .Hover;
        if (std.mem.eql(u8, name, "active")) return .Active;
        if (std.mem.eql(u8, name, "focus")) return .Focus;
        if (std.mem.eql(u8, name, "focus-visible")) return .FocusVisible;
        if (std.mem.eql(u8, name, "focus-within")) return .FocusWithin;
        if (std.mem.eql(u8, name, "enabled")) return .Enabled;
        if (std.mem.eql(u8, name, "disabled")) return .Disabled;
        if (std.mem.eql(u8, name, "read-only")) return .ReadOnly;
        if (std.mem.eql(u8, name, "read-write")) return .ReadWrite;
        if (std.mem.eql(u8, name, "checked")) return .Checked;

        return error.InvalidSelector;
    }

    /// Parse functional pseudo-class (with arguments)
    fn parseFunctionalPseudoClass(self: *Parser, name: []const u8) ParserError!PseudoClassSelector {
        // Consume '('
        try self.expectToken(.lparen);
        try self.advance();
        self.skipWhitespace();

        var kind: PseudoClassKind = undefined;

        // Check pseudo-class type
        if (std.mem.eql(u8, name, "nth-child")) {
            const pattern = try self.parseNthPattern();
            kind = PseudoClassKind{ .NthChild = pattern };
        } else if (std.mem.eql(u8, name, "nth-last-child")) {
            const pattern = try self.parseNthPattern();
            kind = PseudoClassKind{ .NthLastChild = pattern };
        } else if (std.mem.eql(u8, name, "nth-of-type")) {
            const pattern = try self.parseNthPattern();
            kind = PseudoClassKind{ .NthOfType = pattern };
        } else if (std.mem.eql(u8, name, "nth-last-of-type")) {
            const pattern = try self.parseNthPattern();
            kind = PseudoClassKind{ .NthLastOfType = pattern };
        } else if (std.mem.eql(u8, name, "not")) {
            const selector_list = try self.allocator.create(SelectorList);
            selector_list.* = try self.parseSelectorList();
            kind = PseudoClassKind{ .Not = selector_list };
        } else if (std.mem.eql(u8, name, "is")) {
            const selector_list = try self.allocator.create(SelectorList);
            selector_list.* = try self.parseSelectorList();
            kind = PseudoClassKind{ .Is = selector_list };
        } else if (std.mem.eql(u8, name, "where")) {
            const selector_list = try self.allocator.create(SelectorList);
            selector_list.* = try self.parseSelectorList();
            kind = PseudoClassKind{ .Where = selector_list };
        } else if (std.mem.eql(u8, name, "has")) {
            const selector_list = try self.allocator.create(SelectorList);
            selector_list.* = try self.parseSelectorList();
            kind = PseudoClassKind{ .Has = selector_list };
        } else if (std.mem.eql(u8, name, "lang")) {
            const lang_code = try self.parseLanguageCode();
            kind = PseudoClassKind{ .Lang = lang_code };
        } else if (std.mem.eql(u8, name, "dir")) {
            const direction = try self.parseDirection();
            kind = PseudoClassKind{ .Dir = direction };
        } else {
            return error.InvalidSelector;
        }

        self.skipWhitespace();

        // Consume ')'
        try self.expectToken(.rparen);
        try self.advance();

        return PseudoClassSelector{ .kind = kind };
    }

    /// Parse nth pattern (an+b)
    fn parseNthPattern(self: *Parser) ParserError!NthPattern {
        // Handle special keywords
        const token = self.current_token orelse return error.UnexpectedEOF;
        if (token.tag == .ident) {
            if (std.mem.eql(u8, token.value, "odd")) {
                try self.advance();
                return NthPattern{ .a = 2, .b = 1 };
            }
            if (std.mem.eql(u8, token.value, "even")) {
                try self.advance();
                return NthPattern{ .a = 2, .b = 0 };
            }
        }

        // Parse an+b pattern
        // Simplified parser - handles common cases
        // Full implementation would need more complex parsing

        var a: i32 = 0;
        var b: i32 = 0;

        // Try to parse coefficient (a)
        if (token.tag == .ident) {
            // Could be "n", "2n", "-n", etc.
            const value = token.value;
            if (std.mem.endsWith(u8, value, "n")) {
                const coeff_str = value[0 .. value.len - 1];
                if (coeff_str.len == 0) {
                    a = 1;
                } else if (std.mem.eql(u8, coeff_str, "-")) {
                    a = -1;
                } else if (std.mem.eql(u8, coeff_str, "+")) {
                    a = 1;
                } else {
                    a = std.fmt.parseInt(i32, coeff_str, 10) catch return error.InvalidSelector;
                }
                try self.advance();
                self.skipWhitespace();

                // Check for +b or -b
                if (self.current_token) |next_token| {
                    if (next_token.tag == .plus) {
                        try self.advance();
                        self.skipWhitespace();
                        const b_token = self.current_token orelse return error.UnexpectedEOF;
                        b = std.fmt.parseInt(i32, b_token.value, 10) catch return error.InvalidSelector;
                        try self.advance();
                    } else if (next_token.tag == .ident and next_token.value[0] == '-') {
                        b = std.fmt.parseInt(i32, next_token.value, 10) catch return error.InvalidSelector;
                        try self.advance();
                    }
                }
            } else {
                // Just a number (b only)
                b = std.fmt.parseInt(i32, value, 10) catch return error.InvalidSelector;
                try self.advance();
            }
        } else {
            return error.InvalidSelector;
        }

        return NthPattern{ .a = a, .b = b };
    }

    /// Parse language code for :lang() pseudo-class
    fn parseLanguageCode(self: *Parser) ParserError![]const u8 {
        const token = self.current_token orelse return error.UnexpectedEOF;

        // Language code can be either an identifier or a string
        const lang_code = switch (token.tag) {
            .ident, .string => token.value,
            else => return error.InvalidSelector,
        };

        try self.advance();
        return lang_code;
    }

    /// Parse direction for :dir() pseudo-class
    fn parseDirection(self: *Parser) ParserError!Direction {
        const token = self.current_token orelse return error.UnexpectedEOF;

        // Direction must be either "ltr" or "rtl"
        if (token.tag != .ident) return error.InvalidSelector;

        const direction = if (std.mem.eql(u8, token.value, "ltr"))
            Direction.ltr
        else if (std.mem.eql(u8, token.value, "rtl"))
            Direction.rtl
        else
            return error.InvalidSelector;

        try self.advance();
        return direction;
    }

    /// Parse pseudo-element selector
    fn parsePseudoElement(self: *Parser) ParserError!SimpleSelector {
        const name_token = self.current_token orelse return error.UnexpectedEOF;
        if (name_token.tag != .ident) return error.InvalidSelector;
        const name = name_token.value;
        try self.advance();

        return SimpleSelector{ .PseudoElement = .{ .name = name } };
    }

    // ========================================================================
    // Utilities
    // ========================================================================

    /// Check if current position is start of compound selector
    fn isCompoundStart(self: *const Parser) bool {
        const token = self.current_token orelse return false;
        return switch (token.tag) {
            .ident, .dot, .hash, .lbracket, .colon, .asterisk => true,
            else => false,
        };
    }

    /// Check if current position is start of simple selector
    fn isSimpleSelectorStart(self: *const Parser) bool {
        const token = self.current_token orelse return false;
        return switch (token.tag) {
            .dot, .hash, .lbracket, .colon => true,
            else => false,
        };
    }

    /// Advance to next token
    fn advance(self: *Parser) ParserError!void {
        self.current_token = self.tokenizer.nextToken() catch |err| {
            return switch (err) {
                error.UnexpectedToken => error.UnexpectedToken,
                error.UnexpectedEOF => error.UnexpectedEOF,
            };
        };
    }

    /// Skip whitespace tokens
    fn skipWhitespace(self: *Parser) void {
        while (self.current_token) |token| {
            if (token.tag != .whitespace) break;
            self.advance() catch break;
        }
    }

    /// Expect specific token type
    fn expectToken(self: *const Parser, expected: Token.Tag) ParserError!void {
        const token = self.current_token orelse return error.UnexpectedEOF;
        if (token.tag != expected) return error.UnexpectedToken;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = @import("std").testing;

test "Parser: simple type selector (div)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "div");
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    var selector_list = try parser.parse();
    defer selector_list.deinit();

    try testing.expectEqual(@as(usize, 1), selector_list.selectors.len);
    const complex = selector_list.selectors[0];
    try testing.expectEqual(@as(usize, 1), complex.compound.simple_selectors.len);

    const simple = complex.compound.simple_selectors[0];
    try testing.expect(simple == .Type);
    try testing.expectEqualStrings("div", simple.Type.tag_name);
}

test "Parser: class selector (.container)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, ".container");
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    var selector_list = try parser.parse();
    defer selector_list.deinit();

    const simple = selector_list.selectors[0].compound.simple_selectors[0];
    try testing.expect(simple == .Class);
    try testing.expectEqualStrings("container", simple.Class.class_name);
}

test "Parser: ID selector (#main)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "#main");
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    var selector_list = try parser.parse();
    defer selector_list.deinit();

    const simple = selector_list.selectors[0].compound.simple_selectors[0];
    try testing.expect(simple == .Id);
    try testing.expectEqualStrings("main", simple.Id.id);
}

test "Parser: compound selector (div.container#main)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "div.container#main");
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    var selector_list = try parser.parse();
    defer selector_list.deinit();

    const compound = selector_list.selectors[0].compound;
    try testing.expectEqual(@as(usize, 3), compound.simple_selectors.len);
}

test "Parser: child combinator (div > p)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "div > p");
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    var selector_list = try parser.parse();
    defer selector_list.deinit();

    const complex = selector_list.selectors[0];
    try testing.expectEqual(@as(usize, 1), complex.combinators.len);
    try testing.expectEqual(Combinator.Child, complex.combinators[0].combinator);
}

test "Parser: attribute selector ([href])" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "[href]");
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    var selector_list = try parser.parse();
    defer selector_list.deinit();

    const simple = selector_list.selectors[0].compound.simple_selectors[0];
    try testing.expect(simple == .Attribute);
    try testing.expectEqualStrings("href", simple.Attribute.name);
    try testing.expect(simple.Attribute.matcher == .Presence);
}

test "Parser: pseudo-class (:first-child)" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, ":first-child");
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    var selector_list = try parser.parse();
    defer selector_list.deinit();

    const simple = selector_list.selectors[0].compound.simple_selectors[0];
    try testing.expect(simple == .PseudoClass);
    try testing.expect(simple.PseudoClass.kind == .FirstChild);
}

test "Parser: :lang(en) pseudo-class" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, ":lang(en)");
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    var selector_list = try parser.parse();
    defer selector_list.deinit();

    const simple = selector_list.selectors[0].compound.simple_selectors[0];
    try testing.expect(simple == .PseudoClass);
    try testing.expect(simple.PseudoClass.kind == .Lang);
    try testing.expectEqualStrings("en", simple.PseudoClass.kind.Lang);
}
