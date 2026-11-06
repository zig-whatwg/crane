//! gc_bench's rows in the journal: the Crane-only rows (docs/performance.md,
//! "Crane-only rows"). Each row is one gc_bench process run under
//! `/usr/bin/time -l`, as the lanes' cost series run it (lanes compiletime1,
//! streamslife1): instructions retired, wall time and peak footprint of the
//! whole process, and from gc_bench's own report the resident bytes each
//! cycle kept, the engine heap and the live global handles.
//!
//! The workloads beside them in tests/perf/ run the same statements in every
//! engine; what has no browser equivalent is the measurement: a forced full
//! collection between batches (`--gc`, retention, not speed), instructions
//! counted for one process, and the engine adapter's counters.
//!
//! The row bodies are the lanes' (tmp/compiletime1/scripts/gcb.sh,
//! tmp/scratch/streamslife1/sl1-gcb.sh): changing one changes what its
//! history means, so they are pinned by a test.

const std = @import("std");
const Allocator = std.mem.Allocator;
const journal = @import("journal.zig");

pub const Row = struct {
    name: []const u8,
    /// The per-cycle statement (`--body=`); empty is gc_bench's default,
    /// createElement + discard.
    body: []const u8,
    cycles: u32,
    /// `--loop`: the event loop turned after each batch.
    loop: bool = false,
};

pub const rows = [_]Row{
    .{ .name = "create-element", .body = "", .cycles = 100000 },
    .{ .name = "getter-loop", .body = "void (globalThis.h ??= document.createElement('div')).id;", .cycles = 100000 },
    .{ .name = "setter-loop", .body = "(globalThis.h ??= document.createElement('div')).id = 'x';", .cycles = 100000 },
    .{ .name = "method-loop", .body = "void (globalThis.h ??= document.createElement('div')).hasAttribute('x');", .cycles = 100000 },
    .{ .name = "ctor-loop", .body = "new Event('x');", .cycles = 100000 },
    .{ .name = "dict-loop", .body = "new Event('x', { bubbles: true, cancelable: true });", .cycles = 100000 },
    .{ .name = "stream-reader", .body = "new ReadableStream({ start(c) { c.close(); } }).getReader();", .cycles = 20000 },
    .{ .name = "stream-values", .body = "new ReadableStream({ start(c) { c.close(); } }).values();", .cycles = 20000 },
    .{ .name = "writable-writer", .body = "new WritableStream().getWriter();", .cycles = 20000 },
    .{ .name = "response-text", .body = "new Response('x').text();", .cycles = 20000, .loop = true },
    .{ .name = "response-arraybuffer", .body = "new Response('x').arrayBuffer();", .cycles = 20000, .loop = true },
    .{ .name = "for-await", .body = "(async () => { for await (const c of new ReadableStream({ start(c) { c.enqueue(1); c.close(); } })); })();", .cycles = 20000, .loop = true },
    .{ .name = "blob-stream", .body = "new Blob(['x']).stream();", .cycles = 20000 },
    .{ .name = "text-decoder-stream", .body = "new TextDecoderStream();", .cycles = 20000 },
    .{ .name = "pipe-through", .body = "(async () => { const r = new Response('x').body.pipeThrough(new TextDecoderStream()).getReader(); while (!(await r.read()).done); })();", .cycles = 20000, .loop = true },
    .{ .name = "fetch-text", .body = "fetch('data:text/plain,x').then((r) => r.text());", .cycles = 20000, .loop = true },
};

pub fn find(name: []const u8) ?Row {
    for (rows) |r| if (std.mem.eql(u8, r.name, name)) return r;
    return null;
}

/// gc_bench's command line for `row`: `<cycles> <cycles> --gc [--loop]
/// [--body=...]` (one sample at the end, a collection between batches).
pub fn argv(arena: Allocator, gc_bench: []const u8, row: Row) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    const cycles = try std.fmt.allocPrint(arena, "{d}", .{row.cycles});
    try out.appendSlice(arena, &.{ "/usr/bin/time", "-l", gc_bench, cycles, cycles, "--gc" });
    if (row.loop) try out.append(arena, "--loop");
    if (row.body.len > 0) try out.append(arena, try std.fmt.allocPrint(arena, "--body={s}", .{row.body}));
    return out.items;
}

/// What one run printed (gc_bench's report and /usr/bin/time -l's).
pub const Figures = struct {
    wall_s: ?f64 = null,
    instructions: ?u64 = null,
    peak_footprint: ?u64 = null,
    max_rss: ?u64 = null,
    bytes_per_cycle: ?f64 = null,
    heap_used_mb: ?f64 = null,
    global_handle_bytes: ?f64 = null,
    live_object_globals: ?f64 = null,
};

/// The leading number of a `time -l` line ("   6579293474  instructions
/// retired"), when the line ends in `label`.
fn leading(line: []const u8, label: []const u8) ?u64 {
    const t = std.mem.trim(u8, line, " \t\r");
    if (!std.mem.endsWith(u8, t, label)) return null;
    const sp = std.mem.indexOfAny(u8, t, " \t") orelse return null;
    return std.fmt.parseInt(u64, t[0..sp], 10) catch null;
}

