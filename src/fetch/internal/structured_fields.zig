//! RFC 9651 §4.2 parsing, projected onto what its callers consume: a
//! Dictionary's String values (Reporting §3.3), token inner lists (SRI
//! §3.8), an Item's Boolean (HTML's `Origin-Agent-Cluster`), and an Item's
//! Token with its `report-to` String (HTML's opener and embedder policies). Other items and
//! parameters are fully validated before being discarded; one malformed
//! value rejects the entire field. Keys borrow the input; String values are
//! owned.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Error = error{ InvalidField, OutOfMemory };

pub const Member = struct { key: []const u8, string: ?[]u8 };
pub const Dictionary = struct {
    members: std.ArrayListUnmanaged(Member) = .empty,

    pub fn deinit(self: *Dictionary, allocator: Allocator) void {
        for (self.members.items) |member| if (member.string) |s| allocator.free(s);
        self.members.deinit(allocator);
    }
};

/// Keys and tokens borrow the input; each non-null token array is owned.
/// null distinguishes a scalar member from an empty inner list.
pub const TokenListMember = struct { key: []const u8, tokens: ?[]const []const u8 };
pub const TokenListDictionary = struct {
    members: std.ArrayListUnmanaged(TokenListMember) = .empty,

    pub fn deinit(self: *TokenListDictionary, allocator: Allocator) void {
        for (self.members.items) |member| if (member.tokens) |tokens| allocator.free(tokens);
        self.members.deinit(allocator);
    }
};

/// Permissions Policy §9.2 consumes only Tokens and Strings. Other bare
/// items are validated by the same RFC 9651 parser, then discarded.
pub const PolicyItem = union(enum) { token: []const u8, string: []u8 };
pub const PolicyMember = struct {
    key: []const u8,
    inner_list: bool,
    items: []PolicyItem,
    /// A Token parameter, borrowing the input. A String is not an endpoint.
    report_to: ?[]const u8,

    fn deinit(self: PolicyMember, allocator: Allocator) void {
        for (self.items) |item| if (item == .string) allocator.free(item.string);
        allocator.free(self.items);
    }
};
pub const PolicyDictionary = struct {
    members: std.ArrayListUnmanaged(PolicyMember) = .empty,

    pub fn deinit(self: *PolicyDictionary, allocator: Allocator) void {
        for (self.members.items) |member| member.deinit(allocator);
        self.members.deinit(allocator);
    }
};

/// RFC 9651 §4.2's Dictionary projection for Permissions Policy. Keys,
/// Tokens and report-to borrow the input; item arrays and Strings are owned.
/// Scalar versus Inner List is preserved for the caller's field semantics.
pub fn parsePolicyDictionary(allocator: Allocator, input: []const u8) Error!PolicyDictionary {
    for (input) |c| if (c > 127) return error.InvalidField;
    var parser: Parser = .{ .allocator = allocator, .input = input };
    parser.spaces();
    var result: PolicyDictionary = .{};
    errdefer result.deinit(allocator);
    while (parser.peek() != null) {
        const key = try parser.key();
        const member = try policyMember(&parser, key);
        var owned = true;
        defer if (owned) member.deinit(allocator);
        // §4.2.2 steps 2.4–5: the last key replaces the value in place.
        var replaced = false;
        for (result.members.items) |*entry| {
            if (!std.mem.eql(u8, entry.key, key)) continue;
            entry.deinit(allocator);
            entry.* = member;
            replaced = true;
            break;
        }
        if (!replaced) try result.members.append(allocator, member);
        owned = false;
        parser.ows();
        if (parser.peek() == null) break;
        if (!parser.consume(',')) return error.InvalidField;
        parser.ows();
        if (parser.peek() == null) return error.InvalidField;
    }
    return result;
}

fn policyMember(parser: *Parser, key: []const u8) Error!PolicyMember {
    var items: std.ArrayListUnmanaged(PolicyItem) = .empty;
    errdefer {
        for (items.items) |item| if (item == .string) parser.allocator.free(item.string);
        items.deinit(parser.allocator);
    }
    var inner_list = false;
    if (parser.consume('=')) {
        inner_list = parser.consume('(');
        if (inner_list) {
            // §4.2.1.2: each item has its own discarded parameters;
            // report-to belongs to the list, after its closing parenthesis.
            while (true) {
                parser.spaces();
                if (parser.consume(')')) break;
                try appendPolicyItem(parser, &items);
                try parser.parameters();
                if (parser.peek() != ' ' and parser.peek() != ')') return error.InvalidField;
            }
        } else try appendPolicyItem(parser, &items);
    }
    const report_to = try policyParameters(parser);
    return .{ .key = key, .inner_list = inner_list, .items = try items.toOwnedSlice(parser.allocator), .report_to = report_to };
}

