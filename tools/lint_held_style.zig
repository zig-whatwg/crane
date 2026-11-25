//! lint-held-style: every computed style a caller holds is released where it
//! was taken (lane cs1).
//!
//! `dom.style.computedStyle` answers a HELD style (src/dom/style/
//! held_style.zig): a reference on a refcounted ComputedStyle, valid until
//! the caller releases it, whatever style reads happen meanwhile - the cure
//! for the borrowed-style use-after-free (docs/lessons/architecture-a-borrow-
//! the-next-call-can-free-is-a-hold-in-the-type-not-a-comment.md). A hold
//! that is never released is a leak, and Debug's agent hold count
//! (runtime.native_holds) then panics at the next script entry; one kept
//! past the native call that took it crosses into script. Both are
//! decided where the hold is taken, so this lint checks it there.
//!
//! What is flagged, in src/ and tests/ through std.zig.Tokenizer (comments
//! and strings never are), at each call of a function that answers a hold
//! (`hold_functions`: dom.style's computedStyle, baseStyle,
//! fontStyleForText, fontStyleForControl, and the callers' wrappers, all
//! named heldStyleOf / heldStyle):
//! - a discarded hold: the call in a statement that starts `_ =`;
//! - an unbound hold: the call inside any other expression (`expect(try
//!   computedStyle(e, null) == null)`), whose hold nothing releases;
//! - a hold bound by `const NAME = ...;` whose next statement is not
//!   `defer NAME.release();` or `defer if (NAME) |x| x.release();`;
//! - a hold captured by `if (...) |NAME| {` whose block does not start with
//!   `defer NAME.release();`.
//! A statement that returns the call (`return ...`) hands the hold to its
//! caller, which this lint checks in turn; a function's own definition
//! (`fn computedStyle(`) is not a call.
//!
//! Exempt: a call whose line has a `// held-style: <why>` line directly
//! above it - a site that releases explicitly (a loop that keeps one hold
//! past it). Say why.
//!
//! Not scanned: src/dom/style/engine.zig and held_style.zig, which make
//! the holds. Not a ratchet: there is no baseline, and any unmarked site
//! fails.
//!
//!   zig build lint-held-style      (part of `zig build test`)

const std = @import("std");
const stdout_stream = @import("stdout_stream.zig");

/// The trees held to the rule.
const scanned_roots = [_][]const u8{ "src", "tests" };

/// Files that make the holds rather than take them.
const exempt_paths = [_][]const u8{
    "src/dom/style/engine.zig",
    "src/dom/style/held_style.zig",
};

/// The functions whose call answers a hold.
pub const hold_functions = [_][]const u8{
    "computedStyle",
    "baseStyle",
    "fontStyleForText",
    "fontStyleForControl",
    "heldStyleOf",
    "heldStyle",
};

/// The marker that exempts the call on the line below it.
pub const marker = "// held-style:";

/// Whether `path` (from the repo root, `/`-separated) is held to the rule.
pub fn isScanned(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    const rooted = for (scanned_roots) |root| {
        if (std.mem.startsWith(u8, path, root) and path.len > root.len and path[root.len] == '/') break true;
    } else false;
    if (!rooted) return false;
    if (std.mem.indexOf(u8, path, ".zig-cache/") != null) return false;
    if (std.mem.startsWith(u8, path, "tests/wpt/")) return false;
    for (exempt_paths) |exempt| if (std.mem.eql(u8, path, exempt)) return false;
    return true;
}

pub const Problem = enum {
    discarded,
    unbound,
    unreleased_binding,
    unreleased_capture,

    pub fn text(self: Problem) []const u8 {
        return switch (self) {
            .discarded => "a held computed style is discarded (`_ =`): a leak - resolve without a hold (dom.style.engine.resolveStyle) or release it",
            .unbound => "a held computed style is used inside an expression and never released: bind it (`const NAME = ...;` then `defer NAME.release();`)",
            .unreleased_binding => "a held computed style bound here is not released on the next line - `defer NAME.release();` right after the binding",
            .unreleased_capture => "a held computed style captured here is not released first thing in its block - `defer NAME.release();`",
        };
    }
};

