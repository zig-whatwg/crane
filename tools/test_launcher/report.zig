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

const testing = std.testing;

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
