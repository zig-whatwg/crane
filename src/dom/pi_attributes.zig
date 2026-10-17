//! DOM 4.13 ProcessingInstruction pseudo-attributes (XML Stylesheet section 3).
//! Values use XML references, not HTML entities; names use XML 1.0's Name
//! production when parsing, and DOM's relaxed names when changed through IDL.
const std = @import("std");
const infra = @import("infra");
const ParseError = error{ OutOfMemory, InvalidPseudoAttributes };

fn nameStart(cp: u21) bool {
    return cp == ':' or cp == '_' or (cp >= 'A' and cp <= 'Z') or (cp >= 'a' and cp <= 'z') or
        (cp >= 0xC0 and cp <= 0xD6) or (cp >= 0xD8 and cp <= 0xF6) or (cp >= 0xF8 and cp <= 0x2FF) or
        (cp >= 0x370 and cp <= 0x37D) or (cp >= 0x37F and cp <= 0x1FFF) or
        (cp >= 0x200C and cp <= 0x200D) or (cp >= 0x2070 and cp <= 0x218F) or
        (cp >= 0x2C00 and cp <= 0x2FEF) or (cp >= 0x3001 and cp <= 0xD7FF) or
        (cp >= 0xF900 and cp <= 0xFDCF) or (cp >= 0xFDF0 and cp <= 0xFFFD) or
        (cp >= 0x10000 and cp <= 0xEFFFF);
}

fn nameChar(cp: u21) bool {
    return nameStart(cp) or cp == '-' or cp == '.' or (cp >= '0' and cp <= '9') or cp == 0xB7 or
        (cp >= 0x300 and cp <= 0x36F) or (cp >= 0x203F and cp <= 0x2040);
}

fn nextCodePoint(bytes: []const u8, at: *usize) error{InvalidPseudoAttributes}!u21 {
    if (at.* >= bytes.len) return error.InvalidPseudoAttributes;
    const length = std.unicode.utf8ByteSequenceLength(bytes[at.*]) catch return error.InvalidPseudoAttributes;
    if (bytes.len - at.* < length) return error.InvalidPseudoAttributes;
    const cp = std.unicode.utf8Decode(bytes[at.*..][0..length]) catch return error.InvalidPseudoAttributes;
    at.* += length;
    return cp;
}

/// XML 1.0 fifth edition, productions [4] NameStartChar, [4a] NameChar, [5] Name.
pub fn isXmlName(name: []const u8) bool {
    var at: usize = 0;
    if (!nameStart(nextCodePoint(name, &at) catch return false)) return false;
    while (at < name.len) {
        if (!nameChar(nextCodePoint(name, &at) catch return false)) return false;
    }
    return true;
}

fn xmlChar(cp: u32) bool {
    return cp == 0x9 or cp == 0xA or cp == 0xD or (cp >= 0x20 and cp <= 0xD7FF) or
        (cp >= 0xE000 and cp <= 0xFFFD) or (cp >= 0x10000 and cp <= 0x10FFFF);
}

fn isSpace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\n' or byte == '\r';
}

fn skipSpace(data: []const u8, at: *usize) void {
    while (at.* < data.len and isSpace(data[at.*])) at.* += 1;
}

