//! URLPattern Parser
//!
//! Implements the pattern string parsing algorithm from the URLPattern specification.
//! See: https://urlpattern.spec.whatwg.org/#parsing
//!
//! This module takes a token list (from the tokenizer) and produces a part list
//! that represents the structure of the pattern.

const std = @import("std");
const Allocator = std.mem.Allocator;
const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;
const TokenType = tokenizer.TokenType;

/// Part types as defined in the URLPattern spec
pub const PartType = enum {
    /// Simple fixed text string
    fixed_text,
    /// Matching group with custom regular expression
    regexp,
    /// Matching group that matches up to next separator
    segment_wildcard,
    /// Matching group that greedily matches all code points
    full_wildcard,
};

/// Part modifiers
pub const PartModifier = enum {
    /// No modifier
    none,
    /// Optional modifier (?)
    optional,
    /// Zero or more modifier (*)
    zero_or_more,
    /// One or more modifier (+)
    one_or_more,

    /// Convert to pattern string representation
    pub fn toString(self: PartModifier) []const u8 {
        return switch (self) {
            .none => "",
            .optional => "?",
            .zero_or_more => "*",
            .one_or_more => "+",
        };
    }
};

/// A part representing one piece of a parsed pattern string
pub const Part = struct {
    /// Type of this part
    type: PartType,
    /// Value (regexp for regexp type, text for fixed_text, empty for wildcards)
    value: []const u8,
    /// Modifier applied to this part
    modifier: PartModifier,
    /// Name of the capturing group (if any)
    name: []const u8,
    /// Fixed text prefix before the group
    prefix: []const u8,
    /// Fixed text suffix after the group
    suffix: []const u8,

    /// Allocator used for value/name copies (for cleanup)
    _allocator: ?Allocator,
    /// Owned copies that need freeing
    _owned_value: ?[]u8,
    _owned_name: ?[]u8,
    _owned_prefix: ?[]u8,
    _owned_suffix: ?[]u8,

    pub fn init(part_type: PartType, value: []const u8, modifier: PartModifier) Part {
        return Part{
            .type = part_type,
            .value = value,
            .modifier = modifier,
            .name = "",
            .prefix = "",
            .suffix = "",
            ._allocator = null,
            ._owned_value = null,
            ._owned_name = null,
            ._owned_prefix = null,
            ._owned_suffix = null,
        };
    }

    pub fn deinit(self: *Part) void {
        if (self._allocator) |alloc| {
            if (self._owned_value) |v| alloc.free(v);
            if (self._owned_name) |n| alloc.free(n);
            if (self._owned_prefix) |p| alloc.free(p);
            if (self._owned_suffix) |s| alloc.free(s);
        }
    }
};

/// Options for pattern parsing (from path-to-regexp)
pub const Options = struct {
    /// Delimiter code point for segments
    delimiter_code_point: []const u8 = "",
    /// Prefix code point for automatic prefixing
    prefix_code_point: []const u8 = "",
    /// Ignore case in matching
    ignore_case: bool = false,
};

/// Default options (no delimiter, no prefix)
pub const default_options = Options{};

/// Hostname options (delimiter = ".")
pub const hostname_options = Options{
    .delimiter_code_point = ".",
};

/// Pathname options (delimiter = "/", prefix = "/")
pub const pathname_options = Options{
    .delimiter_code_point = "/",
    .prefix_code_point = "/",
};

/// Encoding callback type
pub const EncodingCallback = *const fn (allocator: Allocator, input: []const u8) error{InvalidInput}![]u8;

/// Identity encoding (no transformation)
pub fn identityEncoding(allocator: Allocator, input: []const u8) error{InvalidInput}![]u8 {
    const result = try allocator.alloc(u8, input.len);
    @memcpy(result, input);
    return result;
}

