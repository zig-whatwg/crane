//! HTML Input Stream
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#preprocessing-the-input-stream
//! HTML Standard §13.2.3.5 "Preprocessing the input stream"
//!
//! The input stream consists of the characters pushed into it as the input
//! byte stream is decoded or from the various APIs that directly manipulate
//! the input stream.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const ParseError = @import("parse_errors.zig").ParseError;
const ParseErrorCode = @import("parse_errors.zig").ParseErrorCode;
const ParseErrorCallback = @import("parse_errors.zig").ParseErrorCallback;

/// Represents a Unicode code point or EOF.
pub const InputCharacter = union(enum) {
    /// A Unicode code point.
    codepoint: u21,

    /// End of file.
    eof,

    /// Get the codepoint value, or null for EOF.
    pub fn getCodepoint(self: InputCharacter) ?u21 {
        return switch (self) {
            .codepoint => |cp| cp,
            .eof => null,
        };
    }

    /// Check if this is EOF.
    pub fn isEof(self: InputCharacter) bool {
        return self == .eof;
    }

    /// Check if this is a specific character.
    pub fn is(self: InputCharacter, char: u21) bool {
        return switch (self) {
            .codepoint => |cp| cp == char,
            .eof => false,
        };
    }

    /// Check if this is ASCII alpha (A-Z or a-z).
    pub fn isAsciiAlpha(self: InputCharacter) bool {
        return switch (self) {
            .codepoint => |cp| (cp >= 'A' and cp <= 'Z') or (cp >= 'a' and cp <= 'z'),
            .eof => false,
        };
    }

    /// Check if this is ASCII upper alpha (A-Z).
    pub fn isAsciiUpperAlpha(self: InputCharacter) bool {
        return switch (self) {
            .codepoint => |cp| cp >= 'A' and cp <= 'Z',
            .eof => false,
        };
    }

    /// Check if this is ASCII lower alpha (a-z).
    pub fn isAsciiLowerAlpha(self: InputCharacter) bool {
        return switch (self) {
            .codepoint => |cp| cp >= 'a' and cp <= 'z',
            .eof => false,
        };
    }

    /// Check if this is ASCII digit (0-9).
    pub fn isAsciiDigit(self: InputCharacter) bool {
        return switch (self) {
            .codepoint => |cp| cp >= '0' and cp <= '9',
            .eof => false,
        };
    }

    /// Check if this is ASCII alphanumeric.
    pub fn isAsciiAlphanumeric(self: InputCharacter) bool {
        return self.isAsciiAlpha() or self.isAsciiDigit();
    }

    /// Check if this is ASCII hex digit.
    pub fn isAsciiHexDigit(self: InputCharacter) bool {
        return switch (self) {
            .codepoint => |cp| (cp >= '0' and cp <= '9') or (cp >= 'A' and cp <= 'F') or (cp >= 'a' and cp <= 'f'),
            .eof => false,
        };
    }

    /// Check if this is ASCII upper hex digit (A-F).
    pub fn isAsciiUpperHexDigit(self: InputCharacter) bool {
        return switch (self) {
            .codepoint => |cp| cp >= 'A' and cp <= 'F',
            .eof => false,
        };
    }

    /// Check if this is ASCII lower hex digit (a-f).
    pub fn isAsciiLowerHexDigit(self: InputCharacter) bool {
        return switch (self) {
            .codepoint => |cp| cp >= 'a' and cp <= 'f',
            .eof => false,
        };
    }

    /// Check if this is ASCII whitespace (tab, LF, FF, CR, space).
    pub fn isAsciiWhitespace(self: InputCharacter) bool {
        return switch (self) {
            .codepoint => |cp| cp == 0x09 or cp == 0x0A or cp == 0x0C or cp == 0x0D or cp == 0x20,
            .eof => false,
        };
    }

    /// Check if this is HTML whitespace (tab, LF, FF, space - no CR after preprocessing).
    pub fn isHtmlWhitespace(self: InputCharacter) bool {
        return switch (self) {
            .codepoint => |cp| cp == 0x09 or cp == 0x0A or cp == 0x0C or cp == 0x20,
            .eof => false,
        };
    }

    /// Convert to lowercase if ASCII upper alpha.
    pub fn toLowercase(self: InputCharacter) InputCharacter {
        return switch (self) {
            .codepoint => |cp| if (cp >= 'A' and cp <= 'Z')
                InputCharacter{ .codepoint = cp + 0x20 }
            else
                self,
            .eof => self,
        };
    }

    /// Get as u8 if it fits, otherwise null.
    pub fn toU8(self: InputCharacter) ?u8 {
        return switch (self) {
            .codepoint => |cp| if (cp <= 0xFF) @as(u8, @intCast(cp)) else null,
            .eof => null,
        };
    }
};

