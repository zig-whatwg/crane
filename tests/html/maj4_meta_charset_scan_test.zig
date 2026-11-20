//! The meta charset scan Chrome, Firefox and Safari run in place of the
//! prescan's byte scan (html_core parser/meta_charset_scan.zig): the HTML
//! tokenizer over the bytes, while only head-ish tags are seen or until 1024
//! characters, and no later meta changes the encoding. Each case mirrors a
//! file of WPT html/syntax/charset/ (or xmldecl/), whose expectation all
//! three browsers meet at wpt.fyi 2358bd4835.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const html_core = @import("html_core");

const scan = html_core.parser.meta_charset_scan;
const sniffing = html_core.parser.encoding_sniffing;

const meta = "<meta charset=\"windows-1251\">";

/// `head`, then newlines until byte `at`, then `tail`: the WPT files put a
/// meta at an exact offset the same way.
fn padded(allocator: std.mem.Allocator, head: []const u8, at: usize, tail: []const u8) ![]u8 {
    std.debug.assert(head.len <= at);
    const bytes = try allocator.alloc(u8, at + tail.len);
    @memcpy(bytes[0..head.len], head);
    @memset(bytes[head.len..at], '\n');
    @memcpy(bytes[at..], tail);
    return bytes;
}

fn nameOf(found: ?sniffing.Encoding) []const u8 {
    return if (found) |e| sniffing.canonicalName(e) else "(none)";
}

/// The scan over `bytes` whole, and fed one byte at a time: both give
/// `expected`.
fn expectScan(bytes: []const u8, expected: ?[]const u8) !void {
    const whole = try scan.prescan(testing.allocator, bytes);
    testing.expectEqualStrings(expected orelse "(none)", nameOf(whole)) catch |err| {
        std.debug.print("scan of {d} bytes: \"{s}\"\n", .{ bytes.len, bytes[0..@min(bytes.len, 120)] });
        return err;
    };
    const scanner = try scan.Scanner.create(testing.allocator);
    defer scanner.destroy();
    var outcome: scan.Outcome = .need_more;
    for (bytes, 0..) |_, i| {
        outcome = try scanner.feed(bytes[i .. i + 1], false);
        if (outcome != .need_more) break;
    }
    if (outcome == .need_more) outcome = try scanner.feed("", true);
    try testing.expectEqualStrings(expected orelse "(none)", nameOf(scan.prescanResult(bytes, outcome)));
}

test "a meta in a script, style or title element's text declares nothing" {
    // in-script.html, in-style.html, in-title.html: mismatch.
    try expectScan("<!DOCTYPE html>\n<head>\n<script>" ++ meta ++ "</script>\n</head>\n<body><p>Test</p>", null);
    try expectScan("<!DOCTYPE html>\n<head>\n<style>" ++ meta ++ "</style>\n</head>\n<body><p>Test</p>", null);
    try expectScan("<!DOCTYPE html>\n<head>\n<title>" ++ meta ++ "</title>\n</head>\n<body><p>Test</p>", null);
    // The text ends at its element's end tag; a meta after it counts.
    try expectScan("<head><script>if (a < b) x()</script>" ++ meta, "windows-1251");
}

test "character references in an attribute value are decoded" {
    // ncr.html: match.
    try expectScan("<!DOCTYPE html>\n<head>\n<meta charset=\"&#119;indows-1251\">\n</head>", "windows-1251");
}

test "the scan goes on past 1024 bytes while only head-ish tags were seen" {
    const a = testing.allocator;
    // after-1kb.html: a meta in the head at byte 1024 - match.
    const after_1kb = try padded(a, "<!DOCTYPE html>\n<head>\n<link rel=\"match\" href=\"r.html\">\n", 1024, meta ++ "\n</head>\n<body>");
    defer a.free(after_1kb);
    try expectScan(after_1kb, "windows-1251");
    // Doctype, comments and text do not end the head section either.
    const long_comment = try padded(a, "<!doctype html><!--", 1100, "-->" ++ meta);
    defer a.free(long_comment);
    try expectScan(long_comment, "windows-1251");
}