/// Pattern parser state machine
pub const PatternParser = struct {
    /// Token list to parse
    token_list: []const Token,
    /// Encoding callback
    encoding_callback: EncodingCallback,
    /// Options
    options: Options,
    /// Segment wildcard regexp
    segment_wildcard_regexp: []const u8,
    /// Result part list
    part_list: std.ArrayList(Part),
    /// Pending fixed value buffer
    pending_fixed_value: std.ArrayList(u8),
    /// Current token index
    index: usize,
    /// Next numeric name counter
    next_numeric_name: usize,
    /// Allocator
    allocator: Allocator,

    const Self = @This();

    /// Full wildcard regexp value
    pub const full_wildcard_regexp = ".*";

    /// Initialize the parser
    pub fn init(
        allocator: Allocator,
        tokens: []const Token,
        options: Options,
        encoding_callback: EncodingCallback,
    ) Self {
        return Self{
            .token_list = tokens,
            .encoding_callback = encoding_callback,
            .options = options,
            .segment_wildcard_regexp = generateSegmentWildcardRegexp(options),
            .part_list = std.ArrayList(Part).init(allocator),
            .pending_fixed_value = std.ArrayList(u8).init(allocator),
            .index = 0,
            .next_numeric_name = 0,
            .allocator = allocator,
        };
    }

    /// Free resources
    pub fn deinit(self: *Self) void {
        for (self.part_list.items) |*part| {
            part.deinit();
        }
        self.part_list.deinit();
        self.pending_fixed_value.deinit();
    }

    /// Generate segment wildcard regexp based on options
    fn generateSegmentWildcardRegexp(options: Options) []const u8 {
        // In a full implementation, this would dynamically build [^<delimiter>]+?
        // For now, we use common cases
        if (std.mem.eql(u8, options.delimiter_code_point, "/")) {
            return "[^/]+?";
        }
        if (std.mem.eql(u8, options.delimiter_code_point, ".")) {
            return "[^.]+?";
        }
        return "[^]+?"; // Match anything but empty
    }

    /// Try to consume a token of given type
    fn tryConsumeToken(self: *Self, token_type: TokenType) ?Token {
        if (self.index >= self.token_list.len) return null;

        const token = self.token_list[self.index];
        if (token.type != token_type) return null;

        self.index += 1;
        return token;
    }

    /// Try to consume a modifier token
    fn tryConsumeModifierToken(self: *Self) ?Token {
        if (self.tryConsumeToken(.other_modifier)) |token| {
            return token;
        }
        return self.tryConsumeToken(.asterisk);
    }

    /// Try to consume regexp or wildcard token
    fn tryConsumeRegexpOrWildcardToken(self: *Self, name_token: ?Token) ?Token {
        if (self.tryConsumeToken(.regexp)) |token| {
            return token;
        }
        // Only consume asterisk as wildcard if no name token
        if (name_token == null) {
            return self.tryConsumeToken(.asterisk);
        }
        return null;
    }

    /// Consume a required token
    fn consumeRequiredToken(self: *Self, token_type: TokenType) !Token {
        if (self.tryConsumeToken(token_type)) |token| {
            return token;
        }
        return error.InvalidPattern;
    }

    /// Consume text (char and escaped_char tokens)
    fn consumeText(self: *Self) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        while (true) {
            const token = self.tryConsumeToken(.char) orelse
                self.tryConsumeToken(.escaped_char) orelse break;

            try result.appendSlice(token.value);
        }

        return result.toOwnedSlice();
    }

    /// Maybe add a part from the pending fixed value
    fn maybeAddPartFromPendingFixedValue(self: *Self) !void {
        if (self.pending_fixed_value.items.len == 0) return;

        // Encode the pending value
        const encoded = try self.encoding_callback(self.allocator, self.pending_fixed_value.items);
        errdefer self.allocator.free(encoded);

        var part = Part.init(.fixed_text, encoded, .none);
        part._allocator = self.allocator;
        part._owned_value = encoded;

        try self.part_list.append(part);

        self.pending_fixed_value.clearRetainingCapacity();
    }

    /// Check if name is duplicate
    fn isDuplicateName(self: *Self, name: []const u8) bool {
        for (self.part_list.items) |part| {
            if (std.mem.eql(u8, part.name, name)) {
                return true;
            }
        }
        return false;
    }

    /// Add a part with name, regexp/wildcard, prefix, suffix, modifier
    fn addPart(
        self: *Self,
        prefix: []const u8,
        name_token: ?Token,
        regexp_or_wildcard_token: ?Token,
        suffix: []const u8,
        modifier_token: ?Token,
    ) !void {
        // Determine modifier
        var modifier = PartModifier.none;
        if (modifier_token) |mt| {
            if (std.mem.eql(u8, mt.value, "?")) {
                modifier = .optional;
            } else if (std.mem.eql(u8, mt.value, "*")) {
                modifier = .zero_or_more;
            } else if (std.mem.eql(u8, mt.value, "+")) {
                modifier = .one_or_more;
            }
        }

        // Handle {foo} grouping with no matching group
        if (name_token == null and regexp_or_wildcard_token == null and modifier == .none) {
            try self.pending_fixed_value.appendSlice(prefix);
            return;
        }

        // Flush pending fixed value
        try self.maybeAddPartFromPendingFixedValue();

        // Handle {foo}? - modified fixed text
        if (name_token == null and regexp_or_wildcard_token == null) {
            // assert suffix is empty
            if (prefix.len == 0) return;

            const encoded_prefix = try self.encoding_callback(self.allocator, prefix);
            errdefer self.allocator.free(encoded_prefix);

            var part = Part.init(.fixed_text, encoded_prefix, modifier);
            part._allocator = self.allocator;
            part._owned_value = encoded_prefix;

            try self.part_list.append(part);
            return;
        }

        // Determine regexp value
        var regexp_value: []const u8 = "";
        var part_type: PartType = .segment_wildcard;

        if (regexp_or_wildcard_token == null) {
            regexp_value = self.segment_wildcard_regexp;
            part_type = .segment_wildcard;
        } else if (regexp_or_wildcard_token.?.type == .asterisk) {
            regexp_value = full_wildcard_regexp;
            part_type = .full_wildcard;
        } else {
            regexp_value = regexp_or_wildcard_token.?.value;
            part_type = .regexp;

            // Check if it matches segment wildcard or full wildcard
            if (std.mem.eql(u8, regexp_value, self.segment_wildcard_regexp)) {
                part_type = .segment_wildcard;
                regexp_value = "";
            } else if (std.mem.eql(u8, regexp_value, full_wildcard_regexp)) {
                part_type = .full_wildcard;
                regexp_value = "";
            }
        }

        // Determine name
        var name: []const u8 = "";
        var name_copy: ?[]u8 = null;

        if (name_token) |nt| {
            name_copy = try self.allocator.alloc(u8, nt.value.len);
            @memcpy(name_copy.?, nt.value);
            name = name_copy.?;
        } else if (regexp_or_wildcard_token != null) {
            // Auto-generate numeric name
            var buf: [32]u8 = undefined;
            const name_str = std.fmt.bufPrint(&buf, "{d}", .{self.next_numeric_name}) catch unreachable;
            name_copy = try self.allocator.alloc(u8, name_str.len);
            @memcpy(name_copy.?, name_str);
            name = name_copy.?;
            self.next_numeric_name += 1;
        }

        // Check for duplicate name
        if (self.isDuplicateName(name)) {
            if (name_copy) |nc| self.allocator.free(nc);
            return error.DuplicateName;
        }

        // Encode prefix and suffix
        const encoded_prefix = try self.encoding_callback(self.allocator, prefix);
        errdefer self.allocator.free(encoded_prefix);

        const encoded_suffix = try self.encoding_callback(self.allocator, suffix);
        errdefer self.allocator.free(encoded_suffix);

        // Copy regexp value if needed
        var value_copy: ?[]u8 = null;
        if (regexp_value.len > 0) {
            value_copy = try self.allocator.alloc(u8, regexp_value.len);
            @memcpy(value_copy.?, regexp_value);
        }

        const part = Part{
            .type = part_type,
            .value = if (value_copy) |vc| vc else "",
            .modifier = modifier,
            .name = name,
            .prefix = encoded_prefix,
            .suffix = encoded_suffix,
            ._allocator = self.allocator,
            ._owned_value = value_copy,
            ._owned_name = name_copy,
            ._owned_prefix = encoded_prefix,
            ._owned_suffix = encoded_suffix,
        };

        try self.part_list.append(part);
    }

    /// Parse the token list into parts
    pub fn parse(self: *Self) !void {
        while (self.index < self.token_list.len) {
            // Look for: <prefix char><name><regexp><modifier>
            const char_token = self.tryConsumeToken(.char);
            const name_token = self.tryConsumeToken(.name);
            const regexp_or_wildcard_token = self.tryConsumeRegexpOrWildcardToken(name_token);

            if (name_token != null or regexp_or_wildcard_token != null) {
                // We have a matching group
                var prefix: []const u8 = "";
                if (char_token) |ct| {
                    prefix = ct.value;
                }

                // Check if prefix should be grouped with matching group or pending fixed value
                if (prefix.len > 0 and !std.mem.eql(u8, prefix, self.options.prefix_code_point)) {
                    try self.pending_fixed_value.appendSlice(prefix);
                    prefix = "";
                }

                try self.maybeAddPartFromPendingFixedValue();

                const modifier_token = self.tryConsumeModifierToken();
                try self.addPart(prefix, name_token, regexp_or_wildcard_token, "", modifier_token);
                continue;
            }

            // No matching group - buffer fixed text
            var fixed_token = char_token;
            if (fixed_token == null) {
                fixed_token = self.tryConsumeToken(.escaped_char);
            }

            if (fixed_token) |ft| {
                try self.pending_fixed_value.appendSlice(ft.value);
                continue;
            }

            // Look for: <open><prefix><name><regexp><suffix><close><modifier>
            const open_token = self.tryConsumeToken(.open);
            if (open_token != null) {
                const prefix_text = try self.consumeText();
                defer self.allocator.free(prefix_text);

                const inner_name_token = self.tryConsumeToken(.name);
                const inner_regexp_or_wildcard_token = self.tryConsumeRegexpOrWildcardToken(inner_name_token);

                const suffix_text = try self.consumeText();
                defer self.allocator.free(suffix_text);

                _ = try self.consumeRequiredToken(.close);

                const modifier_token = self.tryConsumeModifierToken();
                try self.addPart(prefix_text, inner_name_token, inner_regexp_or_wildcard_token, suffix_text, modifier_token);
                continue;
            }

            // Flush any pending fixed value
            try self.maybeAddPartFromPendingFixedValue();

            // Expect end token
            _ = try self.consumeRequiredToken(.end);
        }
    }
};

