//! RFC 9651 §4.2 parsing, projected onto what its callers consume: a
//! Dictionary's String values (Reporting §3.3), and an Item's Boolean
//! (HTML's `Origin-Agent-Cluster`). Other item types, inner lists and
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

pub fn parseDictionary(allocator: Allocator, input: []const u8) Error!Dictionary {
    // §4.2 steps 1-2: ASCII, then leading SP (not HTAB).
    for (input) |c| if (c > 127) return error.InvalidField;
    var parser: Parser = .{ .allocator = allocator, .input = input };
    parser.spaces();
    var result: Dictionary = .{};
    errdefer result.deinit(allocator);
    while (parser.peek() != null) {
        const key = try parser.key();
        const string = if (parser.consume('=')) try parser.member() else blk: {
            try parser.parameters();
            break :blk null;
        };
        var string_owned = true;
        defer if (string_owned) {
            if (string) |s| allocator.free(s);
        };
        // §4.2.2 steps 2.4-5: replacement preserves the original position.
        var replaced = false;
        for (result.members.items) |*entry| {
            if (!std.mem.eql(u8, entry.key, key)) continue;
            if (entry.string) |s| allocator.free(s);
            entry.string = string;
            replaced = true;
            break;
        }
        if (!replaced) try result.members.append(allocator, .{ .key = key, .string = string });
        string_owned = false;
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
        if (self.consume('(')) {
            while (true) {
                self.spaces();
                if (self.consume(')')) break;
                if (try self.bare()) |s| self.allocator.free(s);
                try self.parameters();
                if (self.peek() != ' ' and self.peek() != ')') return error.InvalidField;
            }
            try self.parameters();
            return null;
        }
        const parsed_string = try self.bare();
        errdefer if (parsed_string) |s| self.allocator.free(s);
        try self.parameters();
        return parsed_string;
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
        const c = self.peek() orelse return error.InvalidField;
        switch (c) {
            '"' => return try self.string(false),
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
                while (self.peek()) |ch| {
                    if (!std.ascii.isAlphanumeric(ch) and std.mem.indexOfScalar(u8, "!#$%&'*+-.^_`|~:/", ch) == null) break;
                    self.position += 1;
                }
            },
            else => return error.InvalidField,
        }
        return null;
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
