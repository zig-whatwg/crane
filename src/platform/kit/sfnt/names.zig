//! The name table's strings, chosen as CSS Fonts 4 4.3.3.1 says for local():
//! "the US English version must be used (language ID = 0x409 for Windows and
//! language ID = 0 for Macintosh) or the first localization when a US
//! English full font name is not available" - the rule applied here to every
//! name a face reports. Records OTS discards (an unknown platform or
//! encoding, a string outside the table, a PostScript name it refuses) are
//! never chosen, and a PostScript name's characters outside URI's
//! "unreserved" set read as '_' (OTS name.cc SanitizePsName*).

const std = @import("std");
const bytes = @import("bytes.zig");

pub const id = struct {
    pub const family: u16 = 1;
    pub const subfamily: u16 = 2;
    pub const full: u16 = 4;
    pub const postscript: u16 = 6;
    pub const typographic_family: u16 = 16;
    pub const typographic_subfamily: u16 = 17;
};

const Encoding = enum { utf16be, mac_roman };

/// One usable record's string, and how its bytes are encoded.
pub const Name = struct {
    text: []const u8,
    encoding: Encoding,
    postscript: bool,

    /// The UTF-8 length of the decoded string.
    pub fn utf8Len(self: Name) usize {
        var buffer: [4]u8 = undefined;
        var total: usize = 0;
        var it = self.iterator();
        while (it.next()) |cp| total += std.unicode.utf8Encode(cp, &buffer) catch unreachable;
        return total;
    }

    /// Write the decoded string to `out` (utf8Len bytes); returns them.
    pub fn writeUtf8(self: Name, out: []u8) []u8 {
        var at: usize = 0;
        var it = self.iterator();
        while (it.next()) |cp| at += std.unicode.utf8Encode(cp, out[at..]) catch unreachable;
        return out[0..at];
    }

    fn iterator(self: Name) Iterator {
        return .{ .name = self };
    }
};

const Iterator = struct {
    name: Name,
    pos: usize = 0,

    fn next(self: *Iterator) ?u21 {
        const text = self.name.text;
        const cp: u21 = switch (self.name.encoding) {
            .mac_roman => blk: {
                if (self.pos >= text.len) return null;
                const b = text[self.pos];
                self.pos += 1;
                break :blk if (b < 0x80) b else mac_roman[b - 0x80];
            },
            .utf16be => blk: {
                if (self.pos + 2 > text.len) return null;
                const unit = std.mem.readInt(u16, text[self.pos..][0..2], .big);
                self.pos += 2;
                if (unit >= 0xD800 and unit <= 0xDBFF and self.pos + 2 <= text.len) {
                    const low = std.mem.readInt(u16, text[self.pos..][0..2], .big);
                    if (low >= 0xDC00 and low <= 0xDFFF) {
                        self.pos += 2;
                        break :blk 0x10000 + ((@as(u21, unit) - 0xD800) << 10) + (low - 0xDC00);
                    }
                }
                // A lone surrogate reads as U+FFFD.
                break :blk if (unit >= 0xD800 and unit <= 0xDFFF) 0xFFFD else unit;
            },
        };
        if (self.name.postscript and !allowedInPostScriptName(cp)) return '_';
        return cp;
    }
};

fn allowedInPostScriptName(cp: u21) bool {
    return (cp < 0x80 and std.ascii.isAlphanumeric(@intCast(cp))) or cp == '-' or cp == '.' or cp == '_' or cp == '~';
}

/// The string for name `name_id` in the name table `table` (checked by
/// tables.zig), or null when it has none.
pub fn find(table: []const u8, name_id: u16) ?Name {
    const count = bytes.u16At(table, 2) catch return null;
    const string_offset = bytes.u16At(table, 4) catch return null;
    var english: ?Name = null;
    var english_rank: u2 = 0;
    var first: ?Name = null;
    for (0..count) |i| {
        const at = 6 + 12 * i;
        const platform = bytes.u16At(table, at) catch return null;
        const encoding = bytes.u16At(table, at + 2) catch return null;
        const language = bytes.u16At(table, at + 4) catch return null;
        const record_id = bytes.u16At(table, at + 6) catch return null;
        const length = bytes.u16At(table, at + 8) catch return null;
        const offset = bytes.u16At(table, at + 10) catch return null;
        if (record_id != name_id) continue;
        // OTS discards unknown platforms and encodings, and strings outside
        // the table.
        const known = switch (platform) {
            0 => encoding <= 6,
            1 => encoding <= 32,
            2 => encoding <= 2,
            3 => encoding <= 6 or encoding == 10,
            4 => encoding <= 255,
            else => false,
        };
        if (!known) continue;
        if (@as(usize, string_offset) + offset + length > table.len) continue;
        const text = table[@as(usize, string_offset) + offset ..][0..length];
        // Only the encodings Crane decodes: Unicode, Windows Unicode and
        // symbol (UTF-16BE), and Mac Roman.
        const decoded: Encoding = switch (platform) {
            0 => .utf16be,
            3 => if (encoding == 0 or encoding == 1 or encoding == 10) .utf16be else continue,
            1 => if (encoding == 0) .mac_roman else continue,
            else => continue,
        };
        if (decoded == .utf16be and text.len & 1 != 0) continue;
        const postscript = name_id == id.postscript;
        if (postscript) {
            // OTS: a PostScript name over 63 characters, or with a
            // character beyond Latin-1, is refused.
            switch (decoded) {
                .mac_roman => if (text.len > 63) continue,
                .utf16be => {
                    if (text.len > 2 * 63) continue;
                    var j: usize = 0;
                    const beyond = while (j < text.len) : (j += 2) {
                        if (text[j] != 0) break true;
                    } else false;
                    if (beyond) continue;
                },
            }
        }
        const name: Name = .{ .text = text, .encoding = decoded, .postscript = postscript };
        const rank: u2 = if (platform == 3 and language == 0x409) 2 else if (platform == 1 and language == 0) 1 else 0;
        if (rank > english_rank) {
            english = name;
            english_rank = rank;
        }
        if (first == null) first = name;
    }
    return english orelse first;
}

