//! The exclusion lists: tools/fw_matrix/excluded/<framework>-<version>.txt,
//! one entry per test (or file) of a framework that Crane's matrix does not
//! run, each with its reason, in tools/wpt_gate_exemptions.txt's format:
//!
//!     [<id>]
//!     kind      = rendering | needs-server | needs-node-build | node-runner-only
//!     why       = <why it is not run>
//!     assertion = <the assertion that needs layout>   (rendering: required)
//!     source    = <file:line of the test's definition>
//!
//! `<id>` is the name the framework's own filter matches: QUnit
//! "<module>: <test name>" (QUnit's `fullName` in Test.valid), Mocha the
//! test's full title (Runnable#fullTitle: its suites' titles and its own,
//! joined by spaces). A `node-runner-only` entry names a FILE of the
//! project's tests, `[file:<path>]`, that its browser page does not load.
//!
//! The list becomes the framework's OWN filter, so excluded tests are never
//! run (the plan's section 3.2): QUnit 2's negated regex filter
//! `?filter=!/^(?:...)$/` (qunit.js Test.valid -> regexFilter), Mocha's
//! `?grep=^(?:...)$&invert=true` (mocha.js browser-entry run -> grep,
//! invert). An entry that names no test of the page fails the run loudly
//! (`missing`): an upstream rename must never turn an exclusion into a
//! silent no-op.

const std = @import("std");
const Allocator = std.mem.Allocator;
const journal = @import("journal.zig");

pub const Kind = enum {
    rendering,
    needs_server,
    needs_node_build,
    node_runner_only,

    pub fn notRun(k: Kind) journal.NotRun {
        return switch (k) {
            .rendering => .rendering,
            .needs_server => .needs_server,
            .needs_node_build => .needs_node_build,
            .node_runner_only => .node_runner_only,
        };
    }

    fn parse(s: []const u8) ?Kind {
        const names = [_]struct { []const u8, Kind }{
            .{ "rendering", .rendering },
            .{ "needs-server", .needs_server },
            .{ "needs-node-build", .needs_node_build },
            .{ "node-runner-only", .node_runner_only },
        };
        for (names) |n| if (std.mem.eql(u8, s, n[0])) return n[1];
        return null;
    }
};

pub const Entry = struct {
    /// The test's id, or for a file entry its path below the source tree.
    id: []const u8,
    file: bool = false,
    kind: Kind,
    why: []const u8,
    assertion: ?[]const u8 = null,
    source: ?[]const u8 = null,
    /// 1-based line of the `[...]` header, for messages.
    line: usize,
};

pub const ParseError = error{ OutOfMemory, EntryOutsideBlock, UnknownKey, UnknownKind, MissingKind, MissingWhy, MissingAssertion, DuplicateEntry, BadLine, FileEntryNotNodeRunnerOnly };

pub const ParseFailure = struct {
    line: usize = 0,
};