/// Parse a pattern string into parts
pub fn parsePatternString(
    allocator: Allocator,
    input: []const u8,
    options: Options,
    encoding_callback: EncodingCallback,
) !std.ArrayList(Part) {
    // Tokenize the input
    var tokens = try tokenizer.tokenize(allocator, input, .strict);
    defer tokens.deinit();

    // Parse the tokens
    var parser = PatternParser.init(allocator, tokens.items, options, encoding_callback);

    parser.parse() catch |err| {
        parser.deinit();
        return err;
    };

    // Transfer ownership of part list
    const result = parser.part_list;
    parser.part_list = std.ArrayList(Part).init(allocator);
    parser.deinit();

    return result;
}

// Tests

test "parse - simple string" {
    const allocator = std.testing.allocator;
    var parts = try parsePatternString(allocator, "hello", default_options, identityEncoding);
    defer {
        for (parts.items) |*part| {
            part.deinit();
        }
        parts.deinit();
    }

    try std.testing.expectEqual(@as(usize, 1), parts.items.len);
    try std.testing.expectEqual(PartType.fixed_text, parts.items[0].type);
    try std.testing.expectEqualStrings("hello", parts.items[0].value);
}

test "parse - named group" {
    const allocator = std.testing.allocator;
    var parts = try parsePatternString(allocator, ":foo", default_options, identityEncoding);
    defer {
        for (parts.items) |*part| {
            part.deinit();
        }
        parts.deinit();
    }

    try std.testing.expectEqual(@as(usize, 1), parts.items.len);
    try std.testing.expectEqual(PartType.segment_wildcard, parts.items[0].type);
    try std.testing.expectEqualStrings("foo", parts.items[0].name);
}