/// Mac OS Roman's upper half, as Unicode.
const mac_roman = [128]u21{
    0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1, 0x00E0, 0x00E2, 0x00E4, 0x00E3, 0x00E5, 0x00E7, 0x00E9, 0x00E8,
    0x00EA, 0x00EB, 0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3, 0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9, 0x00FB, 0x00FC,
    0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF, 0x00AE, 0x00A9, 0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8,
    0x221E, 0x00B1, 0x2264, 0x2265, 0x00A5, 0x00B5, 0x2202, 0x2211, 0x220F, 0x03C0, 0x222B, 0x00AA, 0x00BA, 0x03A9, 0x00E6, 0x00F8,
    0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248, 0x2206, 0x00AB, 0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153,
    0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA, 0x00FF, 0x0178, 0x2044, 0x20AC, 0x2039, 0x203A, 0xFB01, 0xFB02,
    0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1, 0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4,
    0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC, 0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7,
};

const testing = std.testing;

/// A name table with the given records (platform, encoding, language,
/// name ID, string), strings stored in order.
fn nameTable(comptime records: anytype) []const u8 {
    comptime {
        var strings: []const u8 = "";
        var head: []const u8 = &[_]u8{ 0, 0, 0, records.len, 0, 6 + 12 * records.len };
        for (records) |rec| {
            head = head ++ [_]u8{
                0, rec[0],     0, rec[1],      rec[2] >> 8, rec[2] & 0xff, 0, rec[3],
                0, rec[4].len, 0, strings.len,
            };
            strings = strings ++ rec[4];
        }
        const out = head ++ strings;
        return out;
    }
}

fn utf8(name: Name) ![]u8 {
    const out = try testing.allocator.alloc(u8, name.utf8Len());
    _ = name.writeUtf8(out);
    return out;
}

test "the US English Windows record wins; then the Mac English one; then the first" {
    const t = comptime nameTable(.{
        .{ 3, 1, 0x40C, 1, "\x00F\x00r" },
        .{ 1, 0, 0, 1, "Mac" },
        .{ 3, 1, 0x409, 1, "\x00W\x00i\x00n" },
    });
    const won = try utf8(find(t, 1).?);
    defer testing.allocator.free(won);
    try testing.expectEqualStrings("Win", won);

    const mac_only = comptime nameTable(.{ .{ 3, 1, 0x40C, 4, "\x00F\x00r" }, .{ 1, 0, 0, 4, "Mac\x8e" } });
    const mac = try utf8(find(mac_only, 4).?);
    defer testing.allocator.free(mac);
    try testing.expectEqualStrings("Mac\u{e9}", mac);

    const french = comptime nameTable(.{.{ 3, 1, 0x40C, 4, "\x00F\x00r" }});
    const fr = try utf8(find(french, 4).?);
    defer testing.allocator.free(fr);
    try testing.expectEqualStrings("Fr", fr);
    try testing.expect(find(french, 6) == null);
}

test "a PostScript name: unreserved characters only, and none beyond Latin-1" {
    const t = comptime nameTable(.{.{ 3, 1, 0x409, 6, "\x00A\x00 \x00b" }});
    const ps = try utf8(find(t, 6).?);
    defer testing.allocator.free(ps);
    try testing.expectEqualStrings("A_b", ps);
    const wide = comptime nameTable(.{.{ 3, 1, 0x409, 6, "\x6c\x34" }});
    try testing.expect(find(wide, 6) == null);
}

test "UTF-16: a surrogate pair decodes; a lone surrogate reads U+FFFD" {
    const t = comptime nameTable(.{.{ 3, 10, 0x409, 1, "\xd8\x3d\xde\x00\xd8\x00" }});
    const s = try utf8(find(t, 1).?);
    defer testing.allocator.free(s);
    try testing.expectEqualStrings("\u{1F600}\u{FFFD}", s);
}
