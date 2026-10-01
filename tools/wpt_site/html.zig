//! HTML primitives for the results site: escaping, numbers, paths, URLs,
//! dates. Every byte a page carries goes through one of these, so text from
//! the results (subtest names, failure messages, paths) is never markup.

const std = @import("std");
const Io = std.Io;
const W = *Io.Writer;
pub const Error = Io.Writer.Error;

/// Text or attribute content: `& < > " '` escaped, and C0 controls (which a
/// failure message can carry) shown as their Unicode control pictures
/// (U+2400 + c), so nothing invisible or invalid reaches the document.
/// Tab, newline and carriage return pass through; DEL becomes U+2421.
pub fn text(w: W, s: []const u8) Error!void {
    var start: usize = 0;
    for (s, 0..) |c, i| {
        const rep: ?[]const u8 = switch (c) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '\'' => "&#39;",
            '\t', '\n', '\r' => null,
            0...8, 11, 12, 14...31, 127 => "",
            else => null,
        };
        if (rep) |r| {
            try w.writeAll(s[start..i]);
            if (r.len == 0) {
                const cp: u21 = if (c == 127) 0x2421 else 0x2400 + @as(u21, c);
                var buf: [4]u8 = undefined;
                const n = std.unicode.utf8Encode(cp, &buf) catch unreachable;
                try w.writeAll(buf[0..n]);
            } else try w.writeAll(r);
            start = i + 1;
        }
    }
    try w.writeAll(s[start..]);
}

/// `n` with thousands separators: 1287946 -> "1,287,946".
pub fn num(w: W, n: u64) Error!void {
    var buf: [32]u8 = undefined;
    const digits = std.fmt.bufPrint(&buf, "{d}", .{n}) catch unreachable;
    for (digits, 0..) |d, i| {
        if (i > 0 and (digits.len - i) % 3 == 0) try w.writeByte(',');
        try w.writeByte(d);
    }
}

/// "1 file" / "3 files".
pub fn plural(w: W, n: u64, one: []const u8, many: []const u8) Error!void {
    try num(w, n);
    try w.writeByte(' ');
    try w.writeAll(if (n == 1) one else many);
}

/// A path set in the path face, with a break opportunity after each
/// separator (`_ - . /`), so a narrow column wraps it there and never
/// mid-word.
pub fn path(w: W, s: []const u8) Error!void {
    try w.writeAll("<code>");
    var start: usize = 0;
    for (s, 0..) |c, i| {
        if ((c == '_' or c == '-' or c == '.' or c == '/') and i + 1 < s.len) {
            try text(w, s[start .. i + 1]);
            try w.writeAll("<wbr>");
            start = i + 1;
        }
    }
    try text(w, s[start..]);
    try w.writeAll("</code>");
}

/// A site path as a URL path: every byte outside the unreserved set and `/`
/// percent-encoded, so the result needs no further escaping in an attribute.
pub fn href(w: W, s: []const u8) Error!void {
    for (s) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '.' or c == '_' or c == '~' or c == '/') {
            try w.writeByte(c);
        } else {
            try w.print("%{X:0>2}", .{c});
        }
    }
}

pub const months = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };

pub const Date = struct { y: u32, m: u8, d: u8 };

/// The date of "2026-09-30T11:21:23" (or "...Z", or a bare date).
pub fn parseDate(s: []const u8) ?Date {
    if (s.len < 10 or s[4] != '-' or s[7] != '-') return null;
    const y = std.fmt.parseInt(u32, s[0..4], 10) catch return null;
    const m = std.fmt.parseInt(u8, s[5..7], 10) catch return null;
    const d = std.fmt.parseInt(u8, s[8..10], 10) catch return null;
    if (m < 1 or m > 12 or d < 1 or d > 31) return null;
    return .{ .y = y, .m = m, .d = d };
}

/// "30 September 2026".
pub fn longDate(w: W, s: []const u8) Error!void {
    const dt = parseDate(s) orelse return w.writeAll("an unrecorded date");
    try w.print("{d} {s} {d}", .{ dt.d, months[dt.m - 1], dt.y });
}

/// "30 Sep 2026".
pub fn shortDateY(w: W, s: []const u8) Error!void {
    const dt = parseDate(s) orelse return w.writeAll("an unrecorded date");
    try w.print("{d} {s} {d}", .{ dt.d, months[dt.m - 1][0..3], dt.y });
}

/// "30 Sep".
pub fn shortDate(w: W, s: []const u8) Error!void {
    const dt = parseDate(s) orelse return w.writeAll("?");
    try w.print("{d} {s}", .{ dt.d, months[dt.m - 1][0..3] });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn render(comptime f: anytype, args: anytype) ![]u8 {
    var aw: Io.Writer.Allocating = .init(testing.allocator);
    errdefer aw.deinit();
    try @call(.auto, f, .{&aw.writer} ++ args);
    return aw.toOwnedSlice();
}

test "html: text escapes markup and shows control characters" {
    const got = try render(text, .{"a<b>&\"c'\x00\x1b\t\n\x7f"});
    defer testing.allocator.free(got);
    try testing.expectEqualStrings("a&lt;b&gt;&amp;&quot;c&#39;\u{2400}\u{241b}\t\n\u{2421}", got);
    // UTF-8 passes through untouched.
    const u = try render(text, .{"résumé ✓"});
    defer testing.allocator.free(u);
    try testing.expectEqualStrings("résumé ✓", u);
}

test "html: numbers carry thousands separators" {
    const cases = [_]struct { u64, []const u8 }{
        .{ 0, "0" },          .{ 999, "999" },           .{ 1000, "1,000" },
        .{ 44465, "44,465" }, .{ 1287946, "1,287,946" }, .{ 18446744073709551615, "18,446,744,073,709,551,615" },
    };
    for (cases) |c| {
        const got = try render(num, .{c[0]});
        defer testing.allocator.free(got);
        try testing.expectEqualStrings(c[1], got);
    }
    const p = try render(plural, .{ 1, "file", "files" });
    defer testing.allocator.free(p);
    try testing.expectEqualStrings("1 file", p);
}

test "html: a path breaks only after its separators" {
    const got = try render(path, .{"dom/nodes/Node-cloneNode.html"});
    defer testing.allocator.free(got);
    try testing.expectEqualStrings("<code>dom/<wbr>nodes/<wbr>Node-<wbr>cloneNode.<wbr>html</code>", got);
    const dir = try render(path, .{"xhr/"});
    defer testing.allocator.free(dir);
    try testing.expectEqualStrings("<code>xhr/</code>", dir);
}

test "html: hrefs percent-encode everything but the unreserved set and /" {
    const got = try render(href, .{"html/a b/x?y#z&\"é.html"});
    defer testing.allocator.free(got);
    try testing.expectEqualStrings("html/a%20b/x%3Fy%23z%26%22%C3%A9.html", got);
}

test "html: dates" {
    const a = try render(longDate, .{"2026-09-30T11:21:23"});
    defer testing.allocator.free(a);
    try testing.expectEqualStrings("30 September 2026", a);
    const b = try render(shortDateY, .{"2026-09-19T19:55:00Z"});
    defer testing.allocator.free(b);
    try testing.expectEqualStrings("19 Sep 2026", b);
    const c = try render(shortDate, .{"2026-01-02"});
    defer testing.allocator.free(c);
    try testing.expectEqualStrings("2 Jan", c);
    const d = try render(longDate, .{"garbage"});
    defer testing.allocator.free(d);
    try testing.expectEqualStrings("an unrecorded date", d);
}
