//! A navigation's document is decoded with the encoding the browsers' meta
//! scan decides before parsing: a meta the scan does not reach - after the
//! head section and the first 1024 characters, or in a script's text - does
//! not change it, and a character reference in the label is decoded. Each
//! case is a file of WPT html/syntax/charset/ whose expectation Chrome,
//! Firefox and Safari meet at wpt.fyi 2358bd4835 (after-head-after-1kb.html,
//! in-script.html: mismatch; ncr.html: match).
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const meta = "<meta charset=\"windows-1251\">";

/// `head`, then newlines until byte `at`, then `tail`.
fn padded(allocator: std.mem.Allocator, head: []const u8, at: usize, tail: []const u8) ![]u8 {
    std.debug.assert(head.len <= at);
    const bytes = try allocator.alloc(u8, at + tail.len);
    @memcpy(bytes[0..head.len], head);
    @memset(bytes[head.len..at], '\n');
    @memcpy(bytes[at..], tail);
    return bytes;
}

fn parsedCharacterSet(bytes: []const u8) ![]u8 {
    interfaces.process_hooks.startHooksForTest();
    const allocator = testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try html.scripted_parser.parseHTMLWithScripting(allocator, &ctx, bytes, .{ .byte_stream = .{ .content_type = "text/html" } });
    defer interfaces.Document.deinit(document);
    var name = try interfaces.Document.get_characterSet(document);
    defer name.deinit(allocator);
    return allocator.dupe(u8, name.asSlice());
}

test "a navigation's document keeps the scan's encoding when a later meta declares another" {
    const a = testing.allocator;
    // after-head-after-1kb.html as a document: windows-1252, the default.
    const late = try padded(a, "<!DOCTYPE html>\n<head>\n<link rel=\"mismatch\" href=\"r.html\">\n", 1016, "</head>\n" ++ meta ++ "\n<body><p>Test: \xE6</p>");
    defer a.free(late);
    const late_name = try parsedCharacterSet(late);
    defer a.free(late_name);
    try testing.expectEqualStrings("windows-1252", late_name);
}

test "a meta in a script's text does not declare the document's encoding" {
    const a = testing.allocator;
    // in-script.html as a document.
    const in_script = try parsedCharacterSet("<!DOCTYPE html>\n<head>\n<script>" ++ meta ++ "</script>\n</head>\n<body><p>Test: \xE6</p>");
    defer a.free(in_script);
    try testing.expectEqualStrings("windows-1252", in_script);
}

test "a character reference in a meta's label is decoded" {
    const a = testing.allocator;
    // ncr.html as a document.
    const ncr = try parsedCharacterSet("<!DOCTYPE html>\n<head>\n<meta charset=\"&#119;indows-1251\">\n</head>\n<body><p>Test: \xE6</p>");
    defer a.free(ncr);
    try testing.expectEqualStrings("windows-1251", ncr);
}
