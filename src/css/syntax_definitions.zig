//! CSS Properties and Values API §5: owned syntax definitions.
//! One component grammar serves syntax strings and Values 5 token streams.
//! Strings reject comments and escaped data type names; token syntax permits
//! comments between tokens and decodes identifiers. Both preserve whitespace
//! and require multipliers to be adjacent. Design: Blink CSSSyntaxDefinition
//! and CSSSyntaxStringParser (ordered components, separate lexical fronts).
const std = @import("std");
const tokens = @import("tokenizer.zig");
const values = @import("style_values.zig");
const Allocator = std.mem.Allocator;

/// Public owned result and computation input for syntax-definition consumers.
pub const Value = @import("syntax_values.zig").Value;
pub const ComputeContext = @import("syntax_values.zig").ComputeContext;

/// The supported data type names, CSS Properties and Values API §5.1.
pub const DataType = enum {
    length,
    number,
    percentage,
    length_percentage,
    string,
    color,
    image,
    url,
    integer,
    angle,
    time,
    resolution,
    transform_function,
    custom_ident,
    transform_list,

    fn fromName(name: []const u8) ?DataType {
        const names = .{
            .{ "length", .length },
            .{ "number", .number },
            .{ "percentage", .percentage },
            .{ "length-percentage", .length_percentage },
            .{ "string", .string },
            .{ "color", .color },
            .{ "image", .image },
            .{ "url", .url },
            .{ "integer", .integer },
            .{ "angle", .angle },
            .{ "time", .time },
            .{ "resolution", .resolution },
            .{ "transform-function", .transform_function },
            .{ "custom-ident", .custom_ident },
            .{ "transform-list", .transform_list },
        };
        inline for (names) |entry| {
            if (std.mem.eql(u8, name, entry[0])) return entry[1];
        }
        return null;
    }
};

/// A component's repetition grammar; transform-list is already repeated.
pub const Multiplier = enum { single, space_list, comma_list };

/// One ordered alternative. An identifier owns decoded UTF-8 bytes.
pub const Component = struct {
    name: union(enum) { data_type: DataType, ident: []const u8 },
    multiplier: Multiplier = .single,

    fn deinit(self: Component, allocator: Allocator) void {
        if (self.name == .ident) allocator.free(self.name.ident);
    }
};

/// The universal definition, or a non-empty ordered set of alternatives.
/// Owns all storage independently of the syntax string supplied to parse().
pub const Definition = struct {
    allocator: Allocator,
    universal: bool,
    components: []Component,

    /// Match substituted component values against the ordered syntax.
    pub fn parseValue(self: *const Definition, options: @import("properties.zig").ParseOptions, text: []const u8) Allocator.Error!?@import("syntax_values.zig").Value {
        return @import("syntax_values.zig").parse(self, options, text);
    }

    /// Release every identifier and the component array, exactly once.
    pub fn deinit(self: *Definition) void {
        for (self.components) |component| component.deinit(self.allocator);
        self.allocator.free(self.components);
        self.* = undefined;
    }
};

/// Consume a syntax string, Properties and Values §5.4.2. Comments are not
/// whitespace here, and data type names use their exact, unescaped spelling.
pub fn parse(allocator: Allocator, text: []const u8) ParseError!Definition {
    var input: Input = .{ .stream = tokens.Tokenizer.init(text), .front = .string };
    return parseInput(allocator, &input);
}

/// Consume bounded type() contents, Values 5 §3.3.1. Whitespace stays visible,
/// comments separate tokens, and data type names are decoded identifiers.
/// On invalid syntax or OOM, leave the caller's tokenizer unchanged.
pub fn parseTokens(allocator: Allocator, stream: *tokens.Tokenizer) ParseError!Definition {
    var input: Input = .{ .stream = stream.*, .front = .token };
    const definition = try parseInput(allocator, &input);
    stream.* = input.stream;
    return definition;
}

const ParseError = Allocator.Error || error{InvalidSyntax};