pub const Attributes = struct {
    pub const Entry = struct { name: []const u8, value: []const u8 };
    allocator: std.mem.Allocator,
    entries: infra.List(Entry),

    pub fn init(allocator: std.mem.Allocator) Attributes {
        return .{ .allocator = allocator, .entries = infra.List(Entry).init(allocator) };
    }

    fn clear(self: *Attributes) void {
        for (self.entries.items()) |entry| {
            self.allocator.free(entry.name);
            self.allocator.free(entry.value);
        }
        self.entries.clear();
    }

    pub fn deinit(self: *Attributes) void {
        self.clear();
        self.entries.deinit();
    }

    /// XML Stylesheet 3: PseudoAtts, duplicate rejection, and reference expansion.
    /// An error leaves the whole map empty, including allocation failures.
    pub fn parse(self: *Attributes, data: []const u8) ParseError!void {
        self.clear();
        errdefer self.clear();
        var at: usize = 0;
        skipSpace(data, &at);
        while (at < data.len) {
            const start = at;
            while (at < data.len and data[at] != '=' and !isSpace(data[at])) at += 1;
            const name = data[start..at];
            if (!isXmlName(name) or self.get(name) != null) return error.InvalidPseudoAttributes;
            skipSpace(data, &at);
            if (at == data.len or data[at] != '=') return error.InvalidPseudoAttributes;
            at += 1;
            skipSpace(data, &at);
            if (at == data.len or (data[at] != '\'' and data[at] != '"')) return error.InvalidPseudoAttributes;
            const quote = data[at];
            at += 1;
            var value = infra.List(u8).init(self.allocator);
            defer value.deinit();
            while (at < data.len and data[at] != quote) {
                if (data[at] == '<') return error.InvalidPseudoAttributes;
                if (data[at] == '&') {
                    const end = at + 1 + (std.mem.indexOfScalar(u8, data[at + 1 ..], ';') orelse return error.InvalidPseudoAttributes);
                    const reference = data[at + 1 .. end];
                    const cp = try decodeReference(reference);
                    var encoded: [4]u8 = undefined;
                    const length = std.unicode.utf8Encode(cp, &encoded) catch return error.InvalidPseudoAttributes;
                    try value.appendSlice(encoded[0..length]);
                    at = end + 1;
                } else {
                    const begin = at;
                    const cp = try nextCodePoint(data, &at);
                    // XML 6 notation: a negated character class still matches only Char.
                    if (!xmlChar(cp)) return error.InvalidPseudoAttributes;
                    try value.appendSlice(data[begin..at]);
                }
            }
            if (at == data.len) return error.InvalidPseudoAttributes;
            at += 1;
            try self.set(name, value.items());
            // PseudoAtts requires XML S between consecutive attributes.
            if (at < data.len and !isSpace(data[at])) return error.InvalidPseudoAttributes;
            skipSpace(data, &at);
        }
    }

    pub fn get(self: *const Attributes, name: []const u8) ?[]const u8 {
        for (self.entries.items()) |entry| {
            if (std.mem.eql(u8, entry.name, name)) return entry.value;
        }
        return null;
    }

    pub fn set(self: *Attributes, name: []const u8, value: []const u8) error{OutOfMemory}!void {
        const copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(copy);
        for (self.entries.toSliceMut()) |*entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                self.allocator.free(entry.value);
                entry.value = copy;
                return;
            }
        }
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        try self.entries.append(.{ .name = name_copy, .value = copy });
    }

    pub fn remove(self: *Attributes, name: []const u8) void {
        for (self.entries.items(), 0..) |entry, i| {
            if (std.mem.eql(u8, entry.name, name)) {
                const removed = self.entries.remove(i) catch unreachable;
                self.allocator.free(removed.name);
                self.allocator.free(removed.value);
                return;
            }
        }
    }

    /// DOM update-data-from-attributes steps 1-3. Escape > as U+003E (the
    /// October 2026 erratum b76da7af5f), and leave = and single quotes intact.
    pub fn serialize(self: *const Attributes) error{OutOfMemory}![]u8 {
        var result = infra.List(u8).init(self.allocator);
        errdefer result.deinit();
        for (self.entries.items(), 0..) |entry, i| {
            if (i != 0) try result.append(' ');
            try result.appendSlice(entry.name);
            try result.appendSlice("=\"");
            for (entry.value) |byte| switch (byte) {
                '&' => try result.appendSlice("&amp;"),
                '<' => try result.appendSlice("&lt;"),
                '>' => try result.appendSlice("&gt;"),
                '"' => try result.appendSlice("&quot;"),
                else => try result.append(byte),
            };
            try result.append('"');
        }
        return result.toOwnedSlice();
    }
};

fn decodeReference(reference: []const u8) error{InvalidPseudoAttributes}!u21 {
    const names = .{ "amp", "lt", "gt", "quot", "apos" };
    const values = .{ '&', '<', '>', '"', '\'' };
    inline for (names, values) |name, value| {
        if (std.mem.eql(u8, reference, name)) return value;
    }
    if (reference.len < 2 or reference[0] != '#') return error.InvalidPseudoAttributes;
    const hex = reference[1] == 'x';
    const digits = reference[if (hex) @as(usize, 2) else 1..];
    if (digits.len == 0) return error.InvalidPseudoAttributes;
    for (digits) |digit| {
        if (if (hex) !std.ascii.isHex(digit) else !std.ascii.isDigit(digit)) return error.InvalidPseudoAttributes;
    }
    const cp = std.fmt.parseInt(u32, digits, if (hex) 16 else 10) catch return error.InvalidPseudoAttributes;
    if (!xmlChar(cp)) return error.InvalidPseudoAttributes;
    return @intCast(cp);
}