/// An adapter counter's end value ("  global_handle_bytes   +36352 ->
/// +36416  (0.00/elem)").
fn counterEnd(line: []const u8, name: []const u8) ?f64 {
    const t = std.mem.trim(u8, line, " \t\r");
    if (!std.mem.startsWith(u8, t, name) or t.len == name.len or (t[name.len] != ' ' and t[name.len] != '\t')) return null;
    const arrow = std.mem.indexOf(u8, t, "->") orelse return null;
    var rest = std.mem.trim(u8, t[arrow + 2 ..], " \t");
    const end = std.mem.indexOfAny(u8, rest, " \t") orelse rest.len;
    rest = rest[0..end];
    if (rest.len > 0 and rest[0] == '+') rest = rest[1..];
    return std.fmt.parseFloat(f64, rest) catch null;
}

pub fn parse(output: []const u8) Figures {
    var f: Figures = .{};
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (leading(line, "instructions retired")) |v| f.instructions = v;
        if (leading(line, "peak memory footprint")) |v| f.peak_footprint = v;
        if (leading(line, "maximum resident set size")) |v| f.max_rss = v;
        if (counterEnd(line, "global_handle_bytes")) |v| f.global_handle_bytes = v;
        if (counterEnd(line, "live_object_globals")) |v| f.live_object_globals = v;
        const t = std.mem.trim(u8, line, " \t\r");
        // "        0.16 real         0.56 user         0.07 sys"
        if (std.mem.indexOf(u8, t, " real ") != null and std.mem.endsWith(u8, t, " sys")) {
            const sp = std.mem.indexOfScalar(u8, t, ' ') orelse continue;
            f.wall_s = std.fmt.parseFloat(f64, t[0..sp]) catch null;
        }
        // "100000 cycles: 6.3 MB total, 66 bytes per element"
        if (std.mem.indexOf(u8, t, " cycles: ") != null and std.mem.endsWith(u8, t, " bytes per element")) {
            const comma = std.mem.lastIndexOfScalar(u8, t, ',') orelse continue;
            const num = std.mem.trim(u8, t[comma + 1 .. t.len - " bytes per element".len], " ");
            f.bytes_per_cycle = std.fmt.parseFloat(f64, num) catch null;
        }
        // "Engine heap: 4.5 MB used of 5.8 MB, ..."
        if (std.mem.startsWith(u8, t, "Engine heap: ")) {
            const rest = t["Engine heap: ".len..];
            const sp = std.mem.indexOfScalar(u8, rest, ' ') orelse continue;
            f.heap_used_mb = std.fmt.parseFloat(f64, rest[0..sp]) catch null;
        }
    }
    return f;
}

/// The journal's counters for a run's figures.
pub fn counters(arena: Allocator, f: Figures) ![]const journal.Counter {
    var out: std.ArrayList(journal.Counter) = .empty;
    if (f.bytes_per_cycle) |v| try out.append(arena, .{ .name = "rss_bytes_per_cycle", .value = v });
    if (f.heap_used_mb) |v| try out.append(arena, .{ .name = "engine_heap_used_mb", .value = v });
    if (f.global_handle_bytes) |v| try out.append(arena, .{ .name = "global_handle_bytes", .value = v });
    if (f.live_object_globals) |v| try out.append(arena, .{ .name = "live_object_globals", .value = v });
    return out.items;
}

const testing = std.testing;

/// Two lists of strings, equal string by string (expectEqualSlices compares
/// a slice of slices by pointer).
fn expectStrings(want: []const []const u8, got: []const []const u8) !void {
    try testing.expectEqual(want.len, got.len);
    for (want, got) |w, g| try testing.expectEqualStrings(w, g);
}

test "a gc_bench run's figures: time -l's and gc_bench's own" {
    const out = @embedFile("testdata/gc_bench-getter-loop.txt");
    const f = parse(out);
    try testing.expectEqual(@as(?u64, 6579293474), f.instructions);
    try testing.expectEqual(@as(?u64, 23937792), f.peak_footprint);
    try testing.expectEqual(@as(?u64, 51118080), f.max_rss);
    try testing.expectEqual(@as(?f64, 0.16), f.wall_s);
    try testing.expectEqual(@as(?f64, 66), f.bytes_per_cycle);
    try testing.expectEqual(@as(?f64, 4.5), f.heap_used_mb);
    try testing.expectEqual(@as(?f64, 36416), f.global_handle_bytes);
    try testing.expectEqual(@as(?f64, 7), f.live_object_globals);
}

test "the rows keep the lanes' bodies (their history means these statements)" {
    try testing.expectEqualStrings("void (globalThis.h ??= document.createElement('div')).id;", find("getter-loop").?.body);
    try testing.expectEqualStrings("new Event('x', { bubbles: true, cancelable: true });", find("dict-loop").?.body);
    try testing.expectEqual(@as(u32, 20000), find("fetch-text").?.cycles);
    try testing.expect(find("fetch-text").?.loop);
    try testing.expectEqualStrings("", find("create-element").?.body);
    // Each row is a workload of the journal: "gc-bench.<row>".
    for (rows) |r| {
        var buf: [64]u8 = undefined;
        try testing.expect(journal.isWorkloadName(try std.fmt.bufPrint(&buf, "gc-bench.{s}", .{r.name})));
    }
}

test "gc_bench's command line" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = try argv(arena.allocator(), "/b/gc_bench", find("fetch-text").?);
    try expectStrings(&.{ "/usr/bin/time", "-l", "/b/gc_bench", "20000", "20000", "--gc", "--loop", "--body=fetch('data:text/plain,x').then((r) => r.text());" }, a);
    const b = try argv(arena.allocator(), "/b/gc_bench", find("create-element").?);
    try expectStrings(&.{ "/usr/bin/time", "-l", "/b/gc_bench", "100000", "100000", "--gc" }, b);
}