/// One flagged call: its 1-based line and column, what is wrong, and whether
/// a marker line exempts it.
pub const Finding = struct {
    line: usize,
    column: usize,
    problem: Problem,
    marked: bool,
};

const Token = struct {
    tag: std.zig.Token.Tag,
    start: usize,
    end: usize,
};

fn isHoldFunction(name: []const u8) bool {
    for (hold_functions) |f| if (std.mem.eql(u8, name, f)) return true;
    return false;
}

/// Every flagged call in `source`.
pub fn findings(gpa: std.mem.Allocator, source: [:0]const u8) !std.ArrayList(Finding) {
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(gpa);
    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const t = tokenizer.next();
        if (t.tag == .eof) break;
        try tokens.append(gpa, .{ .tag = t.tag, .start = t.loc.start, .end = t.loc.end });
    }
    var found: std.ArrayList(Finding) = .empty;
    errdefer found.deinit(gpa);
    const ts = tokens.items;
    for (ts, 0..) |t, i| {
        if (t.tag != .identifier or i + 1 >= ts.len or ts[i + 1].tag != .l_paren) continue;
        if (!isHoldFunction(source[t.start..t.end])) continue;
        if (i > 0 and ts[i - 1].tag == .keyword_fn) continue;
        const problem = (try check(source, ts, i)) orelse continue;
        const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..t.start], '\n')) |nl| nl + 1 else 0;
        try found.append(gpa, .{
            .line = std.mem.count(u8, source[0..line_start], "\n") + 1,
            .column = t.start - line_start + 1,
            .problem = problem,
            .marked = markedAbove(source, line_start),
        });
    }
    return found;
}

/// The statement holding the call at token `call` - from the token after
/// the previous `;`, `{` or `}` at its depth - and what is wrong with it.
fn check(source: []const u8, ts: []const Token, call: usize) !?Problem {
    // The statement's first token: walk back over balanced brackets.
    var depth: isize = 0;
    var first = call;
    while (first > 0) {
        const prev = ts[first - 1];
        switch (prev.tag) {
            .r_paren, .r_bracket => depth += 1,
            .l_paren, .l_bracket => {
                if (depth == 0) {
                    // Inside an `if (...)` condition: a capture form.
                    if (first >= 2 and ts[first - 2].tag == .keyword_if) return checkCapture(source, ts, call);
                    depth -= 1;
                } else depth -= 1;
            },
            .semicolon, .l_brace, .r_brace => if (depth <= 0) break,
            else => {},
        }
        first -= 1;
    }
    const lead = ts[first];
    if (lead.tag == .keyword_return) return null;
    if (lead.tag == .identifier and std.mem.eql(u8, source[lead.start..lead.end], "_") and first + 1 < ts.len and ts[first + 1].tag == .equal) return .discarded;
    if (lead.tag == .keyword_const or lead.tag == .keyword_var) {
        if (first + 1 >= ts.len or ts[first + 1].tag != .identifier) return null;
        const name = source[ts[first + 1].start..ts[first + 1].end];
        // The statement's end: the `;` at the depth it started at, scanning
        // from its first token so that every bracket opened before the call
        // (`(try computedStyle(...)) orelse`) is counted.
        var j = first;
        var d: isize = 0;
        while (j < ts.len) : (j += 1) {
            switch (ts[j].tag) {
                .l_paren, .l_bracket, .l_brace => d += 1,
                .r_paren, .r_bracket, .r_brace => {
                    d -= 1;
                    // The block the statement is in ended: no `;` of its own.
                    if (d < 0) return .unreleased_binding;
                },
                .semicolon => if (d == 0) break,
                else => {},
            }
        }
        if (j + 1 >= ts.len) return .unreleased_binding;
        return if (releasesNext(source, ts, j + 1, name)) null else .unreleased_binding;
    }
    return .unbound;
}