/// Input stream for the HTML tokenizer.
///
/// HTML Standard §13.2.3.5:
/// "The input stream consists of the characters pushed into it as the input
/// byte stream is decoded or from the various APIs that directly manipulate
/// the input stream."
pub const InputStream = struct {
    /// The input data (UTF-8 encoded).
    data: []const u8,

    /// Current byte position in the input.
    position: usize,

    /// Current line number (1-based).
    line: u32,

    /// Current column number (1-based).
    column: u32,

    /// Whether we just saw a CR (for CRLF handling).
    last_was_cr: bool,

    /// Error callback for reporting parse errors.
    error_callback: ?ParseErrorCallback,

    /// Context for error callback.
    error_context: ?*anyopaque,

    /// Initialize an input stream from UTF-8 data.
    pub fn init(data: []const u8) InputStream {
        return InputStream{
            .data = data,
            .position = 0,
            .line = 1,
            .column = 1,
            .last_was_cr = false,
            .error_callback = null,
            .error_context = null,
        };
    }

    /// Set error callback for parse error reporting.
    pub fn setErrorCallback(self: *InputStream, callback: ParseErrorCallback, context: ?*anyopaque) void {
        self.error_callback = callback;
        self.error_context = context;
    }

    /// Report a parse error.
    pub fn reportError(self: *InputStream, code: ParseErrorCode) void {
        if (self.error_callback) |callback| {
            callback(ParseError{
                .code = code,
                .line = self.line,
                .column = self.column,
                .offset = self.position,
            }, self.error_context);
        }
    }

    /// Consume the next input character.
    ///
    /// HTML Standard §13.2.3.5:
    /// "Before the tokenization stage, the input stream must be preprocessed
    /// by normalizing newlines. Thus, newlines in HTML DOMs are represented
    /// by U+000A LF characters, and there are never any U+000D CR characters
    /// in the input to the tokenization stage."
    pub fn consume(self: *InputStream) InputCharacter {
        if (self.position >= self.data.len) {
            return .eof;
        }

        // Decode UTF-8
        const result = self.decodeUtf8();
        if (result.codepoint) |cp| {
            self.position += result.bytes_consumed;

            // Preprocess: normalize newlines
            // CR (0x0D) -> LF (0x0A)
            // CRLF -> LF (CR followed by LF becomes single LF)
            if (cp == 0x0D) {
                // CR - emit LF, mark that we saw CR
                self.last_was_cr = true;
                self.line += 1;
                self.column = 1;
                return InputCharacter{ .codepoint = 0x0A };
            } else if (cp == 0x0A) {
                if (self.last_was_cr) {
                    // LF after CR - skip it (CRLF already emitted as single LF)
                    self.last_was_cr = false;
                    return self.consume(); // Recurse to get next char
                } else {
                    // Standalone LF
                    self.line += 1;
                    self.column = 1;
                    self.last_was_cr = false;
                    return InputCharacter{ .codepoint = cp };
                }
            } else {
                self.last_was_cr = false;

                // Check for parse errors in input stream
                self.checkInputStreamErrors(cp);

                // Update column
                self.column += 1;

                return InputCharacter{ .codepoint = cp };
            }
        } else {
            // Invalid UTF-8 - emit replacement character
            self.position += result.bytes_consumed;
            self.column += 1;
            self.last_was_cr = false;
            return InputCharacter{ .codepoint = 0xFFFD };
        }
    }

    /// Check for parse errors in the input stream.
    fn checkInputStreamErrors(self: *InputStream, cp: u21) void {
        // Surrogate check (should not appear in valid UTF-8, but check anyway)
        if (cp >= 0xD800 and cp <= 0xDFFF) {
            self.reportError(.surrogate_in_input_stream);
        }
        // Noncharacter check
        else if ((cp >= 0xFDD0 and cp <= 0xFDEF) or
            (cp & 0xFFFF == 0xFFFE) or (cp & 0xFFFF == 0xFFFF))
        {
            self.reportError(.noncharacter_in_input_stream);
        }
        // Control character check (except ASCII whitespace and NULL)
        else if (cp != 0x00 and cp != 0x09 and cp != 0x0A and cp != 0x0C and cp != 0x0D and cp != 0x20) {
            if ((cp >= 0x01 and cp <= 0x08) or
                (cp >= 0x0E and cp <= 0x1F) or
                (cp >= 0x7F and cp <= 0x9F))
            {
                self.reportError(.control_character_in_input_stream);
            }
        }
    }

    /// Decode a UTF-8 code point at the current position.
    fn decodeUtf8(self: *InputStream) struct { codepoint: ?u21, bytes_consumed: usize } {
        if (self.position >= self.data.len) {
            return .{ .codepoint = null, .bytes_consumed = 0 };
        }

        const first = self.data[self.position];

        // Single byte (ASCII)
        if (first & 0x80 == 0) {
            return .{ .codepoint = first, .bytes_consumed = 1 };
        }

        // Multi-byte sequence
        const len: usize = if (first & 0xE0 == 0xC0)
            2
        else if (first & 0xF0 == 0xE0)
            3
        else if (first & 0xF8 == 0xF0)
            4
        else
            // Invalid leading byte
            return .{ .codepoint = null, .bytes_consumed = 1 };

        if (self.position + len > self.data.len) {
            // Not enough bytes
            return .{ .codepoint = null, .bytes_consumed = 1 };
        }

        // Decode based on length
        var cp: u21 = switch (len) {
            2 => @as(u21, first & 0x1F),
            3 => @as(u21, first & 0x0F),
            4 => @as(u21, first & 0x07),
            else => unreachable,
        };

        for (1..len) |i| {
            const byte = self.data[self.position + i];
            if (byte & 0xC0 != 0x80) {
                // Invalid continuation byte
                return .{ .codepoint = null, .bytes_consumed = 1 };
            }
            cp = (cp << 6) | @as(u21, byte & 0x3F);
        }

        // Check for overlong encoding
        const min_cp: u21 = switch (len) {
            2 => 0x80,
            3 => 0x800,
            4 => 0x10000,
            else => unreachable,
        };

        if (cp < min_cp or cp > 0x10FFFF) {
            return .{ .codepoint = null, .bytes_consumed = len };
        }

        return .{ .codepoint = cp, .bytes_consumed = len };
    }

    /// Peek at the next character without consuming it.
    pub fn peek(self: *InputStream) InputCharacter {
        const saved_pos = self.position;
        const saved_line = self.line;
        const saved_col = self.column;
        const saved_cr = self.last_was_cr;

        const char = self.consume();

        self.position = saved_pos;
        self.line = saved_line;
        self.column = saved_col;
        self.last_was_cr = saved_cr;

        return char;
    }

    /// Peek at N characters ahead without consuming.
    pub fn peekAhead(self: *InputStream, n: usize) InputCharacter {
        const saved_pos = self.position;
        const saved_line = self.line;
        const saved_col = self.column;
        const saved_cr = self.last_was_cr;

        var char: InputCharacter = .eof;
        var i: usize = 0;
        while (i <= n) : (i += 1) {
            char = self.consume();
            if (char.isEof()) break;
        }

        self.position = saved_pos;
        self.line = saved_line;
        self.column = saved_col;
        self.last_was_cr = saved_cr;

        return char;
    }

    /// Check if the next characters match a string (case-insensitive).
    pub fn matchesAsciiCaseInsensitive(self: *InputStream, expected: []const u8) bool {
        const saved_pos = self.position;
        const saved_line = self.line;
        const saved_col = self.column;
        const saved_cr = self.last_was_cr;

        var matches = true;
        for (expected) |expected_char| {
            const char = self.consume();
            if (char.isEof()) {
                matches = false;
                break;
            }
            const cp = char.getCodepoint().?;
            const lower_cp: u8 = if (cp <= 0x7F) @intCast(cp) else 0;
            const lower_expected = if (expected_char >= 'A' and expected_char <= 'Z')
                expected_char + 0x20
            else
                expected_char;
            const lower_actual = if (lower_cp >= 'A' and lower_cp <= 'Z')
                lower_cp + 0x20
            else
                lower_cp;

            if (lower_actual != lower_expected) {
                matches = false;
                break;
            }
        }

        self.position = saved_pos;
        self.line = saved_line;
        self.column = saved_col;
        self.last_was_cr = saved_cr;

        return matches;
    }

    /// Consume characters that match a string (case-insensitive).
    /// Returns true if consumed, false if not matched.
    pub fn consumeAsciiCaseInsensitive(self: *InputStream, expected: []const u8) bool {
        if (!self.matchesAsciiCaseInsensitive(expected)) {
            return false;
        }

        // Actually consume
        for (expected) |_| {
            _ = self.consume();
        }

        return true;
    }

    /// Get current position info for error reporting.
    pub fn getPosition(self: *const InputStream) struct { line: u32, column: u32, offset: usize } {
        return .{
            .line = self.line,
            .column = self.column,
            .offset = self.position,
        };
    }

    /// Check if at end of input.
    pub fn isAtEnd(self: *const InputStream) bool {
        return self.position >= self.data.len;
    }

    /// Get remaining bytes count.
    pub fn remaining(self: *const InputStream) usize {
        if (self.position >= self.data.len) return 0;
        return self.data.len - self.position;
    }
};

