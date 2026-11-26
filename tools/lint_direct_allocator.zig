//! lint-direct-allocator: `std.heap.c_allocator`, `std.heap.smp_allocator`,
//! `std.heap.page_allocator` and `std.heap.PageAllocator` stay out of `src/`
//! outside `src/platform/` and reviewed process-wide / C-ABI / standalone
//! fallback sites (allocator-hardening batch C, item 4).
//!
//! Every allocation a page can cause belongs in its Browser's hardened heap
//! (`.node`, `.satellite`, `.objects`, or `.bytes`), reached through the
//! owner's allocator (`runtime.allocatorOf`, `realm.allocator`,
//! `scope.allocator`, `AgentRecord.allocator`). Direct `std.heap.*_allocator`
//! calls bypass per-Browser isolation, zero-on-free, quarantine, decommit, and
//! the heap leak report.
//!
//! What is flagged, in `src/**/*.zig` through `std.zig.Tokenizer` (comments
//! and string literals never match): a `.` followed by `c_allocator`,
//! `smp_allocator`, `page_allocator`, or `PageAllocator`.
//!
//! Exempt:
//! - `src/platform/`: the platform layer implements OS/host backing;
//! - `src/webidl/codegen/`, `src/webidl/impls_tmp/`: build-time codegen;
//! - Any use whose line directly above carries a reviewed marker with a
//!   non-empty reason: `// direct-allocator: <why>` or `// page-allocator: <why>`.
//!
//! A ratchet: `tools/direct_allocator_baseline.txt` records any remaining
//! unmarked debt per file (`path count`). New or grown counts fail; the
//! baseline only goes down (`-- --update` after migrating sites; `-- --list`
//! prints every unmarked use).
//!
//!   zig build lint-direct-allocator              (part of `zig build test`)
//!   zig build lint-direct-allocator -- --list
//!   zig build lint-direct-allocator -- --update

const std = @import("std");
const stdout_stream = @import("stdout_stream.zig");

const scanned_root = "src";
pub const baseline_path = "tools/direct_allocator_baseline.txt";

const exempt_prefixes = [_][]const u8{
    "src/platform/",
    "src/webidl/codegen/",
    "src/webidl/impls_tmp/",
};

pub const direct_marker = "// direct-allocator:";
pub const page_marker = "// page-allocator:";

pub fn isScanned(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    if (!std.mem.startsWith(u8, path, scanned_root ++ "/")) return false;
    if (std.mem.indexOf(u8, path, ".zig-cache/") != null) return false;
    for (exempt_prefixes) |prefix| if (std.mem.startsWith(u8, path, prefix)) return false;
    return true;
}

pub const Use = struct {
    line: usize,
    column: usize,
    name: []const u8,
    marked: bool,
};

fn isFlaggedName(name: []const u8) bool {
    return std.mem.eql(u8, name, "c_allocator") or
        std.mem.eql(u8, name, "smp_allocator") or
        std.mem.eql(u8, name, "page_allocator") or
        std.mem.eql(u8, name, "PageAllocator");
}

fn hasMarker(line: []const u8) bool {
    if (std.mem.startsWith(u8, line, direct_marker)) {
        return std.mem.trim(u8, line[direct_marker.len..], " \t").len > 0;
    }
    if (std.mem.startsWith(u8, line, page_marker)) {
        return std.mem.trim(u8, line[page_marker.len..], " \t").len > 0;
    }
    return false;
}

/// Whether the line directly above `line_start` (or the start of a contiguous
/// comment block directly above it) carries a reviewed marker with a reason.
fn markedAbove(source: []const u8, line_start: usize) bool {
    if (line_start == 0) return false;
    const above_end = line_start - 1;
    const above_start = if (std.mem.lastIndexOfScalar(u8, source[0..above_end], '\n')) |nl| nl + 1 else 0;
    const above = std.mem.trim(u8, source[above_start..above_end], " \t\r");
    return hasMarker(above);
}

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
        if (!isFlaggedName(name)) continue;
        const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..token.loc.start], '\n')) |nl| nl + 1 else 0;
        try found.append(gpa, .{
            .line = std.mem.count(u8, source[0..line_start], "\n") + 1,
            .column = token.loc.start - line_start + 1,
            .name = name,
            .marked = markedAbove(source, line_start),
        });
    }
    return found;
}

pub const Counts = std.StringHashMapUnmanaged(usize);