/// Every entry of a list. `#` lines and blank lines are comments.
pub fn parse(arena: Allocator, text: []const u8, failure: *ParseFailure) ParseError![]Entry {
    var entries: std.ArrayList(Entry) = .empty;
    var it = std.mem.splitScalar(u8, text, '\n');
    var n: usize = 0;
    var current: ?Entry = null;
    var kind_seen = false;
    while (it.next()) |raw| {
        n += 1;
        failure.line = n;
        const line = std.mem.trimEnd(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        if (line[0] == '[') {
            if (line[line.len - 1] != ']') return error.BadLine;
            if (current) |c| try finish(arena, &entries, c, kind_seen, failure);
            const inner = line[1 .. line.len - 1];
            const is_file = std.mem.startsWith(u8, inner, "file:");
            current = .{ .id = if (is_file) inner["file:".len..] else inner, .file = is_file, .kind = .rendering, .why = "", .line = n };
            kind_seen = false;
            continue;
        }
        if (current == null) return error.EntryOutsideBlock;
        const c = &current.?;
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse return error.BadLine;
        const key = std.mem.trim(u8, line[0..eq], " \t");
        const value = std.mem.trim(u8, line[eq + 1 ..], " \t");
        if (std.mem.eql(u8, key, "kind")) {
            c.kind = Kind.parse(value) orelse return error.UnknownKind;
            kind_seen = true;
        } else if (std.mem.eql(u8, key, "why")) {
            c.why = value;
        } else if (std.mem.eql(u8, key, "assertion")) {
            c.assertion = value;
        } else if (std.mem.eql(u8, key, "source")) {
            c.source = value;
        } else return error.UnknownKey;
    }
    if (current) |c| try finish(arena, &entries, c, kind_seen, failure);
    return entries.items;
}

fn finish(arena: Allocator, entries: *std.ArrayList(Entry), e: Entry, kind_seen: bool, failure: *ParseFailure) ParseError!void {
    failure.line = e.line;
    if (!kind_seen) return error.MissingKind;
    if (e.why.len == 0) return error.MissingWhy;
    if (e.kind == .rendering and (e.assertion == null or e.assertion.?.len == 0)) return error.MissingAssertion;
    if (e.file != (e.kind == .node_runner_only)) return error.FileEntryNotNodeRunnerOnly;
    for (entries.items) |o| if (o.file == e.file and std.mem.eql(u8, o.id, e.id)) return error.DuplicateEntry;
    try entries.append(arena, e);
}

/// The QUnit module of an id ("<module>: <name>"), or null.
pub fn qunitModule(id: []const u8) ?[]const u8 {
    const sep = std.mem.indexOf(u8, id, ": ") orelse return null;
    return id[0..sep];
}

/// The entries one page excludes: a QUnit module page those whose module is
/// the page's (QUnit compares module names lower-cased: Test.valid's
/// moduleChainNameMatch), a page without a module every test entry.
pub fn forPage(arena: Allocator, entries: []const Entry, module: ?[]const u8, kinds: []const Kind) ![]const Entry {
    var out: std.ArrayList(Entry) = .empty;
    for (entries) |e| {
        if (e.file) continue;
        if (std.mem.indexOfScalar(Kind, kinds, e.kind) == null) continue;
        if (module) |m| {
            const em = qunitModule(e.id) orelse continue;
            if (!std.ascii.eqlIgnoreCase(em, m)) continue;
        }
        try out.append(arena, e);
    }
    return out.items;
}

/// `s` with every character a JavaScript RegExp gives a meaning escaped
/// (ECMAScript SyntaxCharacter, and `/`, which QUnit's filter delimits with).
pub fn escapeRegex(w: *std.Io.Writer, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '\\', '^', '$', '.', '*', '+', '?', '(', ')', '[', ']', '{', '}', '|', '/' => try w.writeByte('\\'),
            else => {},
        }
        try w.writeByte(c);
    }
}

/// `^(?:<id>|<id>...)$`: matches exactly the ids given.
pub fn alternation(arena: Allocator, entries: []const Entry) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    try out.writer.writeAll("^(?:");
    for (entries, 0..) |e, i| {
        if (i > 0) try out.writer.writeByte('|');
        try escapeRegex(&out.writer, e.id);
    }
    try out.writer.writeAll(")$");
    return out.written();
}

/// encodeURIComponent's encoding, keeping only A-Z a-z 0-9 - _ . ~ as they
/// are (both readers decode with decodeURIComponent after turning `+` into a
/// space: qunit.js decodeQueryParam, mocha.js parseQuery).
pub fn percentEncode(w: *std.Io.Writer, s: []const u8) !void {
    for (s) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
            try w.writeByte(c);
        } else try w.print("%{X:0>2}", .{c});
    }
}

pub const Reader = enum { qunit, mocha };