test "InputStream - basic ASCII" {
    var stream = InputStream.init("hello");

    try std.testing.expect(stream.consume().is('h'));
    try std.testing.expect(stream.consume().is('e'));
    try std.testing.expect(stream.consume().is('l'));
    try std.testing.expect(stream.consume().is('l'));
    try std.testing.expect(stream.consume().is('o'));
    try std.testing.expect(stream.consume().isEof());
}

test "InputStream - newline normalization" {
    // Test CR -> LF
    var stream1 = InputStream.init("a\rb");
    try std.testing.expect(stream1.consume().is('a'));
    try std.testing.expect(stream1.consume().is('\n')); // CR normalized to LF
    try std.testing.expect(stream1.consume().is('b'));

    // Test CRLF -> LF
    var stream2 = InputStream.init("a\r\nb");
    try std.testing.expect(stream2.consume().is('a'));
    try std.testing.expect(stream2.consume().is('\n')); // CRLF normalized to single LF
    try std.testing.expect(stream2.consume().is('b'));

    // Test standalone LF
    var stream3 = InputStream.init("a\nb");
    try std.testing.expect(stream3.consume().is('a'));
    try std.testing.expect(stream3.consume().is('\n'));
    try std.testing.expect(stream3.consume().is('b'));
}

test "InputStream - UTF-8 decoding" {
    // 2-byte sequence (é = U+00E9)
    var stream1 = InputStream.init("\xC3\xA9");
    try std.testing.expectEqual(@as(u21, 0xE9), stream1.consume().getCodepoint().?);

    // 3-byte sequence (€ = U+20AC)
    var stream2 = InputStream.init("\xE2\x82\xAC");
    try std.testing.expectEqual(@as(u21, 0x20AC), stream2.consume().getCodepoint().?);

    // 4-byte sequence (😀 = U+1F600)
    var stream3 = InputStream.init("\xF0\x9F\x98\x80");
    try std.testing.expectEqual(@as(u21, 0x1F600), stream3.consume().getCodepoint().?);
}