pub fn parseBaseline(arena: std.mem.Allocator, text: []const u8) !Counts {
    var counts: Counts = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const last_space = std.mem.lastIndexOfScalar(u8, line, ' ') orelse return error.BadBaseline;
        const count = std.fmt.parseInt(usize, line[last_space + 1 ..], 10) catch return error.BadBaseline;
        try counts.put(arena, try arena.dupe(u8, line[0..last_space]), count);
    }
    return counts;
}

const baseline_header =
    \\# Unmarked direct std.heap allocator uses (c_allocator, smp_allocator,
    \\# page_allocator, PageAllocator) in src/ outside src/platform/:
    \\# path count (tools/lint_direct_allocator.zig).
    \\# Every allocation a page can cause belongs in its Browser's hardened heap;
    \\# genuine process-wide / C-ABI / standalone-fallback sites take a
    \\# `// direct-allocator: <why>` (or `// page-allocator: <why>`) line directly
    \\# above. A ratchet: `zig build lint-direct-allocator` (part of `zig build
    \\# test`) fails on any new or grown count; `-- --update` records lower counts.
    \\
;

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

pub fn formatBaseline(arena: std.mem.Allocator, counts: *const Counts) ![]u8 {
    var keys: std.ArrayList([]const u8) = .empty;
    var it = counts.keyIterator();
    while (it.next()) |k| try keys.append(arena, k.*);
    std.mem.sort([]const u8, keys.items, {}, lessThan);

    var out: std.Io.Writer.Allocating = .init(arena);
    try out.writer.writeAll(baseline_header);
    for (keys.items) |k| {
        const v = counts.get(k).?;
        if (v == 0) continue;
        try out.writer.print("{s} {d}\n", .{ k, v });
    }
    return out.written();
}

pub const ScanResult = struct {
    counts: Counts,
    total_unmarked: usize,
    total_marked: usize,
};

pub fn scan(io: std.Io, arena: std.mem.Allocator, dir: std.Io.Dir, list_out: ?*std.Io.Writer) !ScanResult {
    var counts: Counts = .empty;
    var total_unmarked: usize = 0;
    var total_marked: usize = 0;

    var root = dir.openDir(io, scanned_root, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return .{ .counts = counts, .total_unmarked = 0, .total_marked = 0 },
        else => return err,
    };
    defer root.close(io);
    var walker = try root.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ scanned_root, entry.path });
        std.mem.replaceScalar(u8, path, '\\', '/');
        if (!isScanned(path)) continue;
        const source = try dir.readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
        const found = try uses(arena, source);
        var file_unmarked: usize = 0;
        for (found.items) |u| {
            if (u.marked) {
                total_marked += 1;
                continue;
            }
            file_unmarked += 1;
            total_unmarked += 1;
            if (list_out) |w| {
                try w.print("{s}:{d}:{d}: std.heap.{s}\n", .{ path, u.line, u.column, u.name });
            }
        }
        if (file_unmarked > 0) {
            try counts.put(arena, path, file_unmarked);
        }
    }
    return .{
        .counts = counts,
        .total_unmarked = total_unmarked,
        .total_marked = total_marked,
    };
}