fn appendPolicyItem(parser: *Parser, items: *std.ArrayListUnmanaged(PolicyItem)) Error!void {
    const item = try parser.bareItem();
    errdefer if (item.string) |string| parser.allocator.free(string);
    if (item.string) |string| {
        try items.append(parser.allocator, .{ .string = string });
    } else if (item.token) |token| try items.append(parser.allocator, .{ .token = token });
}

fn policyParameters(parser: *Parser) Error!?[]const u8 {
    var report_to: ?[]const u8 = null;
    while (parser.consume(';')) {
        parser.spaces();
        const key = try parser.key();
        const item: Parser.BareItem = if (parser.consume('=')) try parser.bareItem() else .{};
        defer if (item.string) |string| parser.allocator.free(string);
        // §4.2.3.2: duplicate parameter names overwrite earlier ones,
        // including a later non-Token value clearing a Token endpoint.
        if (std.mem.eql(u8, key, "report-to")) report_to = item.token;
    }
    return report_to;
}

pub fn parseDictionary(allocator: Allocator, input: []const u8) Error!Dictionary {
    return parseDictionaryAs(Dictionary, allocator, input);
}

/// SRI §3.8 consumes inner-list tokens only. Non-token items are validated
/// and skipped, as Blink HandleKeyValue and WebKit parseInnerList do.
pub fn parseTokenListDictionary(allocator: Allocator, input: []const u8) Error!TokenListDictionary {
    return parseDictionaryAs(TokenListDictionary, allocator, input);
}

fn parseDictionaryAs(comptime T: type, allocator: Allocator, input: []const u8) Error!T {
    const value_field = if (T == Dictionary) "string" else "tokens";
    const Entry = if (T == Dictionary) Member else TokenListMember;
    const Value = if (T == Dictionary) ?[]u8 else ?[]const []const u8;
    // §4.2 steps 1-2: ASCII, then leading SP (not HTAB).
    for (input) |c| if (c > 127) return error.InvalidField;
    var parser: Parser = .{ .allocator = allocator, .input = input };
    parser.spaces();
    var result: T = .{};
    errdefer result.deinit(allocator);
    while (parser.peek() != null) {
        const key = try parser.key();
        const value: Value = if (parser.consume('=')) blk: {
            break :blk if (T == Dictionary) try parser.member() else try parser.tokenMember();
        } else blk: {
            try parser.parameters();
            break :blk null;
        };
        var value_owned = true;
        defer if (value_owned) {
            if (value) |v| allocator.free(v);
        };
        // §4.2.2 steps 2.4-5: replacement preserves the original position.
        var replaced = false;
        for (result.members.items) |*entry| {
            if (!std.mem.eql(u8, entry.key, key)) continue;
            if (@field(entry.*, value_field)) |v| allocator.free(v);
            @field(entry.*, value_field) = value;
            replaced = true;
            break;
        }
        if (!replaced) {
            var entry: Entry = undefined;
            entry.key = key;
            @field(entry, value_field) = value;
            try result.members.append(allocator, entry);
        }
        value_owned = false;
        parser.ows();
        if (parser.peek() == null) break;
        if (!parser.consume(',')) return error.InvalidField;
        parser.ows();
        if (parser.peek() == null) return error.InvalidField;
    }
    return result;
}

/// RFC 9651 §4.2 with field type "item" - what Fetch's "get a structured
/// field value" given "item" parses - projected onto the Boolean: the item's
/// bare item when it is a Boolean, null for an item of any other type. Its
/// parameters are validated and discarded. A field that is not exactly one
/// valid item is error.InvalidField (Fetch: the header's value is null).
pub fn parseItemBoolean(allocator: Allocator, input: []const u8) Error!?bool {
    // 1. "Convert input_bytes into an ASCII string input_string; if
    // conversion fails, fail parsing."
    for (input) |c| if (c > 127) return error.InvalidField;
    var parser: Parser = .{ .allocator = allocator, .input = input };
    // 2. "Discard any leading SP characters from input_string."
    parser.spaces();
    // 5. "Let output be the result of running Parsing an Item": §4.2.3, a
    // bare item, then its parameters. §4.2.8 "Parsing a Boolean": "?", then
    // "1" (true) or "0" (false).
    var boolean: ?bool = null;
    if (parser.consume('?')) {
        if (parser.consume('1')) {
            boolean = true;
        } else if (parser.consume('0')) {
            boolean = false;
        } else return error.InvalidField;
    } else if (try parser.bare()) |string| allocator.free(string);
    try parser.parameters();
    // 6-7. "Discard any leading SP characters from input_string. If
    // input_string is not empty, fail parsing."
    parser.spaces();
    if (parser.peek() != null) return error.InvalidField;
    return boolean;
}

