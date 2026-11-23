//! lint-page-allocator: `std.heap.page_allocator` stays out of src/ except at
//! reviewed sites.
//!
//! Zig's page allocator has no size classes and no reuse: every allocation
//! is an mmap of whole pages (std/heap/PageAllocator.zig, the pinned 0.17
//! toolchain), and every free an munmap. A 24-byte record on it costs a
//! 16 KiB page on macOS and a page and a mapping on Linux, where a process
//! past vm.max_map_count (65,530 by default) fails every later mmap, V8's
//! included. Lane alloc1's inventory found it under page-input paths (an
//! addEventListener signal's record kept a page per listener; URL.canParse,
//! IDNA, the inline style parse and the navigable walks mapped and unmapped
//! pages per call), and lane leak3 moved every one to its owner's
//! allocator, a stack buffer, or libc's (docs/lessons/architecture-std-heap-
//! page-allocator-maps-a-page-per-allocation.md).
//!
//! What is flagged, in src/**/*.zig through std.zig.Tokenizer (so comments
//! and string literals never are): a `.` followed by the identifier
//! `page_allocator` or `PageAllocator` - `std.heap.page_allocator`,
//! `@import("std").heap.page_allocator`, `heap.PageAllocator` and the like.
//!
//! Exempt: a use whose line has a `// page-allocator: <why>` line directly
//! above it - a reviewed site that genuinely wants whole pages (a
//! process-wide startup buffer, an arena's backing). Say why.
//!
//! Not scanned:
//! - src/webidl/codegen/: the build-time WebIDL generator (`zig build
//!   codegen`), never called at run time, which allocates through the page
//!   allocator throughout (the integrator's ruling, 2026-11-22);
//! - src/webidl/impls_tmp/: codegen's stubs for hand merging, not built.
//!
//! Not a ratchet: there is no baseline, and any unmarked use fails.
//!
//!   zig build lint-page-allocator      (part of `zig build test`)

const std = @import("std");
const stdout_stream = @import("stdout_stream.zig");

/// The tree held to the rule.
const scanned_root = "src";

/// Directories of src/ that are not held to it, each with its reason above.
const exempt_prefixes = [_][]const u8{
    "src/webidl/codegen/",
    "src/webidl/impls_tmp/",
};

/// The marker that exempts the use on the line below it.
pub const marker = "// page-allocator:";

/// Whether `path` (from the repo root, `/`-separated) is held to the rule.
pub fn isScanned(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    if (!std.mem.startsWith(u8, path, scanned_root ++ "/")) return false;
    if (std.mem.indexOf(u8, path, ".zig-cache/") != null) return false;
    for (exempt_prefixes) |prefix| if (std.mem.startsWith(u8, path, prefix)) return false;
    return true;
}

/// One use of the page allocator: its 1-based line and column, and whether a
/// marker line exempts it.
pub const Use = struct {
    line: usize,
    column: usize,
    marked: bool,
};

/// Every use of the page allocator in `source`.
pub fn uses(gpa: std.mem.Allocator, source: [:0]const u8) !std.ArrayList(Use) {
    var found: std.ArrayList(Use) = .empty;
    errdefer found.deinit(gpa);
    var tokenizer = std.zig.Tokenizer.init(source);
    var previous: std.zig.Token.Tag = .eof;
    while (true) {
        const token = tokenizer.next();
        if (token.tag == .eof) break;
        defer previous = token.tag;
        if (token.tag != .identifier or previous != .period) continue;
        const name = source[token.loc.start..token.loc.end];
        if (!std.mem.eql(u8, name, "page_allocator") and !std.mem.eql(u8, name, "PageAllocator")) continue;
        const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..token.loc.start], '\n')) |nl| nl + 1 else 0;
        try found.append(gpa, .{
            .line = std.mem.count(u8, source[0..line_start], "\n") + 1,
            .column = token.loc.start - line_start + 1,
            .marked = markedAbove(source, line_start),
        });
    }
    return found;
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