/// `if (... call ...) |NAME| {` - the block's first statement releases NAME.
fn checkCapture(source: []const u8, ts: []const Token, call: usize) ?Problem {
    var j = call;
    var d: isize = 0;
    // The `)` closing the condition.
    while (j < ts.len) : (j += 1) {
        switch (ts[j].tag) {
            .l_paren => d += 1,
            .r_paren => {
                d -= 1;
                if (d < 0) break;
            },
            else => {},
        }
    }
    if (j + 4 >= ts.len) return null;
    if (ts[j + 1].tag != .pipe or ts[j + 2].tag != .identifier or ts[j + 3].tag != .pipe) return null;
    const name = source[ts[j + 2].start..ts[j + 2].end];
    if (ts[j + 4].tag != .l_brace) return .unreleased_capture;
    return if (releasesNext(source, ts, j + 5, name)) null else .unreleased_capture;
}

/// Whether the tokens from `at` are `defer NAME.release();` or
/// `defer if (NAME) |x| x.release();`.
fn releasesNext(source: []const u8, ts: []const Token, at: usize, name: []const u8) bool {
    const eq = struct {
        fn f(s: []const u8, t: Token, text: []const u8) bool {
            return std.mem.eql(u8, s[t.start..t.end], text);
        }
    }.f;
    if (at + 5 < ts.len and ts[at].tag == .keyword_defer and eq(source, ts[at + 1], name) and ts[at + 2].tag == .period and eq(source, ts[at + 3], "release") and ts[at + 4].tag == .l_paren) return true;
    if (at + 11 < ts.len and ts[at].tag == .keyword_defer and ts[at + 1].tag == .keyword_if and ts[at + 2].tag == .l_paren and eq(source, ts[at + 3], name) and ts[at + 4].tag == .r_paren and ts[at + 5].tag == .pipe and ts[at + 6].tag == .identifier and ts[at + 7].tag == .pipe and eq(source, ts[at + 8], source[ts[at + 6].start..ts[at + 6].end]) and ts[at + 9].tag == .period and eq(source, ts[at + 10], "release")) return true;
    return false;
}

/// Whether the line before the one starting at `line_start` is a marker
/// with a reason.
fn markedAbove(source: []const u8, line_start: usize) bool {
    if (line_start == 0) return false;
    const above_end = line_start - 1;
    const above_start = if (std.mem.lastIndexOfScalar(u8, source[0..above_end], '\n')) |nl| nl + 1 else 0;
    const above = std.mem.trim(u8, source[above_start..above_end], " \t\r");
    if (!std.mem.startsWith(u8, above, marker)) return false;
    return std.mem.trim(u8, above[marker.len..], " \t").len > 0;
}

/// Check every scanned file under `dir`; print each unmarked finding to
/// `out`. The number of unmarked findings, and of marked ones.
pub fn checkTree(io: std.Io, gpa: std.mem.Allocator, dir: std.Io.Dir, out: *std.Io.Writer) !struct { unmarked: usize, marked: usize } {
    var unmarked: usize = 0;
    var marked: usize = 0;
    for (scanned_roots) |scanned_root| {
        var root = dir.openDir(io, scanned_root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer root.close(io);
        var walker = try root.walk(gpa);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind != .file) continue;
            const path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ scanned_root, entry.path });
            defer gpa.free(path);
            std.mem.replaceScalar(u8, path, '\\', '/');
            if (!isScanned(path)) continue;
            const source = try dir.readFileAllocOptions(io, path, gpa, .limited(64 << 20), .of(u8), 0);
            defer gpa.free(source);
            var found = try findings(gpa, source);
            defer found.deinit(gpa);
            for (found.items) |f| {
                if (f.marked) {
                    marked += 1;
                    continue;
                }
                unmarked += 1;
                try out.print("{s}:{d}:{d}: error: {s}; a site that releases otherwise takes a \"{s} <why>\" line directly above (tools/lint_held_style.zig)\n", .{ path, f.line, f.column, f.problem.text(), marker });
            }
        }
    }
    return .{ .unmarked = unmarked, .marked = marked };
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    const result = try checkTree(io, init.gpa, std.Io.Dir.cwd(), out);
    if (result.unmarked > 0) {
        try out.print("\nlint-held-style: {d} held computed style(s) not released where taken (tools/lint_held_style.zig); {d} reviewed.\n", .{ result.unmarked, result.marked });
        try out.flush();
        std.process.exit(1);
    }
    try out.print("lint-held-style: every held computed style released where taken, {d} reviewed site(s).\n", .{result.marked});
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn findingsOf(source: [:0]const u8) !std.ArrayList(Finding) {
    return findings(testing.allocator, source);
}