/// The query parameters that make the framework skip `entries` itself
/// (empty when there are none): QUnit `filter=!/^(?:...)$/`, Mocha
/// `grep=^(?:...)$&invert=true`.
pub fn filterQuery(arena: Allocator, reader: Reader, entries: []const Entry) ![]const u8 {
    if (entries.len == 0) return "";
    const re = try alternation(arena, entries);
    var out: std.Io.Writer.Allocating = .init(arena);
    switch (reader) {
        .qunit => {
            try out.writer.writeAll("filter=");
            const f = try std.fmt.allocPrint(arena, "!/{s}/", .{re});
            try percentEncode(&out.writer, f);
        },
        .mocha => {
            try out.writer.writeAll("grep=");
            try percentEncode(&out.writer, re);
            try out.writer.writeAll("&invert=true");
        },
    }
    return out.written();
}

/// `path` with `query` added (`?` or `&` as the path already has one).
pub fn withQuery(arena: Allocator, path: []const u8, query: []const u8) ![]const u8 {
    if (query.len == 0) return path;
    const sep: u8 = if (std.mem.indexOfScalar(u8, path, '?') == null) '?' else '&';
    return std.fmt.allocPrint(arena, "{s}{c}{s}", .{ path, sep, query });
}

/// The entries that name no test the page defines (`defined`: every test id
/// the framework registered, run or not). Non-empty fails the run.
pub fn missing(arena: Allocator, entries: []const Entry, defined: []const []const u8) ![]const Entry {
    var set: std.StringHashMapUnmanaged(void) = .empty;
    for (defined) |d| try set.put(arena, d, {});
    var out: std.ArrayList(Entry) = .empty;
    for (entries) |e| if (!set.contains(e.id)) try out.append(arena, e);
    return out.items;
}

const testing = std.testing;

const sample =
    \\# jQuery 4.0.0
    \\
    \\[offset: offset(Object)]
    \\kind      = rendering
    \\why       = asserts .offset(), getBoundingClientRect: a layout box
    \\assertion = offset().top: expected 1, got 0
    \\source    = test/unit/offset.js:120
    \\
    \\[ajax: jQuery.ajax() - success callbacks]
    \\kind = needs-server
    \\why  = requests data/mock.php?action=...
    \\
    \\[file:test/tests/unit/logger.js]
    \\kind = node-runner-only
    \\why  = test.html does not load it
    \\
;

test "parse: entries, kinds, file entries; comments skipped" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    var f: ParseFailure = .{};
    const entries = try parse(arena_state.allocator(), sample, &f);
    try testing.expectEqual(@as(usize, 3), entries.len);
    try testing.expectEqualStrings("offset: offset(Object)", entries[0].id);
    try testing.expectEqual(Kind.rendering, entries[0].kind);
    try testing.expectEqualStrings("test/unit/offset.js:120", entries[0].source.?);
    try testing.expectEqual(Kind.needs_server, entries[1].kind);
    try testing.expect(entries[2].file);
    try testing.expectEqualStrings("test/tests/unit/logger.js", entries[2].id);
    try testing.expectEqual(@as(usize, 13), entries[2].line);
}

test "parse refuses what would exclude without a reason" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var f: ParseFailure = .{};
    try testing.expectError(error.MissingAssertion, parse(a, "[m: t]\nkind = rendering\nwhy = w\n", &f));
    try testing.expectError(error.MissingWhy, parse(a, "[m: t]\nkind = needs-server\n", &f));
    try testing.expectError(error.MissingKind, parse(a, "[m: t]\nwhy = w\n", &f));
    try testing.expectError(error.UnknownKind, parse(a, "[m: t]\nkind = slow\n", &f));
    try testing.expectError(error.UnknownKey, parse(a, "[m: t]\nkind = needs-server\nwhy = w\nnote = x\n", &f));
    try testing.expectError(error.EntryOutsideBlock, parse(a, "kind = rendering\n", &f));
    try testing.expectError(error.DuplicateEntry, parse(a, "[m: t]\nkind = needs-server\nwhy = w\n[m: t]\nkind = needs-server\nwhy = w\n", &f));
    try testing.expectEqual(@as(usize, 4), f.line);
    try testing.expectError(error.FileEntryNotNodeRunnerOnly, parse(a, "[file:x.js]\nkind = needs-server\nwhy = w\n", &f));
    try testing.expectError(error.FileEntryNotNodeRunnerOnly, parse(a, "[m: t]\nkind = node-runner-only\nwhy = w\n", &f));
}

