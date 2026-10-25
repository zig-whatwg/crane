//! CSS Properties and Values API §5: owned syntax definitions.
//! This grammar consumes code points, so comments are not whitespace and
//! multipliers must immediately follow their component. Identifier decoding
//! uses the existing CSS Syntax tokenizer; data type names are not escaped.
//! Design reference: Blink CSSSyntaxStringParser (ordered components).
const std = @import("std");
const tokens = @import("tokenizer.zig");
const values = @import("style_values.zig");
const Allocator = std.mem.Allocator;

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

/// Consume a syntax definition, §5.4.2. OOM is distinct from invalid syntax.
pub fn parse(allocator: Allocator, text: []const u8) (Allocator.Error || error{InvalidSyntax})!Definition {
    // Steps 1–3: Infra ASCII whitespace; the universal form stands alone.
    const input = std.mem.trim(u8, text, " \t\n\r\x0c");
    if (input.len == 0) return error.InvalidSyntax;
    if (std.mem.eql(u8, input, "*")) return .{ .allocator = allocator, .universal = true, .components = &.{} };

    // Step 4: at most one component per literal separator plus one.
    // Escaped pipes can overestimate this bound, never underestimate it.
    // CSS is a standalone module: no additional module dependency is needed.
    const capacity = std.mem.count(u8, input, "|") + 1;
    var components = try allocator.alloc(Component, capacity);
    var count: usize = 0;
    errdefer {
        for (components[0..count]) |component| component.deinit(allocator);
        allocator.free(components);
    }
    var position: usize = 0;
    while (true) {
        // Step 5: consume a component, whitespace, then EOF or '|'.
        skipWhitespace(input, &position);
        components[count] = try consumeComponent(allocator, input, &position);
        count += 1;
        skipWhitespace(input, &position);
        if (position == input.len) break;
        if (input[position] != '|') return error.InvalidSyntax;
        position += 1;
    }
    components = try allocator.realloc(components, count);
    return .{ .allocator = allocator, .universal = false, .components = components };
}

fn consumeComponent(allocator: Allocator, input: []const u8, position: *usize) (Allocator.Error || error{InvalidSyntax})!Component {
    // §5.4.3: a data type name or an ident sequence, then at most one multiplier.
    if (position.* == input.len) return error.InvalidSyntax;
    var component: Component = undefined;
    if (input[position.*] == '<') {
        // §5.4.4: only the exact supported spelling can succeed. This also
        // rejects whitespace, escapes, punctuation and unknown names.
        const start = position.* + 1;
        const end = std.mem.indexOfScalarPos(u8, input, start, '>') orelse return error.InvalidSyntax;
        const data_type = DataType.fromName(input[start..end]) orelse return error.InvalidSyntax;
        component = .{ .name = .{ .data_type = data_type } };
        position.* = end + 1;
    } else {
        var tokenizer = tokens.Tokenizer.init(input[position.*..]);
        const token = tokenizer.next();
        // Consume an ident, not a token stream: a comment at the beginning
        // must not be skipped by Tokenizer.next(). The spelling must begin
        // at this exact position. CSS Syntax handles '--' and escaped starts.
        if (token.token_type != .ident or token.value.ptr != input[position.*..].ptr) return error.InvalidSyntax;
        const name = try tokens.decode(allocator, token.value);
        if (!isCustomIdent(name)) {
            allocator.free(name);
            return error.InvalidSyntax;
        }
        component = .{ .name = .{ .ident = name } };
        position.* += tokenizer.pos;
    }
    if (component.name == .data_type and component.name.data_type == .transform_list) return component;
    if (position.* < input.len) switch (input[position.*]) {
        '+' => {
            component.multiplier = .space_list;
            position.* += 1;
        },
        '#' => {
            component.multiplier = .comma_list;
            position.* += 1;
        },
        else => {},
    };
    return component;
}

/// CSS Values <custom-ident>, on an already decoded identifier token.
pub fn isCustomIdent(name: []const u8) bool {
    return values.CssWide.parse(name) == null and !std.ascii.eqlIgnoreCase(name, "default");
}

fn skipWhitespace(input: []const u8, position: *usize) void {
    while (position.* < input.len and std.mem.indexOfScalar(u8, " \t\n\r\x0c", input[position.*]) != null) position.* += 1;
}