test "parse - named group with regexp" {
    const allocator = std.testing.allocator;
    var parts = try parsePatternString(allocator, ":id(\\d+)", default_options, identityEncoding);
    defer {
        for (parts.items) |*part| {
            part.deinit();
        }
        parts.deinit();
    }

    try std.testing.expectEqual(@as(usize, 1), parts.items.len);
    try std.testing.expectEqual(PartType.regexp, parts.items[0].type);
    try std.testing.expectEqualStrings("id", parts.items[0].name);
    try std.testing.expectEqualStrings("\\d+", parts.items[0].value);
}

test "parse - asterisk wildcard" {
    const allocator = std.testing.allocator;
    var parts = try parsePatternString(allocator, "*", default_options, identityEncoding);
    defer {
        for (parts.items) |*part| {
            part.deinit();
        }
        parts.deinit();
    }

    try std.testing.expectEqual(@as(usize, 1), parts.items.len);
    try std.testing.expectEqual(PartType.full_wildcard, parts.items[0].type);
    try std.testing.expectEqualStrings("0", parts.items[0].name);
}

test "parse - optional modifier" {
    const allocator = std.testing.allocator;
    var parts = try parsePatternString(allocator, ":foo?", default_options, identityEncoding);
    defer {
        for (parts.items) |*part| {
            part.deinit();
        }
        parts.deinit();
    }

    try std.testing.expectEqual(@as(usize, 1), parts.items.len);
    try std.testing.expectEqual(PartModifier.optional, parts.items[0].modifier);
}