/// Check every scanned file under `dir`'s src/; print each unmarked use to
/// `out`. The number of unmarked uses, and of marked ones.
pub fn check(io: std.Io, gpa: std.mem.Allocator, dir: std.Io.Dir, out: *std.Io.Writer) !struct { unmarked: usize, marked: usize } {
    var unmarked: usize = 0;
    var marked: usize = 0;
    var root = dir.openDir(io, scanned_root, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return .{ .unmarked = 0, .marked = 0 },
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
        var found = try uses(gpa, source);
        defer found.deinit(gpa);
        for (found.items) |use| {
            if (use.marked) {
                marked += 1;
                continue;
            }
            unmarked += 1;
            try out.print("{s}:{d}:{d}: error: std.heap.page_allocator maps a page per allocation - use the owner's allocator, a stack buffer (std.heap.BufferFirstAllocator over it), or libc's where none is in reach; a site that wants whole pages takes a \"{s} <why>\" line directly above (docs/lessons/architecture-std-heap-page-allocator-maps-a-page-per-allocation.md)\n", .{ path, use.line, use.column, marker });
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

    const result = try check(io, init.gpa, std.Io.Dir.cwd(), out);
    if (result.unmarked > 0) {
        try out.print("\nlint-page-allocator: {d} unmarked use(s) of the page allocator in src/ (tools/lint_page_allocator.zig); {d} reviewed.\n", .{ result.unmarked, result.marked });
        try out.flush();
        std.process.exit(1);
    }
    try out.print("lint-page-allocator: 0 unmarked uses in src/, {d} reviewed site(s).\n", .{result.marked});
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn usesOf(source: [:0]const u8) !std.ArrayList(Use) {
    return uses(testing.allocator, source);
}

test "a use in code is found with its line and column; one in a comment or a string is not" {
    var found = try usesOf(
        \\const std = @import("std");
        \\// std.heap.page_allocator in a comment
        \\/// and in a doc comment: std.heap.page_allocator
        \\const text = "std.heap.page_allocator";
        \\fn f() void {
        \\    const a = std.heap.page_allocator;
        \\    _ = a;
        \\}
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), found.items.len);
    try testing.expectEqual(@as(usize, 6), found.items[0].line);
    try testing.expectEqual(@as(usize, 24), found.items[0].column);
    try testing.expect(!found.items[0].marked);
}

test "every spelling through a field access is found" {
    var found = try usesOf(
        \\const a = @import("std").heap.page_allocator;
        \\const heap = std.heap;
        \\const b = heap.page_allocator;
        \\const C = std.heap.PageAllocator;
        \\var list = std.ArrayList(u8).init(std.heap.page_allocator);
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 4), found.items.len);
    try testing.expectEqual(@as(usize, 1), found.items[0].line);
    try testing.expectEqual(@as(usize, 3), found.items[1].line);
    try testing.expectEqual(@as(usize, 4), found.items[2].line);
    try testing.expectEqual(@as(usize, 5), found.items[3].line);
}

test "a marker with a reason directly above exempts; an empty one, or one further up, does not" {
    var found = try usesOf(
        \\    // page-allocator: the process's snapshot, whole pages, once.
        \\    const a = std.heap.page_allocator;
        \\    // page-allocator:
        \\    const b = std.heap.page_allocator;
        \\    // page-allocator: two lines up is not directly above.
        \\
        \\    const c = std.heap.page_allocator;
        \\    // not-a-marker: page-allocator
        \\    const d = std.heap.page_allocator;
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 4), found.items.len);
    try testing.expect(found.items[0].marked);
    try testing.expect(!found.items[1].marked);
    try testing.expect(!found.items[2].marked);
    try testing.expect(!found.items[3].marked);
}

test "src/ is scanned except the build-time generator and codegen's stubs" {
    try testing.expect(isScanned("src/dom/tree.zig"));
    try testing.expect(isScanned("src/runtime/engines/v8/wrapper_cache.zig"));
    try testing.expect(isScanned("src/webidl/impls/EventTarget.zig"));
    try testing.expect(!isScanned("src/webidl/codegen/writer.zig"));
    try testing.expect(!isScanned("src/webidl/impls_tmp/EventTarget.zig"));
    try testing.expect(!isScanned("src/dom/notes.md"));
    try testing.expect(!isScanned("tools/lint_page_allocator.zig"));
    try testing.expect(!isScanned("tests/html/leak3_signal_listener_record_test.zig"));
    try testing.expect(!isScanned("src/.zig-cache/o/x.zig"));
}

test "check flags an unmarked use under src/dom with its place, and skips the generator's" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = testing.io;
    try tmp.dir.createDirPath(io, "src/dom");
    try tmp.dir.createDirPath(io, "src/webidl/codegen");
    try tmp.dir.createDirPath(io, "src/browser");
    try tmp.dir.writeFile(io, .{ .sub_path = "src/dom/walk.zig", .data = "const std = @import(\"std\");\nfn f() void {\n    var l = std.heap.page_allocator;\n    _ = &l;\n}\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/webidl/codegen/writer.zig", .data = "const a = std.heap.page_allocator;\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/browser/process.zig", .data = "// page-allocator: the snapshot.\nconst a = std.heap.page_allocator;\n" });
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    const result = try check(io, testing.allocator, tmp.dir, &w);
    try testing.expectEqual(@as(usize, 1), result.unmarked);
    try testing.expectEqual(@as(usize, 1), result.marked);
    const text = w.buffered();
    try testing.expect(std.mem.indexOf(u8, text, "src/dom/walk.zig:3:22: error: std.heap.page_allocator maps a page per allocation") != null);
    try testing.expect(std.mem.indexOf(u8, text, "codegen") == null);
    try testing.expect(std.mem.indexOf(u8, text, "process.zig") == null);
}