/// Two lexical fronts feed one component/multiplier/alternative grammar.
/// In the string front a comment is invalid before the tokenizer can skip it.
const Input = struct {
    stream: tokens.Tokenizer,
    front: enum { string, token },

    fn next(self: *Input) error{InvalidSyntax}!tokens.Token {
        if (self.front == .string and std.mem.startsWith(u8, self.stream.input[self.stream.pos..], "/*"))
            return error.InvalidSyntax;
        return self.stream.next();
    }

    fn peek(self: *Input) error{InvalidSyntax}!tokens.Token {
        var copy = self.*;
        return copy.next();
    }

    fn skipWhitespace(self: *Input) error{InvalidSyntax}!void {
        while ((try self.peek()).token_type == .whitespace) _ = try self.next();
    }

    fn dataType(self: *Input, allocator: Allocator, token: tokens.Token) ParseError!DataType {
        if (token.token_type != .ident) return error.InvalidSyntax;
        if (self.front == .string) return DataType.fromName(token.value) orelse error.InvalidSyntax;
        const decoded = try tokens.decode(allocator, token.value);
        defer allocator.free(decoded);
        return DataType.fromName(decoded) orelse error.InvalidSyntax;
    }
};

fn isDelimiter(token: tokens.Token, spelling: []const u8) bool {
    return token.token_type == .delim and std.mem.eql(u8, token.value, spelling);
}

fn parseInput(allocator: Allocator, input: *Input) ParseError!Definition {
    // §5.4.2 steps 1–3: ASCII whitespace; the universal form stands alone.
    try input.skipWhitespace();
    if (isDelimiter(try input.peek(), "*")) {
        _ = try input.next();
        try input.skipWhitespace();
        if ((try input.next()).token_type != .eof) return error.InvalidSyntax;
        return .{ .allocator = allocator, .universal = true, .components = &.{} };
    }
    // Step 4: every separator token has a literal pipe in the remaining
    // source. Escaped pipes and comments can only overestimate this bound.
    const source = input.stream.input[input.stream.pos..];
    const capacity = std.mem.count(u8, source, "|") + 1;
    var components = try allocator.alloc(Component, capacity);
    var count: usize = 0;
    errdefer {
        for (components[0..count]) |component| component.deinit(allocator);
        allocator.free(components);
    }
    while (true) {
        // Step 5: a complete component, whitespace, then EOF or '|'.
        components[count] = try consumeComponent(allocator, input);
        count += 1;
        try input.skipWhitespace();
        const separator = try input.next();
        if (separator.token_type == .eof) break;
        if (!isDelimiter(separator, "|")) return error.InvalidSyntax;
        try input.skipWhitespace();
    }
    components = try allocator.realloc(components, count);
    return .{ .allocator = allocator, .universal = false, .components = components };
}

fn consumeComponent(allocator: Allocator, input: *Input) ParseError!Component {
    // §5.4.3: a data type name or an ident, then one adjacent multiplier.
    const first = try input.next();
    var component: Component = undefined;
    if (isDelimiter(first, "<")) {
        // §5.4.4; Values 5 §3.3.1: whitespace is forbidden inside <...>.
        // The token front alone accepts escapes and intervening comments.
        const data_type = try input.dataType(allocator, try input.next());
        if (!isDelimiter(try input.next(), ">")) return error.InvalidSyntax;
        component = .{ .name = .{ .data_type = data_type } };
    } else {
        if (first.token_type != .ident) return error.InvalidSyntax;
        const name = try tokens.decode(allocator, first.value);
        if (!isCustomIdent(name)) {
            allocator.free(name);
            return error.InvalidSyntax;
        }
        component = .{ .name = .{ .ident = name } };
    }
    errdefer component.deinit(allocator);
    const multiplier = try input.peek();
    if (isDelimiter(multiplier, "+") or isDelimiter(multiplier, "#")) {
        // A transform-list already repeats; a second multiplier is invalid.
        if (component.name == .data_type and component.name.data_type == .transform_list) return error.InvalidSyntax;
        _ = try input.next();
        component.multiplier = if (isDelimiter(multiplier, "+")) .space_list else .comma_list;
    }
    return component;
}

/// CSS Values <custom-ident>, on an already decoded identifier token.
pub fn isCustomIdent(name: []const u8) bool {
    return values.CssWide.parse(name) == null and !std.ascii.eqlIgnoreCase(name, "default");
}