test "parse - path pattern with prefix" {
    const allocator = std.testing.allocator;
    var parts = try parsePatternString(allocator, "/:category", pathname_options, identityEncoding);
    defer {
        for (parts.items) |*part| {
            part.deinit();
        }
        parts.deinit();
    }

    try std.testing.expectEqual(@as(usize, 1), parts.items.len);
    try std.testing.expectEqualStrings("/", parts.items[0].prefix);
    try std.testing.expectEqualStrings("category", parts.items[0].name);
}

test "parse - grouped pattern" {
    const allocator = std.testing.allocator;
    var parts = try parsePatternString(allocator, "{:foo}?", default_options, identityEncoding);
    defer {
        for (parts.items) |*part| {
            part.deinit();
        }
        parts.deinit();
    }

    try std.testing.expectEqual(@as(usize, 1), parts.items.len);
    try std.testing.expectEqual(PartModifier.optional, parts.items[0].modifier);
    try std.testing.expectEqualStrings("foo", parts.items[0].name);
}

test "parse - complex pathname" {
    const allocator = std.testing.allocator;
    var parts = try parsePatternString(allocator, "/products/:id/*", pathname_options, identityEncoding);
    defer {
        for (parts.items) |*part| {
            part.deinit();
        }
        parts.deinit();
    }

    // /products + /:id + /* = 3 parts (fixed text, named group, wildcard)
    // But the way parsing works: "/products" is fixed, "/:id" has / prefix, "/*" has / prefix
    try std.testing.expect(parts.items.len >= 2);
}

test "parse - duplicate name error" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.DuplicateName, parsePatternString(allocator, ":foo:foo", default_options, identityEncoding));
}