test "InputStream - peek" {
    var stream = InputStream.init("abc");

    try std.testing.expect(stream.peek().is('a'));
    try std.testing.expect(stream.peek().is('a')); // Should still be 'a'
    try std.testing.expect(stream.consume().is('a'));
    try std.testing.expect(stream.peek().is('b'));
}

test "InputStream - line/column tracking" {
    var stream = InputStream.init("ab\ncd");

    _ = stream.consume(); // a
    try std.testing.expectEqual(@as(u32, 1), stream.line);
    try std.testing.expectEqual(@as(u32, 2), stream.column);

    _ = stream.consume(); // b
    try std.testing.expectEqual(@as(u32, 1), stream.line);
    try std.testing.expectEqual(@as(u32, 3), stream.column);

    _ = stream.consume(); // \n
    try std.testing.expectEqual(@as(u32, 2), stream.line);
    try std.testing.expectEqual(@as(u32, 1), stream.column);

    _ = stream.consume(); // c
    try std.testing.expectEqual(@as(u32, 2), stream.line);
    try std.testing.expectEqual(@as(u32, 2), stream.column);
}

test "InputStream - matchesAsciiCaseInsensitive" {
    var stream = InputStream.init("DOCTYPE html");

    try std.testing.expect(stream.matchesAsciiCaseInsensitive("doctype"));
    try std.testing.expect(stream.matchesAsciiCaseInsensitive("DOCTYPE"));
    try std.testing.expect(stream.matchesAsciiCaseInsensitive("DocType"));
    try std.testing.expect(!stream.matchesAsciiCaseInsensitive("public"));
}

test "InputCharacter - type checks" {
    const alpha = InputCharacter{ .codepoint = 'A' };
    try std.testing.expect(alpha.isAsciiAlpha());
    try std.testing.expect(alpha.isAsciiUpperAlpha());
    try std.testing.expect(!alpha.isAsciiLowerAlpha());
    try std.testing.expect(alpha.isAsciiAlphanumeric());

    const digit = InputCharacter{ .codepoint = '5' };
    try std.testing.expect(digit.isAsciiDigit());
    try std.testing.expect(!digit.isAsciiAlpha());
    try std.testing.expect(digit.isAsciiAlphanumeric());

    const hex = InputCharacter{ .codepoint = 'f' };
    try std.testing.expect(hex.isAsciiHexDigit());
    try std.testing.expect(hex.isAsciiLowerHexDigit());

    const ws = InputCharacter{ .codepoint = ' ' };
    try std.testing.expect(ws.isHtmlWhitespace());

    const eof: InputCharacter = .eof;
    try std.testing.expect(eof.isEof());
    try std.testing.expect(!eof.isAsciiAlpha());
}
