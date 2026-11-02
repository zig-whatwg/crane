//! The machine-readable result file: one JSON object per line, one line per
//! test the run selected, in run order (batch, then position), so a reader
//! sees each test after the tests that ran before it in its process.
//!
//!   {"name":"...","index":12,"status":"ORDER-DEPENDENT","first":"fail",
//!    "alone":["pass","pass"],"replay":"fail","batch":3,"position":4,
//!    "seed":"0x1f","duration_ms":12.5}

const std = @import("std");
const sched = @import("scheduler.zig");

pub fn writeJsonString(w: *std.Io.Writer, s: []const u8) std.Io.Writer.Error!void {
    try w.writeByte('"');
    for (s) |c| switch (c) {
        '"' => try w.writeAll("\\\""),
        '\\' => try w.writeAll("\\\\"),
        '\n' => try w.writeAll("\\n"),
        '\r' => try w.writeAll("\\r"),
        '\t' => try w.writeAll("\\t"),
        0...8, 11, 12, 14...0x1f, 0x7f => try w.print("\\u{x:0>4}", .{c}),
        else => try w.writeByte(c),
    };
    try w.writeByte('"');
}

pub fn writeLine(w: *std.Io.Writer, name: []const u8, index: u32, rec: *const sched.TestRecord, seed: u64) std.Io.Writer.Error!void {
    try w.writeAll("{\"name\":");
    try writeJsonString(w, name);
    try w.print(",\"index\":{d},\"status\":\"{s}\",\"first\":\"{t}\",\"alone\":[", .{ index, rec.verdict.label(), rec.first });
    for (rec.aloneRuns(), 0..) |s, i| {
        if (i != 0) try w.writeByte(',');
        try w.print("\"{t}\"", .{s});
    }
    try w.writeAll("],\"replay\":");
    if (rec.replay) |s| try w.print("\"{t}\"", .{s}) else try w.writeAll("null");
    try w.print(",\"batch\":{d},\"position\":{d},\"seed\":\"0x{x}\",\"duration_ms\":{d}.{d:0>3}}}\n", .{
        rec.batch, rec.position, seed, rec.ns / std.time.ns_per_ms, (rec.ns / std.time.ns_per_us) % 1000,
    });
}

/// A test that did not pass, for a person: its verdict, name, how its first
/// run ended, where it ran (batch, position, seed), its alone runs and its
/// prefix replay, then the end of its output.
///
///   FAIL css.x_test.test.it (first run: fail, batch 3 position 4, seed 0x1f; alone: fail fail)
pub fn writeVerdictBlock(w: *std.Io.Writer, name: []const u8, rec: *const sched.TestRecord, seed: u64) std.Io.Writer.Error!void {
    try w.print("{s} {s} (first run: {t}, batch {d} position {d}, seed 0x{x}; alone:", .{
        rec.verdict.label(), name, rec.first, rec.batch, rec.position, seed,
    });
    for (rec.aloneRuns()) |s| try w.print(" {t}", .{s});
    if (rec.replay) |s| try w.print("; after the tests before it in its process (from position {d}): {t}", .{ rec.process_start, s });
    try w.writeAll(")\n");
    const tail = lastLines(rec.output, 40);
    if (tail.len != 0) try w.print("{s}\n", .{tail});
}

/// The last `n` lines of `s` (the end of a crash report is the useful part).
pub fn lastLines(s: []const u8, n: usize) []const u8 {
    const trimmed = std.mem.trimEnd(u8, s, "\n");
    var count: usize = 0;
    var i = trimmed.len;
    while (i > 0) : (i -= 1) {
        if (trimmed[i - 1] == '\n') {
            count += 1;
            if (count == n) return trimmed[i..];
        }
    }
    return trimmed;
}