test "names with regex and URL characters survive both filters exactly" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const entries = [_]Entry{
        .{ .id = "css: css(String|Hash) [gh-1] a/b?", .kind = .rendering, .why = "w", .assertion = "x", .line = 1 },
        .{ .id = "css: 100% & +1", .kind = .needs_server, .why = "w", .line = 2 },
    };
    try testing.expectEqualStrings("^(?:css: css\\(String\\|Hash\\) \\[gh-1\\] a\\/b\\?|css: 100% & \\+1)$", try alternation(a, &entries));
    const q = try filterQuery(a, .qunit, &entries);
    try testing.expectEqualStrings(
        "filter=%21%2F%5E%28%3F%3Acss%3A%20css%5C%28String%5C%7CHash%5C%29%20%5C%5Bgh-1%5C%5D%20a%5C%2Fb%5C%3F%7Ccss%3A%20100%25%20%26%20%5C%2B1%29%24%2F",
        q,
    );
    const m = try filterQuery(a, .mocha, entries[1..]);
    try testing.expectEqualStrings("grep=%5E%28%3F%3Acss%3A%20100%25%20%26%20%5C%2B1%29%24&invert=true", m);
    try testing.expectEqualStrings("test/index.html?module=css&x=1", try withQuery(a, "test/index.html?module=css", "x=1"));
    try testing.expectEqualStrings("test/test.html?x=1", try withQuery(a, "test/test.html", "x=1"));
    try testing.expectEqualStrings("t.html", try withQuery(a, "t.html", ""));
}

test "the escaped alternation, compiled as a regex, matches exactly its ids" {
    // A check that does not go through escapeRegex: undo the escaping by
    // hand and compare with the ids (a backslash always precedes exactly one
    // escaped character).
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const ids = [_][]const u8{ "a.b*c", "x\\y", "(p)|[q]{r}^$" };
    for (ids) |id| {
        var out: std.Io.Writer.Allocating = .init(a);
        try escapeRegex(&out.writer, id);
        const esc = out.written();
        var undone: std.ArrayList(u8) = .empty;
        var i: usize = 0;
        while (i < esc.len) : (i += 1) {
            if (esc[i] == '\\') {
                i += 1;
                try testing.expect(std.mem.indexOfScalar(u8, "\\^$.*+?()[]{}|/", esc[i]) != null);
            } else try testing.expect(std.mem.indexOfScalar(u8, "\\^$.*+?()[]{}|/", esc[i]) == null);
            try undone.append(a, esc[i]);
        }
        try testing.expectEqualStrings(id, undone.items);
    }
}

test "forPage: a module page takes its module's entries, case-insensitively; kinds switch entries off" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var f: ParseFailure = .{};
    const entries = try parse(a, sample, &f);
    const all_kinds = [_]Kind{ .rendering, .needs_server, .needs_node_build };
    try testing.expectEqual(@as(usize, 1), (try forPage(a, entries, "Offset", &all_kinds)).len);
    try testing.expectEqual(@as(usize, 1), (try forPage(a, entries, "ajax", &all_kinds)).len);
    try testing.expectEqual(@as(usize, 0), (try forPage(a, entries, "ajax", &.{.rendering})).len);
    try testing.expectEqual(@as(usize, 2), (try forPage(a, entries, null, &all_kinds)).len);
}

test "missing: an entry no defined test has is reported" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var f: ParseFailure = .{};
    const entries = try parse(a, sample, &f);
    const defined = [_][]const u8{ "offset: offset(Object)", "offset: other" };
    const m = try missing(a, entries[0..2], &defined);
    try testing.expectEqual(@as(usize, 1), m.len);
    try testing.expectEqualStrings("ajax: jQuery.ajax() - success callbacks", m[0].id);
}
