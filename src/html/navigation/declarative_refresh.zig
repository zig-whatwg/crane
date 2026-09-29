//! The engine-free steps of HTML's "shared declarative refresh steps" (§4.2.5.3):
//! parsing a `<meta http-equiv=refresh>` content value, or a `Refresh`
//! header's, into a time and the URL string the document refreshes to.
//!
//! Steps 1 and 11.11-13 (the document's "will declaratively refresh", parsing
//! the URL string relative to the document, refusing javascript:) are the
//! Document's, which owns that state; this module is steps 2-11.10.
//!
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#shared-declarative-refresh-steps

const std = @import("std");

/// A refresh value that parsed.
pub const Parsed = struct {
    /// `time`, in seconds (step 7's non-negative integer; saturating).
    time: u64,
    /// The URL string, a slice of the input, for step 11.11 to parse relative
    /// to the document - or null when the input names none, and urlRecord
    /// stays the document's URL (step 9). An empty string is not null: it
    /// parses to the document's base URL.
    url: ?[]const u8,
};

/// Infra's ASCII whitespace: TAB, LF, FF, CR and SPACE (not VT).
fn isAsciiWhitespace(c: u8) bool {
    return switch (c) {
        '\t', '\n', '\x0c', '\r', ' ' => true,
        else => false,
    };
}

/// A position in the input, as Infra's "collect a sequence of code points"
/// and "skip ASCII whitespace" use it.
const Cursor = struct {
    input: []const u8,
    position: usize = 0,

    fn atEnd(self: *const Cursor) bool {
        return self.position >= self.input.len;
    }

    /// The code point pointed to by position, or null past the end.
    fn current(self: *const Cursor) ?u8 {
        return if (self.atEnd()) null else self.input[self.position];
    }

    fn skipAsciiWhitespace(self: *Cursor) void {
        while (self.current()) |c| {
            if (!isAsciiWhitespace(c)) break;
            self.position += 1;
        }
    }

    /// Advance past the current code point when it is `a` or `b`.
    fn advanceIf(self: *Cursor, a: u8, b: u8) bool {
        const c = self.current() orelse return false;
        if (c != a and c != b) return false;
        self.position += 1;
        return true;
    }
};

/// Steps 2-11.10 of the shared declarative refresh steps given `input`: null
/// wherever the steps "return".
pub fn parse(input: []const u8) ?Parsed {
    // Step 2: "Let position point at the first code point of input."
    var cursor: Cursor = .{ .input = input };
    // Step 3: "Skip ASCII whitespace within input given position."
    cursor.skipAsciiWhitespace();
    // Step 4: "Let time be 0."
    var time: u64 = 0;
    // Step 5: "Collect a sequence of code points that are ASCII digits from
    // input given position, and let timeString be the result."
    const time_start = cursor.position;
    while (cursor.current()) |c| {
        if (!std.ascii.isDigit(c)) break;
        cursor.position += 1;
    }
    const time_string = input[time_start..cursor.position];
    if (time_string.len == 0) {
        // Step 6.1: "If the code point in input pointed to by position is not
        // U+002E (.), then return."
        if (cursor.current() != '.') return null;
    } else {
        // Step 7: "set time to the result of parsing timeString using the
        // rules for parsing non-negative integers" - digits only, so the
        // value is the digits' (saturated at the integer's range).
        for (time_string) |digit| {
            time = std.math.mul(u64, time, 10) catch std.math.maxInt(u64);
            time = std.math.add(u64, time, digit - '0') catch std.math.maxInt(u64);
        }
    }
    // Step 8: "Collect a sequence of code points that are ASCII digits and
    // U+002E FULL STOP characters (.) from input given position. Ignore any
    // collected characters."
    while (cursor.current()) |c| {
        if (!std.ascii.isDigit(c) and c != '.') break;
        cursor.position += 1;
    }
    // Step 9: "Let urlRecord be document's URL" - a null URL string.
    // Step 10: "If position is not past the end of input":
    if (!cursor.atEnd()) {
        // 10.1: "If the code point in input pointed to by position is not
        // U+003B (;), U+002C (,), or ASCII whitespace, then return."
        const c = cursor.current().?;
        if (c != ';' and c != ',' and !isAsciiWhitespace(c)) return null;
        // 10.2: "Skip ASCII whitespace within input given position."
        cursor.skipAsciiWhitespace();
        // 10.3: "If the code point in input pointed to by position is U+003B
        // (;) or U+002C (,), then advance position to the next code point."
        _ = cursor.advanceIf(';', ',');
        // 10.4: "Skip ASCII whitespace within input given position."
        cursor.skipAsciiWhitespace();
    }
    // Step 11: "If position is not past the end of input":
    if (cursor.atEnd()) return .{ .time = time, .url = null };
    // 11.1: "Let urlString be the substring of input from the code point at
    // position to the end of the string."
    var url_string = input[cursor.position..];
    skip_quotes: {
        parse_url: {
            // 11.2: "If the code point in input pointed to by position is
            // U+0055 (U) or U+0075 (u), then advance position to the next code
            // point. Otherwise, jump to the step labeled skip quotes."
            if (!cursor.advanceIf('U', 'u')) break :parse_url;
            // 11.3-11.4: "R" then "L", or jump to the step labeled parse.
            if (!cursor.advanceIf('R', 'r')) break :skip_quotes;
            if (!cursor.advanceIf('L', 'l')) break :skip_quotes;
            // 11.5: "Skip ASCII whitespace within input given position."
            cursor.skipAsciiWhitespace();
            // 11.6: "If the code point in input pointed to by position is
            // U+003D (=), then advance position to the next code point.
            // Otherwise, jump to the step labeled parse."
            if (!cursor.advanceIf('=', '=')) break :skip_quotes;
            // 11.7: "Skip ASCII whitespace within input given position."
            cursor.skipAsciiWhitespace();
        }
        // 11.8: "Skip quotes: If the code point in input pointed to by
        // position is U+0027 (') or U+0022 ("), then let quote be that code
        // point, and advance position to the next code point. Otherwise, let
        // quote be the empty string."
        const quote: ?u8 = if (cursor.current()) |c| (if (c == '\'' or c == '"') c else null) else null;
        if (quote != null) cursor.position += 1;
        // 11.9: "Set urlString to the substring of input from the code point
        // at position to the end of the string."
        url_string = input[cursor.position..];
        // 11.10: "If quote is not the empty string, and there is a code point
        // in urlString equal to quote, then truncate urlString at that code
        // point, so that it and all subsequent code points are removed."
        if (quote) |q| {
            if (std.mem.indexOfScalar(u8, url_string, q)) |end| url_string = url_string[0..end];
        }
    }
    // 11.11 "Parse" onwards is the document's.
    return .{ .time = time, .url = url_string };
}