pub fn checkAgainstBaseline(
    actual: *const Counts,
    baseline: *const Counts,
    out: *std.Io.Writer,
) !struct { regressions: usize, improvements: usize } {
    var regressions: usize = 0;
    var improvements: usize = 0;

    var it = actual.iterator();
    while (it.next()) |kv| {
        const allowed = baseline.get(kv.key_ptr.*) orelse 0;
        if (kv.value_ptr.* > allowed) {
            regressions += kv.value_ptr.* - allowed;
            try out.print("{s}: error: {d} unmarked direct std.heap allocator use(s) (baseline {d}) - use the owner's allocator or add a \"{s} <why>\" line directly above\n", .{ kv.key_ptr.*, kv.value_ptr.*, allowed, direct_marker });
        } else if (kv.value_ptr.* < allowed) {
            improvements += allowed - kv.value_ptr.*;
        }
    }
    var bit = baseline.iterator();
    while (bit.next()) |kv| {
        if (!actual.contains(kv.key_ptr.*) and kv.value_ptr.* > 0) {
            improvements += kv.value_ptr.*;
        }
    }
    return .{ .regressions = regressions, .improvements = improvements };
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var list_mode = false;
    var update_mode = false;
    var args_it = try std.process.Args.Iterator.initAllocator(init.minimal.args, arena);
    defer args_it.deinit();
    _ = args_it.next();
    while (args_it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--list")) list_mode = true;
        if (std.mem.eql(u8, arg, "--update")) update_mode = true;
    }

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    const cwd = std.Io.Dir.cwd();
    const scanned = try scan(io, arena, cwd, if (list_mode) out else null);
    if (list_mode) {
        try out.print("lint-direct-allocator: {d} unmarked, {d} reviewed.\n", .{ scanned.total_unmarked, scanned.total_marked });
        return;
    }

    const baseline_text = cwd.readFileAlloc(io, baseline_path, arena, .limited(4 << 20)) catch |err| switch (err) {
        error.FileNotFound => "",
        else => return err,
    };
    const baseline = try parseBaseline(arena, baseline_text);
    const diff = try checkAgainstBaseline(&scanned.counts, &baseline, out);

    if (update_mode) {
        if (diff.regressions > 0) {
            try out.print("\nlint-direct-allocator: refusing --update: {d} new or grown unmarked use(s) above baseline.\n", .{diff.regressions});
            try out.flush();
            std.process.exit(1);
        }
        const formatted = try formatBaseline(arena, &scanned.counts);
        try cwd.writeFile(io, .{ .sub_path = baseline_path, .data = formatted });
        try out.print("lint-direct-allocator: updated {s} ({d} unmarked, {d} reviewed).\n", .{ baseline_path, scanned.total_unmarked, scanned.total_marked });
        return;
    }

    if (diff.regressions > 0) {
        try out.print("\nlint-direct-allocator: {d} regression(s) ({d} unmarked total, {d} reviewed; run `-- --list` to inspect).\n", .{ diff.regressions, scanned.total_unmarked, scanned.total_marked });
        try out.flush();
        std.process.exit(1);
    }
    try out.print("lint-direct-allocator: {d} unmarked (baseline ok, {d} below baseline), {d} reviewed.\n", .{ scanned.total_unmarked, diff.improvements, scanned.total_marked });
}

// ============================================================================
// Tests (red and green fixtures)
// ============================================================================

const testing = std.testing;

test "red fixtures: unmarked c_allocator, smp_allocator, page_allocator, and empty marker are flagged" {
    var found = try uses(testing.allocator,
        \\const std = @import("std");
        \\const a = std.heap.c_allocator;
        \\const b = std.heap.smp_allocator;
        \\const c = @import("std").heap.page_allocator;
        \\// direct-allocator:
        \\const d = std.heap.c_allocator;
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 4), found.items.len);
    for (found.items) |u| try testing.expect(!u.marked);
}

test "green fixtures: reviewed markers, comments, strings, platform, and codegen are allowed" {
    var found = try uses(testing.allocator,
        \\// std.heap.c_allocator in comment
        \\const s = "std.heap.smp_allocator";
        \\// direct-allocator: process-wide UA stylesheet built once at start.
        \\const a = std.heap.c_allocator;
        \\// page-allocator: process snapshot buffer.
        \\const b = std.heap.page_allocator;
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), found.items.len);
    try testing.expect(found.items[0].marked);
    try testing.expect(found.items[1].marked);

    try testing.expect(isScanned("src/html/script_execution.zig"));
    try testing.expect(isScanned("src/runtime/engines/v8/wrapper_cache.zig"));
    try testing.expect(!isScanned("src/platform/host.zig"));
    try testing.expect(!isScanned("src/webidl/codegen/writer.zig"));
    try testing.expect(!isScanned("src/webidl/impls_tmp/X.zig"));
    try testing.expect(!isScanned("tools/repl.zig"));
}

test "ratchet fails on growth and passes at or below baseline" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const base = try parseBaseline(arena, "src/a.zig 2\nsrc/b.zig 1\n");
    var worse: Counts = .empty;
    try worse.put(arena, "src/a.zig", 3);
    var buf: [1024]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    const d1 = try checkAgainstBaseline(&worse, &base, &w);
    try testing.expectEqual(@as(usize, 1), d1.regressions);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "src/a.zig: error: 3 unmarked") != null);

    var better: Counts = .empty;
    try better.put(arena, "src/a.zig", 1);
    var w2: std.Io.Writer = .fixed(&buf);
    const d2 = try checkAgainstBaseline(&better, &base, &w2);
    try testing.expectEqual(@as(usize, 0), d2.regressions);
    try testing.expectEqual(@as(usize, 2), d2.improvements);
}