test "a binding released on the next line, a capture released first, and a returned hold pass" {
    var found = try findingsOf(
        \\fn a(e: *I) !bool {
        \\    const held = (try dom.style.computedStyle(e, null)) orelse return false;
        \\    defer held.release();
        \\    return held.style.display().box == .none;
        \\}
        \\fn b(e: *I) bool {
        \\    if (dom.style.computedStyle(e, null) catch null) |s| {
        \\        defer s.release();
        \\        return s.style.keyword(.visibility) == .visible;
        \\    }
        \\    return false;
        \\}
        \\fn heldStyleOf(e: *I) ?dom.style.HeldStyle {
        \\    return dom.style.computedStyle(e, null) catch null;
        \\}
        \\fn c(e: *I) void {
        \\    const maybe = dom.style.engine.computedStyle(e, null) catch null;
        \\    defer if (maybe) |h| h.release();
        \\}
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), found.items.len);
}

test "a discarded hold, a binding with no release next, a capture that does not release first and an unbound hold are found" {
    var found = try findingsOf(
        \\fn a(e: *I) !void {
        \\    _ = (try dom.style.computedStyle(e, null)).?;
        \\    const held = (try heldStyleOf(e)) orelse return;
        \\    use(held.style);
        \\    held.release();
        \\    if (map.heldStyle() catch null) |s| {
        \\        use(s.style);
        \\        s.release();
        \\    }
        \\    try expect(try dom.style.engine.fontStyleForText(n) == null);
        \\}
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 4), found.items.len);
    try testing.expectEqual(Problem.discarded, found.items[0].problem);
    try testing.expectEqual(@as(usize, 2), found.items[0].line);
    try testing.expectEqual(Problem.unreleased_binding, found.items[1].problem);
    try testing.expectEqual(@as(usize, 3), found.items[1].line);
    try testing.expectEqual(Problem.unreleased_capture, found.items[2].problem);
    try testing.expectEqual(@as(usize, 6), found.items[2].line);
    try testing.expectEqual(Problem.unbound, found.items[3].problem);
    try testing.expectEqual(@as(usize, 10), found.items[3].line);
}

test "a marker with a reason directly above exempts; a comment or a string naming the function is no call" {
    var found = try findingsOf(
        \\fn a(e: *I) void {
        \\    // computedStyle(e, null) in a comment
        \\    const text = "computedStyle(e, null)";
        \\    // held-style: kept past the loop, released below.
        \\    const s = (dom.style.computedStyle(e, null) catch null) orelse return;
        \\    _ = text;
        \\    s.release();
        \\}
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), found.items.len);
    try testing.expect(found.items[0].marked);
}

test "src/ and tests/ are scanned, except the files that make the holds and the WPT tree" {
    try testing.expect(isScanned("src/dom/accessibility_tree.zig"));
    try testing.expect(isScanned("tests/v8/cs1_held_style_test.zig"));
    try testing.expect(!isScanned("src/dom/style/engine.zig"));
    try testing.expect(!isScanned("src/dom/style/held_style.zig"));
    try testing.expect(!isScanned("tests/wpt/crane/x.zig"));
    try testing.expect(!isScanned("tools/lint_held_style.zig"));
    try testing.expect(!isScanned("srcx/a.zig"));
}