/// Durations from an earlier run's result file, by test name: the input of
/// the longest-first claim order. Lines that do not parse are skipped (an
/// old or truncated file only loses its timings). `index_of` maps a name to
/// this run's test index; `out[i]` gets that test's duration in ns.
pub fn readTimings(gpa: std.mem.Allocator, text: []const u8, index_of: *const std.StringHashMapUnmanaged(u32), out: []?u64) void {
    const Line = struct { name: []const u8, duration_ms: f64 };
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        if (line.len == 0) continue;
        const parsed = std.json.parseFromSlice(Line, gpa, line, .{ .ignore_unknown_fields = true }) catch continue;
        defer parsed.deinit();
        const i = index_of.get(parsed.value.name) orelse continue;
        if (i >= out.len or parsed.value.duration_ms < 0) continue;
        out[i] = @intFromFloat(parsed.value.duration_ms * std.time.ns_per_ms);
    }
}

const testing = std.testing;

test "lastLines keeps the end" {
    try testing.expectEqualStrings("c\nd", lastLines("a\nb\nc\nd\n", 2));
    try testing.expectEqualStrings("a\nb", lastLines("a\nb", 5));
    try testing.expectEqualStrings("", lastLines("", 5));
}

test "a verdict block names the verdict, the runs, the batch, the seed and the output's end" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var rec: sched.TestRecord = .{ .batch = 2, .position = 1, .first = .crash, .ran = true, .verdict = .fail };
    rec.alone[0] = .crash;
    rec.alone_len = 1;
    var output = "panic: here\n".*;
    rec.output = &output;
    try writeVerdictBlock(&aw.writer, "x.test.boom", &rec, 0x2a);
    try testing.expectEqualStrings("FAIL x.test.boom (first run: crash, batch 2 position 1, seed 0x2a; alone: crash)\npanic: here\n", aw.written());
}

test "timings: an earlier result file's durations by name; bad lines and unknown names are skipped" {
    var index_of: std.StringHashMapUnmanaged(u32) = .empty;
    defer index_of.deinit(testing.allocator);
    try index_of.put(testing.allocator, "a.test.one", 0);
    try index_of.put(testing.allocator, "a.test.two", 1);
    var out = [_]?u64{ null, null, null };
    readTimings(testing.allocator,
        \\{"name":"a.test.two","index":1,"status":"PASS","duration_ms":12.500}
        \\not json
        \\{"name":"gone.test","duration_ms":3.000}
        \\{"name":"a.test.one","duration_ms":0.250,"seed":"0x1"}
    , &index_of, &out);
    try testing.expectEqual(@as(?u64, 250_000), out[0]);
    try testing.expectEqual(@as(?u64, 12_500_000), out[1]);
    try testing.expectEqual(@as(?u64, null), out[2]);
}

test "json strings escape quotes, backslashes and control characters" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try writeJsonString(&aw.writer, "a\"b\\c\nd\x01");
    try testing.expectEqualStrings("\"a\\\"b\\\\c\\nd\\u0001\"", aw.written());
}

test "a result line carries the verdict, the runs, the batch and the seed" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var rec: sched.TestRecord = .{ .batch = 3, .position = 4, .first = .fail, .ran = true, .ns = 12_500_000, .verdict = .order_dependent, .replay = .fail };
    rec.alone[0] = .pass;
    rec.alone[1] = .pass;
    rec.alone_len = 2;
    try writeLine(&aw.writer, "css.x_test.test.it \"works\"", 12, &rec, 0x1f);
    try testing.expectEqualStrings(
        "{\"name\":\"css.x_test.test.it \\\"works\\\"\",\"index\":12,\"status\":\"ORDER-DEPENDENT\",\"first\":\"fail\"," ++
            "\"alone\":[\"pass\",\"pass\"],\"replay\":\"fail\",\"batch\":3,\"position\":4,\"seed\":\"0x1f\",\"duration_ms\":12.500}\n",
        aw.written(),
    );
    // Every line is valid JSON.
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, aw.written(), .{});
    defer parsed.deinit();
    try testing.expectEqualStrings("ORDER-DEPENDENT", parsed.value.object.get("status").?.string);
}