/// An Item projected onto a Token and its `report-to` String parameter:
/// what HTML's `Cross-Origin-Opener-Policy` and
/// `Cross-Origin-Embedder-Policy` (and their -Report-Only twins) read.
/// `token` borrows the input; `report_to` is OWNED.
pub const TokenItem = struct {
    /// The bare item when it is a Token; null for an item of another type.
    token: ?[]const u8,
    /// The last `report-to` parameter, when it is a String (an earlier one
    /// is overwritten by a later one of any type, §4.2.3.2).
    report_to: ?[]u8,
};

/// RFC 9651 §4.2 with field type "item" - Fetch's "get a structured field
/// value" given "item" - projected onto `TokenItem`. Other parameters are
/// validated and discarded. A field that is not exactly one valid item
/// (a list from two combined headers included) is error.InvalidField.
pub fn parseItemToken(allocator: Allocator, input: []const u8) Error!TokenItem {
    // 1. "Convert input_bytes into an ASCII string input_string; if
    // conversion fails, fail parsing."
    for (input) |c| if (c > 127) return error.InvalidField;
    var parser: Parser = .{ .allocator = allocator, .input = input };
    // 2. "Discard any leading SP characters from input_string."
    parser.spaces();
    // 5. §4.2.3 Parsing an Item: a bare item, then its parameters.
    const bare = try parser.bareItem();
    if (bare.string) |string| allocator.free(string);
    var report_to: ?[]u8 = null;
    errdefer if (report_to) |endpoint| allocator.free(endpoint);
    // §4.2.3.2 Parsing Parameters.
    while (parser.consume(';')) {
        parser.spaces();
        const name = try parser.key();
        const value: Parser.BareItem = if (parser.consume('=')) try parser.bareItem() else .{};
        if (std.mem.eql(u8, name, "report-to")) {
            if (report_to) |previous| allocator.free(previous);
            report_to = value.string;
        } else if (value.string) |string| allocator.free(string);
    }
    // 6-7. "Discard any leading SP characters from input_string. If
    // input_string is not empty, fail parsing."
    parser.spaces();
    if (parser.peek() != null) return error.InvalidField;
    return .{ .token = bare.token, .report_to = report_to };
}

