//! Family and local() name comparison: CSS Fonts 4 5.1's Unicode "Default
//! Caseless Matching" (full case folding, CaseFolding.txt statuses C and F,
//! no normalization), for every character whose folding is ASCII - the
//! ASCII letters, ß and ẞ (ss), ſ (s), the Kelvin sign (k) and the Latin
//! ligatures U+FB00-FB06. Any other character compares exactly: a deviation
//! only for names with non-ASCII letters that differ by case, which no name
//! the built-in platforms compare here has.

const std = @import("std");

/// `a` and `b` (UTF-8) are the same name, caselessly.
pub fn equal(a: []const u8, b: []const u8) bool {
    var fa: Folder = .{ .text = a };
    var fb: Folder = .{ .text = b };
    while (true) {
        const ca = fa.next();
        const cb = fb.next();
        if (ca == null or cb == null) return ca == null and cb == null;
        if (ca.? != cb.?) return false;
    }
}

const Folder = struct {
    text: []const u8,
    pos: usize = 0,
    pending: []const u8 = "",

    fn next(self: *Folder) ?u21 {
        if (self.pending.len > 0) {
            defer self.pending = self.pending[1..];
            return self.pending[0];
        }
        if (self.pos >= self.text.len) return null;
        const len = std.unicode.utf8ByteSequenceLength(self.text[self.pos]) catch {
            self.pos += 1;
            return 0xFFFD;
        };
        if (self.pos + len > self.text.len) {
            self.pos = self.text.len;
            return 0xFFFD;
        }
        const cp = std.unicode.utf8Decode(self.text[self.pos..][0..len]) catch 0xFFFD;
        self.pos += len;
        const folded: []const u8 = switch (cp) {
            'A'...'Z' => return cp + 32,
            0x00DF, 0x1E9E => "ss",
            0x017F => "s",
            0x212A => "k",
            0xFB00 => "ff",
            0xFB01 => "fi",
            0xFB02 => "fl",
            0xFB03 => "ffi",
            0xFB04 => "ffl",
            0xFB05, 0xFB06 => "st",
            else => return cp,
        };
        self.pending = folded[1..];
        return folded[0];
    }
};

test "ASCII letters fold; the ASCII-folding specials fold to their letters" {
    try std.testing.expect(equal("Times New Roman", "times new ROMAN"));
    try std.testing.expect(equal("\u{212A}rane", "krane"));
    try std.testing.expect(equal("Stra\u{DF}e", "STRASSE"));
    try std.testing.expect(equal("\u{FB01}ne", "FINE"));
    try std.testing.expect(!equal("Arial", "Arial "));
    try std.testing.expect(!equal("Ahem", "Ahe"));
    try std.testing.expect(!equal("\u{C9}", "\u{E9}"));
}