test "after a tag not allowed in a head the scan stops at 1024 characters" {
    const a = testing.allocator;
    // after-head-in-1kb.html: </head> early, meta at byte 1023 - match.
    const in_1kb = try padded(a, "<!DOCTYPE html>\n<head>\n<link rel=\"match\" href=\"r.html\">\n</head>\n", 1023, meta ++ "\n<body>");
    defer a.free(in_1kb);
    try expectScan(in_1kb, "windows-1251");
    // after-head-after-1kb.html: </head> at byte 1016, meta at 1024 - mismatch.
    const head = try padded(a, "<!DOCTYPE html>\n<head>\n<link rel=\"mismatch\" href=\"r.html\">\n", 1016, "</head>\n" ++ meta ++ "\n<body>");
    defer a.free(head);
    try expectScan(head, null);
    // after-bogus-after-1kb.html: an unknown tag ends the head section.
    const bogus = try padded(a, "<!DOCTYPE html>\n<head>\n<link rel=\"mismatch\" href=\"r.html\">\n", 1017, "<bogus>" ++ meta ++ "\n</head>");
    defer a.free(bogus);
    try expectScan(bogus, null);
    // after-bogus.html: within the first 1024 - match.
    try expectScan("<!DOCTYPE html>\n<head>\n<bogus>" ++ meta ++ "\n</head>", "windows-1251");
    // in-template-after-1kb.html: template ends it too - mismatch; in-template.html - match.
    const template = try padded(a, "<!DOCTYPE html>\n<head>\n", 1130, "<template>" ++ meta ++ "</template>\n</head>");
    defer a.free(template);
    try expectScan(template, null);
    try expectScan("<!DOCTYPE html>\n<head>\n<template>" ++ meta ++ "</template>\n</head>", "windows-1251");
}

test "the scan does not know foreign content: CDATA is a bogus comment" {
    // in-svg.html: match; in-svg-in-cdata.html: mismatch.
    try expectScan("<!DOCTYPE html>\n<head>\n</head>\n<body>\n<svg>" ++ meta ++ "</svg>", "windows-1251");
    try expectScan("<!DOCTYPE html>\n<head>\n</head>\n<body>\n<svg><![CDATA[" ++ meta ++ "]]></svg>", null);
    // in-object.html: match; in-comment.html: mismatch.
    try expectScan("<!DOCTYPE html>\n<head>\n<object>" ++ meta ++ "</object>\n</head>", "windows-1251");
    try expectScan("<!DOCTYPE html>\n<head>\n<!--" ++ meta ++ "-->\n</head>", null);
}

test "an XML declaration whose > is the 1025th byte still declares the encoding" {
    // xmldecl-2.html kilobyte-plus-one-after.htm: match in all three.
    const a = testing.allocator;
    const decl = try padded(a, "<?xml version=\"1.0\" encoding=\"windows-1251\"", 1023, "?>\n<p>Normal XML decl</p>");
    defer a.free(decl);
    @memset(decl[43..1023], ' ');
    try testing.expectEqual(@as(u8, '>'), decl[1024]);
    try expectScan(decl, "windows-1251");
}

test "the sniffing algorithm: a meta found by the scan is tentative; a BOM or the transport skip it" {
    const a = testing.allocator;
    const found = try scan.sniff(a, "<head><script>x</script>" ++ meta, .{});
    try testing.expectEqualStrings("windows-1251", sniffing.canonicalName(found.encoding));
    try testing.expectEqual(sniffing.Confidence.tentative, found.confidence);
    const none = try scan.sniff(a, "<script>" ++ meta ++ "</script>", .{ .parent = sniffing.lookup("gbk") });
    try testing.expectEqualStrings("GBK", sniffing.canonicalName(none.encoding));
    const transport = try scan.sniff(a, meta, .{ .transport = sniffing.lookup("big5") });
    try testing.expectEqualStrings("Big5", sniffing.canonicalName(transport.encoding));
    try testing.expectEqual(sniffing.Confidence.certain, transport.confidence);
}

test "the end of the bytes inside a tag, a comment or an element's text ends the scan" {
    // The tokenizer emits an end-of-file token in every state but data - and
    // again at each call after it: the scan stops at the first.
    try expectScan("<head><meta char", null);
    try expectScan("<head><script>" ++ meta, null);
    try expectScan("<head><title>" ++ meta, null);
    try expectScan("<head><!--" ++ meta, null);
    try expectScan("<head><meta charset=\"windows-1251", null);
    try expectScan("<!DOCTYPE html", null);
}