const Parser = struct {
    allocator: Allocator,
    input: []const u8,
    position: usize = 0,

    fn peek(self: *const Parser) ?u8 {
        return if (self.position < self.input.len) self.input[self.position] else null;
    }
    fn consume(self: *Parser, c: u8) bool {
        if (self.peek() != c) return false;
        self.position += 1;
        return true;
    }
    fn spaces(self: *Parser) void {
        while (self.consume(' ')) {}
    }
    fn ows(self: *Parser) void {
        while (self.consume(' ') or self.consume('\t')) {}
    }
    fn key(self: *Parser) Error![]const u8 {
        const first = self.peek() orelse return error.InvalidField;
        if (!std.ascii.isLower(first) and first != '*') return error.InvalidField;
        const start = self.position;
        while (self.peek()) |c| {
            if (!std.ascii.isLower(c) and !std.ascii.isDigit(c) and std.mem.indexOfScalar(u8, "_-.*", c) == null) break;
            self.position += 1;
        }
        return self.input[start..self.position];
    }

    // §4.2.1.1-2: no nested lists, only SP between inner items.
    fn member(self: *Parser) Error!?[]u8 {
        if (self.peek() == '(') {
            self.allocator.free(try self.innerList(false));
            return null;
        }
        const parsed_string = try self.bare();
        errdefer if (parsed_string) |s| self.allocator.free(s);
        try self.parameters();
        return parsed_string;
    }

    fn tokenMember(self: *Parser) Error!?[]const []const u8 {
        if (self.peek() == '(') return try self.innerList(true);
        if (try self.member()) |s| self.allocator.free(s);
        return null;
    }

    fn innerList(self: *Parser, comptime retain_tokens: bool) Error![]const []const u8 {
        if (!self.consume('(')) return error.InvalidField;
        var tokens: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer tokens.deinit(self.allocator);
        while (true) {
            self.spaces();
            if (self.consume(')')) break;
            const item = try self.bareItem();
            defer if (item.string) |s| self.allocator.free(s);
            if (retain_tokens) {
                if (item.token) |token| try tokens.append(self.allocator, token);
            }
            try self.parameters();
            if (self.peek() != ' ' and self.peek() != ')') return error.InvalidField;
        }
        try self.parameters();
        return tokens.toOwnedSlice(self.allocator);
    }
    fn parameters(self: *Parser) Error!void {
        while (self.consume(';')) {
            self.spaces();
            _ = try self.key();
            if (self.consume('=')) {
                if (try self.bare()) |s| self.allocator.free(s);
            }
        }
    }
    fn bare(self: *Parser) Error!?[]u8 {
        return (try self.bareItem()).string;
    }
    const BareItem = struct { string: ?[]u8 = null, token: ?[]const u8 = null };
    fn bareItem(self: *Parser) Error!BareItem {
        const c = self.peek() orelse return error.InvalidField;
        switch (c) {
            '"' => return .{ .string = try self.string(false) },
            '%' => {
                self.position += 1;
                const s = try self.string(true);
                self.allocator.free(s);
            },
            '-', '0'...'9' => _ = try self.number(),
            '@' => {
                self.position += 1;
                if (try self.number()) return error.InvalidField;
            },
            '?' => {
                self.position += 1;
                if (!self.consume('0') and !self.consume('1')) return error.InvalidField;
            },
            ':' => try self.bytes(),
            'A'...'Z', 'a'...'z', '*' => {
                // §4.2.6: tchar plus ':' and '/'.
                const start = self.position;
                while (self.peek()) |ch| {
                    if (!std.ascii.isAlphanumeric(ch) and std.mem.indexOfScalar(u8, "!#$%&'*+-.^_`|~:/", ch) == null) break;
                    self.position += 1;
                }
                return .{ .token = self.input[start..self.position] };
            },
            else => return error.InvalidField,
        }
        return .{};
    }
    /// §4.2.4: return true for Decimal (Date requires Integer).
    fn number(self: *Parser) Error!bool {
        _ = self.consume('-');
        const start = self.position;
        while (self.peek()) |c| {
            if (!std.ascii.isDigit(c)) break;
            self.position += 1;
        }
        const digits = self.position - start;
        if (digits == 0 or digits > 15) return error.InvalidField;
        if (!self.consume('.')) return false;
        if (digits > 12) return error.InvalidField;
        const fraction = self.position;
        while (self.peek()) |c| {
            if (!std.ascii.isDigit(c)) break;
            self.position += 1;
        }
        if (self.position == fraction or self.position - fraction > 3) return error.InvalidField;
        return true;
    }
    /// §4.2.5 and §4.2.10 differ in escaping and the resulting character set.
    fn string(self: *Parser, display: bool) Error![]u8 {
        if (!self.consume('"')) return error.InvalidField;
        var out: std.ArrayListUnmanaged(u8) = .empty;
        errdefer out.deinit(self.allocator);
        while (self.peek()) |c| {
            self.position += 1;
            if (c == '"') {
                if (display and !std.unicode.utf8ValidateSlice(out.items)) return error.InvalidField;
                return out.toOwnedSlice(self.allocator);
            }
            if (c < 0x20 or c >= 0x7f) return error.InvalidField;
            if (display and c == '%') {
                if (self.input.len - self.position < 2) return error.InvalidField;
                const high = try lowerHex(self.input[self.position]);
                const low = try lowerHex(self.input[self.position + 1]);
                self.position += 2;
                try out.append(self.allocator, high * 16 + low);
            } else if (!display and c == '\\') {
                const escaped = self.peek() orelse return error.InvalidField;
                if (escaped != '"' and escaped != '\\') return error.InvalidField;
                self.position += 1;
                try out.append(self.allocator, escaped);
            } else try out.append(self.allocator, c);
        }
        return error.InvalidField;
    }
    fn lowerHex(c: u8) Error!u8 {
        return switch (c) {
            '0'...'9' => c - '0',
            'a'...'f' => c - 'a' + 10,
            else => error.InvalidField,
        };
    }
    // §4.2.7: validate the encoding without materializing discarded bytes.
    // Missing padding and nonzero pad bits are accepted as recommended.
    fn bytes(self: *Parser) Error!void {
        self.position += 1;
        var digits: usize = 0;
        var padding: usize = 0;
        while (self.peek()) |c| {
            self.position += 1;
            if (c == ':') {
                if (digits % 4 == 1 or padding > 2) return error.InvalidField;
                // §4.2.7 step 7 synthesizes missing padding, including
                // one missing '=' in a two-padding encoding such as Zg=.
                const required_padding = (4 - digits % 4) % 4;
                if (padding > required_padding) return error.InvalidField;
                return;
            }
            if (c == '=') {
                padding += 1;
            } else if ((std.ascii.isAlphanumeric(c) or c == '+' or c == '/') and padding == 0) {
                digits += 1;
            } else return error.InvalidField;
        }
        return error.InvalidField;
    }
};
