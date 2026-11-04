//! Run-time test selection (`--filter=PATTERN`, build.zig's -Dtest-filter).
//!
//! A pattern is matched against a test's WHOLE name, and `*` matches any run
//! of characters, none included; every other character is itself. A test's
//! name starts with its file's path under its directory, so one pattern
//! covers a file and a test: `mutation_test*` is every test of
//! tests/dom/mutation_test.zig, `mutation_test.test.removes*` some of them,
//! `*removes*` every test whose name holds "removes", and a full name exactly
//! one test. Several patterns select a test when any of them matches.
//!
//! In an executable that holds several suites (build.zig's
//! -Dtest-binaries=v8), names carry their directory first
//! ("dom.mutation_test.test.x"); a pattern there also matches the name
//! without its suite's prefix (`--group`), so the same pattern selects the
//! same tests in either layout.
//!
//! Selection is at run time, so it never changes a test executable: the
//! build's cache keeps every compile, and only the launcher's runs differ.

const std = @import("std");

/// The patterns of one run; none selects every test.
pub const Filter = struct {
    patterns: []const []const u8 = &.{},

    pub fn active(f: Filter) bool {
        return f.patterns.len != 0;
    }

    /// Whether the test `name` is selected. `prefix`: the name's suite
    /// prefix in an executable of several suites (its `--group`), or null.
    pub fn selects(f: Filter, name: []const u8, prefix: ?[]const u8) bool {
        if (f.patterns.len == 0) return true;
        const own: ?[]const u8 = if (prefix) |p|
            (if (p.len != 0 and std.mem.startsWith(u8, name, p)) name[p.len..] else null)
        else
            null;
        for (f.patterns) |pattern| {
            if (glob(pattern, name)) return true;
            if (own) |o| if (glob(pattern, o)) return true;
        }
        return false;
    }

    /// The patterns as the summary line names them: "a*, b*".
    pub fn format(f: Filter, w: *std.Io.Writer) std.Io.Writer.Error!void {
        for (f.patterns, 0..) |p, i| {
            if (i != 0) try w.writeAll(", ");
            try w.writeAll(p);
        }
    }

    /// What a filtered run says beside its counts: how many of the
    /// executable's tests the patterns took, or that none matched and
    /// nothing ran (the suite passes).
    pub fn writeNote(f: Filter, w: *std.Io.Writer, matched: usize, total: usize) std.Io.Writer.Error!void {
        if (matched == 0) {
            try w.print("filter {f}: no test of {d} matches, nothing run", .{ f, total });
        } else {
            try w.print("filter {f}: {d} of {d} tests", .{ f, matched, total });
        }
    }
};

/// Whether `pattern` matches all of `text`: `*` is any run of characters
/// (none included), everything else matches itself. Iterative, with one
/// backtrack point - the last `*` - so it is linear in practice and never
/// recursive.
pub fn glob(pattern: []const u8, text: []const u8) bool {
    var p: usize = 0;
    var t: usize = 0;
    // The last `*` seen, and the text position it is matched up to.
    var star: ?usize = null;
    var star_t: usize = 0;
    while (t < text.len) {
        if (p < pattern.len and pattern[p] == '*') {
            star = p;
            star_t = t;
            p += 1;
        } else if (p < pattern.len and pattern[p] == text[t]) {
            p += 1;
            t += 1;
        } else if (star) |s| {
            // Let the last `*` take one more character, and retry after it.
            p = s + 1;
            star_t += 1;
            t = star_t;
        } else return false;
    }
    while (p < pattern.len and pattern[p] == '*') p += 1;
    return p == pattern.len;
}

const testing = std.testing;

