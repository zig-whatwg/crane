const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;

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

/// CSS Specificity (a, b, c) tuple per Selectors Level 4
/// a = ID selectors count
/// b = class selectors + attribute selectors + pseudo-classes count
/// c = type selectors + pseudo-elements count
pub const Specificity = struct {
    id: u32 = 0, // a
    class: u32 = 0, // b
    element: u32 = 0, // c

    /// Compare two specificities
    /// Returns: .lt (less), .eq (equal), .gt (greater)
    pub fn compare(self: Specificity, other: Specificity) std.math.Order {
        if (self.id != other.id) return std.math.order(self.id, other.id);
        if (self.class != other.class) return std.math.order(self.class, other.class);
        return std.math.order(self.element, other.element);
    }

    /// Add two specificities together
    pub fn add(self: Specificity, other: Specificity) Specificity {
        return Specificity{
            .id = self.id + other.id,
            .class = self.class + other.class,
            .element = self.element + other.element,
        };
    }

    /// Return maximum of two specificities
    pub fn max(self: Specificity, other: Specificity) Specificity {
        return if (self.compare(other) == .gt) self else other;
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

    /// Calculate specificity of this complex selector
    pub fn calculateSpecificity(self: *const ComplexSelector) Specificity {
        var spec = self.compound.calculateSpecificity();

        // Add specificity from all combinators
        for (self.combinators) |*pair| {
            spec = spec.add(pair.compound.calculateSpecificity());
        }

        return spec;
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

    /// Calculate specificity of this compound selector
    pub fn calculateSpecificity(self: *const CompoundSelector) Specificity {
        var spec = Specificity{};

        for (self.simple_selectors) |*selector| {
            spec = spec.add(selector.calculateSpecificity());
        }

        return spec;
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

    /// Calculate specificity contribution of this simple selector
    pub fn calculateSpecificity(self: *const SimpleSelector) Specificity {
        return switch (self.*) {
            .Universal => Specificity{}, // 0,0,0
            .Type => Specificity{ .element = 1 }, // 0,0,1
            .Class => Specificity{ .class = 1 }, // 0,1,0
            .Id => Specificity{ .id = 1 }, // 1,0,0
            .Attribute => Specificity{ .class = 1 }, // 0,1,0
            .PseudoClass => |*pseudo| pseudo.calculateSpecificity(), // varies
            .PseudoElement => Specificity{ .element = 1 }, // 0,0,1
        };
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

    /// Calculate specificity contribution of this pseudo-class
    pub fn calculateSpecificity(self: *const PseudoClassSelector) Specificity {
        return switch (self.kind) {
            // :where() always has 0 specificity
            .Where => Specificity{},

            // :is(), :not(), :has() take the max specificity of their arguments
            .Is, .Not, .Has => |selector_list_ptr| blk: {
                var max_spec = Specificity{};
                for (selector_list_ptr.selectors) |*selector| {
                    const spec = selector.calculateSpecificity();
                    max_spec = max_spec.max(spec);
                }
                break :blk max_spec;
            },

            // All other pseudo-classes count as class selectors (0,1,0)
            else => Specificity{ .class = 1 },
        };
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

    // Scoping
    Scope,
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
    pub fn parseSelectorList(self: *Parser) ParserError!SelectorList {
        var selectors = infra.List(ComplexSelector).init(self.allocator);
        errdefer {
            for (selectors.toSliceMut()) |*selector| {
                selector.deinit();
            }
            selectors.deinit();
        }

        // Parse first complex selector
        try selectors.append(try self.parseComplexSelector());

        // Parse additional selectors (comma-separated)
        while (self.current_token) |token| {
            if (token.tag == .comma) {
                try self.advance();
                self.skipWhitespace();
                try selectors.append(try self.parseComplexSelector());
            } else {
                break;
            }
        }

        return SelectorList{
            .selectors = try selectors.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    /// Parse selector list with forgiving error handling
    /// Invalid selectors are silently dropped instead of failing entire list
    /// Used by :is(), :where(), :has() per Selectors Level 4 spec
    fn parseForgivingSelectorList(self: *Parser) ParserError!SelectorList {
        var selectors = infra.List(ComplexSelector).init(self.allocator);
        errdefer {
            for (0..selectors.len) |i| {
                selectors.toSliceMut()[i].deinit();
            }
            selectors.deinit();
        }

        // Parse first complex selector (with error recovery)
        if (self.parseComplexSelector()) |selector| {
            try selectors.append(selector);
        } else |_| {
            // First selector failed - skip to next comma or end
            self.skipToCommaOrEnd();
        }

        // Parse additional selectors (comma-separated)
        while (self.current_token) |token| {
            if (token.tag == .comma) {
                try self.advance();
                self.skipWhitespace();

                // Try to parse next selector, skip if invalid
                if (self.parseComplexSelector()) |selector| {
                    try selectors.append(selector);
                } else |_| {
                    // Invalid selector - skip to next comma or end
                    self.skipToCommaOrEnd();
                }
            } else {
                break;
            }
        }

        // If all selectors were invalid, return empty list (matches nothing)
        return SelectorList{
            .selectors = try selectors.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    /// Skip tokens until comma or end (for error recovery)
    fn skipToCommaOrEnd(self: *Parser) void {
        while (self.current_token) |token| {
            if (token.tag == .comma or token.tag == .rparen) {
                break;
            }
            self.advance() catch break;
        }
    }

    /// Parse complex selector (combinator chain)
    fn parseComplexSelector(self: *Parser) ParserError!ComplexSelector {
        var combinators = infra.List(CombinatorPair).init(self.allocator);
        errdefer {
            for (0..combinators.len) |i| {
                combinators.toSliceMut()[i].compound.deinit();
            }
            combinators.deinit();
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

            try combinators.append(CombinatorPair{
                .combinator = combinator.?,
                .compound = next_compound,
            });
        }

        return ComplexSelector{
            .compound = first_compound,
            .combinators = try combinators.toOwnedSlice(),
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
        var simple_selectors = infra.List(SimpleSelector).init(self.allocator);
        errdefer {
            for (0..simple_selectors.len) |i| {
                simple_selectors.toSliceMut()[i].deinit(self.allocator);
            }
            simple_selectors.deinit();
        }

        // Parse first simple selector
        try simple_selectors.append(try self.parseSimpleSelector());

        // Parse additional simple selectors (no whitespace between)
        while (self.isSimpleSelectorStart()) {
            try simple_selectors.append(try self.parseSimpleSelector());
        }

        if (simple_selectors.len == 0) {
            return error.InvalidSelector;
        }

        return CompoundSelector{
            .simple_selectors = try simple_selectors.toOwnedSlice(),
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

        // Check for case-sensitivity flag ('i' or 's') before ']'
        var case_sensitive = true;

        // Skip whitespace before checking for flag
        self.skipWhitespace();

        // Check if current token is a case-sensitivity flag
        if (self.current_token) |flag_token| {
            if (flag_token.tag == .ident) {
                const flag = flag_token.value;
                if (std.mem.eql(u8, flag, "i") or std.mem.eql(u8, flag, "s")) {
                    if (std.mem.eql(u8, flag, "i")) {
                        case_sensitive = false;
                    }
                    // Consume the flag
                    try self.advance();
                    // Skip any whitespace after the flag
                    self.skipWhitespace();
                }
            }
        }

        // Consume ']'
        try self.expectToken(.rbracket);
        try self.advance();

        return AttributeSelector{
            .name = name,
            .matcher = matcher,
            .case_sensitive = case_sensitive,
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
        if (std.mem.eql(u8, name, "scope")) return .Scope;
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
            selector_list.* = try self.parseForgivingSelectorList();
            kind = PseudoClassKind{ .Is = selector_list };
        } else if (std.mem.eql(u8, name, "where")) {
            const selector_list = try self.allocator.create(SelectorList);
            selector_list.* = try self.parseForgivingSelectorList();
            kind = PseudoClassKind{ .Where = selector_list };
        } else if (std.mem.eql(u8, name, "has")) {
            const selector_list = try self.allocator.create(SelectorList);
            selector_list.* = try self.parseForgivingSelectorList();
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









// ============================================================================
// Specificity Tests
// ============================================================================












