//! HTML "shared declarative refresh steps" 2-11.10, as `declarative_refresh`
//! parses a `<meta http-equiv=refresh>` content value or a `Refresh` header.
//! The cases are the table of WPT's
//! html/semantics/document-metadata/the-meta-element/pragma-directives/
//! attr-meta-http-equiv-refresh/parsing.html; the URL string is the one the
//! steps hand to the URL parser, before it strips tabs, newlines and
//! surrounding spaces.
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#shared-declarative-refresh-steps

const std = @import("std");
const testing = std.testing;
const refresh = @import("html_core").navigation.declarative_refresh;

/// `input` parses to `time` seconds and, when `url` is non-null, that URL
/// string; a null `url` is the document's own URL (step 9).
fn expectRefresh(input: []const u8, time: u64, url: ?[]const u8) !void {
    const parsed = refresh.parse(input) orelse {
        std.debug.print("\"{s}\" did not parse\n", .{input});
        return error.TestExpectedParse;
    };
    try testing.expectEqual(time, parsed.time);
    if (url) |expected| {
        const got = parsed.url orelse {
            std.debug.print("\"{s}\" has no URL string, expected \"{s}\"\n", .{ input, expected });
            return error.TestExpectedUrl;
        };
        try testing.expectEqualStrings(expected, got);
    } else if (parsed.url) |got| {
        std.debug.print("\"{s}\" has URL string \"{s}\", expected the document's URL\n", .{ input, got });
        return error.TestUnexpectedUrl;
    }
}

fn expectNoRefresh(input: []const u8) !void {
    if (refresh.parse(input)) |parsed| {
        std.debug.print("\"{s}\" parsed to {d}, {?s}\n", .{ input, parsed.time, parsed.url });
        return error.TestExpectedNoParse;
    }
}

test "a bare number refreshes to the document's own URL" {
    try expectRefresh("1", 1, null);
    try expectRefresh("0", 0, null);
    try expectRefresh("300", 300, null);
    // Step 10: a separator or ASCII whitespace may follow, and nothing else.
    try expectRefresh("1 ", 1, null);
    try expectRefresh("1\t", 1, null);
    try expectRefresh("1\r", 1, null);
    try expectRefresh("1\n", 1, null);
    try expectRefresh("1\x0c", 1, null);
    try expectRefresh("1;", 1, null);
    try expectRefresh("1,", 1, null);
}

test "a number, a separator and url= gives the URL string" {
    try expectRefresh("1; url=foo", 1, "foo");
    try expectRefresh("1, url=foo", 1, "foo");
    try expectRefresh("1 url=foo", 1, "foo");
    try expectRefresh("0; url=foo", 0, "foo");
    for ([_][]const u8{ "\t", "\r", "\n", "\x0c" }) |ws| {
        var buf: [32]u8 = undefined;
        try expectRefresh(try std.fmt.bufPrint(&buf, "1;{s}url=foo", .{ws}), 1, "foo");
        try expectRefresh(try std.fmt.bufPrint(&buf, "1,{s}url=foo", .{ws}), 1, "foo");
        try expectRefresh(try std.fmt.bufPrint(&buf, "1{s}url=foo", .{ws}), 1, "foo");
    }
    // "URL" is matched ASCII case-insensitively.
    try expectRefresh("1; URL=foo", 1, "foo");
    try expectRefresh("1; UrL=foo", 1, "foo");
}

test "whitespace around the time, the separator, url and = is skipped" {
    try expectRefresh("  1  ;  url  =  foo", 1, "foo");
    try expectRefresh("  1  ,  url  =  foo", 1, "foo");
    try expectRefresh("  1  url  =  foo", 1, "foo");
    // A URL string without url= is the rest of the input.
    try expectRefresh("  1  ;  foo", 1, "foo");
    try expectRefresh("  1  ,  foo", 1, "foo");
    try expectRefresh("0; foo", 0, "foo");
    // Trailing whitespace and embedded tabs and newlines are the URL
    // parser's to strip.
    try expectRefresh("1; url=foo ", 1, "foo ");
    try expectRefresh("1; url=f\to\no", 1, "f\to\no");
}

test "a quoted URL ends at its closing quote" {
    try expectRefresh("1; url=\"foo\"bar", 1, "foo");
    try expectRefresh("1; url='foo'bar", 1, "foo");
    // Without its own closing quote, the other quote is part of the URL.
    try expectRefresh("1; url=\"foo'bar", 1, "foo'bar");
    // A quote may open the URL string without url=.
    try expectRefresh("1; \"foo\"bar", 1, "foo");
    // An unclosed quote runs to the end.
    try expectRefresh("1; url='foo", 1, "foo");
}

test "a partial url= keyword is the start of the URL string" {
    try expectRefresh("1; url foo", 1, "url foo");
    try expectRefresh("1; urlfoo", 1, "urlfoo");
    try expectRefresh("1; urfoo", 1, "urfoo");
    try expectRefresh("1; ufoo", 1, "ufoo");
    try expectRefresh("1 x;url=foo", 1, "x;url=foo");
    // Only one separator is skipped.
    try expectRefresh("1;;url=foo", 1, ";url=foo");
    // url= with nothing after it: the empty string, parsed against the
    // document - not the document's URL.
    try expectRefresh("1; url=", 1, "");
}

test "fractions are read and ignored" {
    try expectRefresh("1.9; url=foo", 1, "foo");
    try expectRefresh("1.9..5.; url=foo", 1, "foo");
    try expectRefresh(".9; url=foo", 0, "foo");
    try expectRefresh("0.9; url=foo", 0, "foo");
    try expectRefresh("0...9; url=foo", 0, "foo");
    try expectRefresh("0...; url=foo", 0, "foo");
}

test "anything else is no refresh" {
    try expectNoRefresh("");
    try expectNoRefresh("   ");
    try expectNoRefresh("1url=foo");
    try expectNoRefresh("1x;url=foo");
    try expectNoRefresh("; foo");
    try expectNoRefresh(";foo");
    try expectNoRefresh(", foo");
    try expectNoRefresh(",foo");
    try expectNoRefresh("foo");
    // Signs are not digits.
    for ([_][]const u8{ "+1", "-1", "+0", "-0" }) |time| {
        var buf: [32]u8 = undefined;
        try expectNoRefresh(time);
        try expectNoRefresh(try std.fmt.bufPrint(&buf, "{s}; url=foo", .{time}));
        try expectNoRefresh(try std.fmt.bufPrint(&buf, "{s}; foo", .{time}));
    }
    // Exponents are not.
    try expectNoRefresh("1e0; url=foo");
    try expectNoRefresh("1e1; url=foo");
    try expectNoRefresh("10e-1; url=foo");
    try expectNoRefresh("-0.1; url=foo");
}

test "a time too large for the integer saturates" {
    try expectRefresh("99999999999999999999999999; url=foo", std.math.maxInt(u64), "foo");
}