test "glob: a pattern is the whole name; * is any run of characters" {
    // A full name is exactly that test.
    try testing.expect(glob("mutation_test.test.removes a child", "mutation_test.test.removes a child"));
    try testing.expect(!glob("mutation_test.test.removes a child", "mutation_test.test.removes a child twice"));
    // No star: not a substring and not a prefix.
    try testing.expect(!glob("mutation_test", "mutation_test.test.removes a child"));
    try testing.expect(!glob("removes", "mutation_test.test.removes a child"));
    // A file: its stem and a star.
    try testing.expect(glob("mutation_test*", "mutation_test.test.removes a child"));
    try testing.expect(glob("mutation_test.test.*", "mutation_test.test.removes a child"));
    // Anchored at the start: another file whose name ends the same is not it.
    try testing.expect(!glob("mutation_test*", "dom_mutation_test.test.x"));
    // Stars anywhere, none or many.
    try testing.expect(glob("*removes*", "mutation_test.test.removes a child"));
    try testing.expect(glob("*child", "mutation_test.test.removes a child"));
    try testing.expect(!glob("*child", "mutation_test.test.removes a child twice"));
    try testing.expect(glob("*", "anything"));
    try testing.expect(glob("*", ""));
    try testing.expect(glob("**", "x"));
    try testing.expect(glob("a*", "a"));
    try testing.expect(!glob("", "a"));
    try testing.expect(glob("", ""));
    try testing.expect(glob("a*b*c", "aXXbYYc"));
    try testing.expect(!glob("a*b*c", "aXXcYYb"));
    // Backtracking: the first place a star could stop is not always right.
    try testing.expect(glob("*ab", "aab"));
    try testing.expect(glob("a*ab", "aaab"));
    try testing.expect(glob("*a*b", "xaxxab"));
    try testing.expect(!glob("*a*b", "xaxxa"));
    // Other characters are themselves: no ?, no classes, dots are dots.
    try testing.expect(!glob("mutation?test*", "mutation_test.test.x"));
    try testing.expect(glob("sub.b_test.test.*", "sub.b_test.test.x"));
    try testing.expect(!glob("sub.b_test.test.*", "subXb_test.test.x"));
}

test "filter: no pattern selects every test; several select a test when any matches" {
    const none: Filter = .{};
    try testing.expect(!none.active());
    try testing.expect(none.selects("anything.test.x", null));
    const two: Filter = .{ .patterns = &.{ "mutation_test*", "*range*" } };
    try testing.expect(two.active());
    try testing.expect(two.selects("mutation_test.test.removes", null));
    try testing.expect(two.selects("range_test.test.collapse", null));
    try testing.expect(two.selects("node_test.test.a range of nodes", null));
    try testing.expect(!two.selects("node_test.test.clone", null));
}

test "filter: in an executable of several suites a pattern also matches the name without its suite's prefix" {
    const f: Filter = .{ .patterns = &.{"mutation_test*"} };
    // -Dtest-binaries=v8: "dom." first; the dirs layout's pattern still selects it.
    try testing.expect(f.selects("dom.mutation_test.test.removes", "dom."));
    try testing.expect(!f.selects("html.parser_test.test.x", "html."));
    // The full name works too.
    const full: Filter = .{ .patterns = &.{"dom.mutation_test*"} };
    try testing.expect(full.selects("dom.mutation_test.test.removes", "dom."));
    try testing.expect(!full.selects("mutation_test.test.removes", null));
    // A whole suite of the joined executable.
    const suite: Filter = .{ .patterns = &.{"html.*"} };
    try testing.expect(suite.selects("html.parser_test.test.x", "html."));
    try testing.expect(!suite.selects("dom.mutation_test.test.removes", "dom."));
    // A prefix the name does not start with is not stripped.
    try testing.expect(!f.selects("html.mutation_test.test.x", "dom."));
    // An empty prefix (a test in no group) strips nothing.
    try testing.expect(!f.selects("dom.mutation_test.test.removes", ""));
}

test "filter: the summary note says how many tests matched, or that nothing ran" {
    var buf: [256]u8 = undefined;
    const f: Filter = .{ .patterns = &.{ "mutation_test*", "*range*" } };
    var w: std.Io.Writer = .fixed(&buf);
    try f.writeNote(&w, 12, 642);
    try testing.expectEqualStrings("filter mutation_test*, *range*: 12 of 642 tests", w.buffered());
    w = .fixed(&buf);
    try f.writeNote(&w, 0, 310);
    try testing.expectEqualStrings("filter mutation_test*, *range*: no test of 310 matches, nothing run", w.buffered());
}
