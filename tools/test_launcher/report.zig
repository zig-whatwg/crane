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
    if (rec.cause.len != 0) {
        try w.writeAll(",\"cause\":");
        try writeJsonString(w, std.mem.trimEnd(u8, rec.cause, "\n"));
    }
    try w.print(",\"batch\":{d},\"position\":{d},\"seed\":\"0x{x}\",\"duration_ms\":{d}.{d:0>3}}}\n", .{
        rec.batch, rec.position, seed, rec.ns / std.time.ns_per_ms, (rec.ns / std.time.ns_per_us) % 1000,
    });
}

/// A test that did not pass, for a person: its verdict, name, how its first
/// run ended, where it ran (batch, position, seed), its alone runs and its
/// prefix replay, then the end of its output.
///
///   FAIL css.x_test.test.it (first run: fail, batch 3 position 4, seed 0x1f; alone: fail fail)
///
/// A test the launcher could not start says so instead, and names why:
///
///   LAUNCHER-ERROR x.test.it (not run: the launcher could not start its process, batch 0 position 4, seed 0x1f)
///   launcher: could not start the test process: could not spawn ...
pub fn writeVerdictBlock(w: *std.Io.Writer, name: []const u8, rec: *const sched.TestRecord, seed: u64) std.Io.Writer.Error!void {
    if (rec.first == .launcher_error) {
        try w.print("{s} {s} (not run: the launcher could not start its process, batch {d} position {d}, seed 0x{x})\n{s}\n", .{
            rec.verdict.label(), name, rec.batch, rec.position, seed, std.mem.trimEnd(u8, rec.cause, "\n"),
        });
        return;
    }
    try w.print("{s} {s} (first run: {t}, batch {d} position {d}, seed 0x{x}; alone:", .{
        rec.verdict.label(), name, rec.first, rec.batch, rec.position, seed,
    });
    for (rec.aloneRuns()) |s| try w.print(" {t}", .{s});
    if (rec.replay) |s| try w.print("; after the tests before it in its process (from position {d}): {t}", .{ rec.process_start, s });
    try w.writeAll(")\n");
    if (rec.cause.len != 0) try w.print("{s}\n", .{std.mem.trimEnd(u8, rec.cause, "\n")});
    try writeOutputExcerpt(w, rec.output);
}

/// Lines of a test's output a verdict block shows: its last `tail_lines`,
/// and, when a crash report starts above them, that report's first
/// `crash_head_lines`.
const tail_lines = 40;
const crash_head_lines = 20;

/// What a verdict block shows of a test's output: its end, and the start of
/// the crash report that ended it when that is above the end - the panic
/// message or the signal, and the frames nearest it, which name the cause.
/// The end alone lost them: a panic 44 lines above the end of a shuffled
/// tests-v8 process's output kept only its frames from gc.onObjectFreed
/// down, and a test's own hook panicking on `current.?` was read as a
/// crash in the wrapper cache (lane crashes7: workerteardown1_global_last_test).
fn writeOutputExcerpt(w: *std.Io.Writer, output: []const u8) std.Io.Writer.Error!void {
    const tail = lastLines(output, tail_lines);
    if (tail.len == 0) return;
    const tail_at = @intFromPtr(tail.ptr) - @intFromPtr(output.ptr);
    if (lastCrashStart(output[0..tail_at])) |at| {
        const head = firstLines(output[at..tail_at], crash_head_lines);
        try w.print("{s}\n", .{std.mem.trimEnd(u8, head, "\n")});
        // Lines between the two are left out, and the block says so.
        if (at + head.len < tail_at) try w.writeAll("...\n");
    }
    try w.print("{s}\n", .{tail});
}

/// Where the last crash report in `s` begins: a line Zig's panic or signal
/// handler starts one with (`thread N panic: `, `Segmentation fault at
/// address`, ...), or ThreadSanitizer's. The last one, since a process
/// ends at its crash and earlier tests of its batch may print panics they
/// expect.
fn lastCrashStart(s: []const u8) ?usize {
    var found: ?usize = null;
    var start: usize = 0;
    while (start < s.len) {
        const end = std.mem.indexOfScalarPos(u8, s, start, '\n') orelse s.len;
        if (startsCrash(s[start..end])) found = start;
        start = end + 1;
    }
    return found;
}

fn startsCrash(line: []const u8) bool {
    if (std.mem.startsWith(u8, line, "WARNING: ThreadSanitizer:")) return true;
    var rest = line;
    // Zig names the thread first: "thread 136140834 panic: ...".
    if (std.mem.startsWith(u8, rest, "thread ")) {
        var i: usize = "thread ".len;
        while (i < rest.len and std.ascii.isDigit(rest[i])) i += 1;
        if (i == "thread ".len or i == rest.len or rest[i] != ' ') return false;
        rest = rest[i + 1 ..];
    }
    const starts = [_][]const u8{ "panic: ", "Segmentation fault at address", "Bus error at address", "Illegal instruction at address" };
    for (starts) |prefix| if (std.mem.startsWith(u8, rest, prefix)) return true;
    return false;
}

/// The first `n` lines of `s`, each with its newline.
fn firstLines(s: []const u8, n: usize) []const u8 {
    var count: usize = 0;
    for (s, 0..) |c, i| {
        if (c != '\n') continue;
        count += 1;
        if (count == n) return s[0 .. i + 1];
    }
    return s;
}

/// The tests the launcher could not run, once per run, grouped by cause:
/// what fails the run when a test process could not be started. Each cause
/// is one line in the build runner's own form, `error: '<step>' failed:`,
/// naming the suite's step (never a test: none failed), the path and the
/// errno - the line gate scripts grep for (tmp/remote/gate-main.sh:
/// `^error: '`), so a run whose skipped tests hide a launcher failure never
/// reads green. The tests it hit follow, indented.
///
///   error: 'test tests-x' failed: LAUNCHER-ERROR, 3 tests not run (the launcher failed, not them): launcher: could not start the test process: could not take a test-process slot, /c/test-launcher-slots/slot-0: FileNotFound (ENOENT)
///       x.test.one
///       ...
pub fn writeLauncherErrors(w: *std.Io.Writer, gpa: std.mem.Allocator, suite: []const u8, names: []const []const u8, records: []const sched.TestRecord) !void {
    const Cause = struct { text: []const u8, count: u32 = 0, first: [max_named]u32 = undefined };
    var causes: std.ArrayList(Cause) = .empty;
    defer causes.deinit(gpa);
    for (records, 0..) |*rec, t| {
        if (rec.verdict != .launcher_error) continue;
        const text = std.mem.trimEnd(u8, rec.cause, "\n");
        const c = for (causes.items) |*c| {
            if (std.mem.eql(u8, c.text, text)) break c;
        } else c: {
            try causes.append(gpa, .{ .text = text });
            break :c &causes.items[causes.items.len - 1];
        };
        if (c.count < max_named) c.first[c.count] = @intCast(t);
        c.count += 1;
    }
    for (causes.items) |c| {
        try w.print("error: 'test {s}' failed: LAUNCHER-ERROR, {d} test{s} not run (the launcher failed, not {s}): {s}\n", .{
            suite,                                                  c.count, if (c.count == 1) "" else "s", if (c.count == 1) "it" else "them",
            if (c.text.len != 0) c.text else "(no cause recorded)",
        });
        for (c.first[0..@min(c.count, max_named)]) |t| try w.print("      {s}\n", .{names[t]});
        if (c.count > max_named) try w.print("      and {d} more\n", .{c.count - max_named});
    }
}

/// Tests named per cause in `writeLauncherErrors`.
const max_named = 5;

/// The last `n` lines of `s`: the end of a test's output (`writeOutputExcerpt`).
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

/// A panic's trace of `frames` frames under its message, as Zig prints one:
/// three lines a frame (where, the source line, the caret).
fn panicTrace(buf: []u8, frames: usize) []const u8 {
    var w: std.Io.Writer = .fixed(buf);
    w.writeAll("thread 1 panic: attempt to use null value\n") catch unreachable;
    for (0..frames) |i| w.print("/src/f{d}.zig:1:1: 0x1 in f{d} (t)\n    f{d}();\n    ^\n", .{ i, i, i }) catch unreachable;
    return w.buffered();
}

test "a crash whose trace is longer than the tail: its block keeps the panic and the frames nearest it" {
    // Lane crashes7: workerteardown1's hook panicked on `current.?` 44 lines
    // above the end of its process's output, so a block of the last 40 lines
    // began at the third frame - gc.onObjectFreed - and the panic and the
    // hook that raised it were read as a crash in the wrapper cache.
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var buf: [4096]u8 = undefined;
    const trace = panicTrace(&buf, 15);
    var output: [4096]u8 = undefined;
    const prefix = "an earlier test's line\n";
    @memcpy(output[0..prefix.len], prefix);
    @memcpy(output[prefix.len..][0..trace.len], trace);
    var rec: sched.TestRecord = .{ .batch = 0, .position = 1118, .first = .crash, .ran = true, .verdict = .flaky, .output = output[0 .. prefix.len + trace.len] };
    rec.alone[0] = .pass;
    rec.alone_len = 1;
    try writeVerdictBlock(&aw.writer, "x.test.hooked", &rec, 0x171a);
    const block = aw.written();
    // The panic and the frame that raised it, then the rest of the trace -
    // every line of it once, none lost between the two.
    try testing.expect(std.mem.indexOf(u8, block, "thread 1 panic: attempt to use null value\n/src/f0.zig:1:1: 0x1 in f0 (t)\n") != null);
    try testing.expect(std.mem.indexOf(u8, block, "f14();\n    ^\n") != null);
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, block, "in f1 (t)"));
    try testing.expect(std.mem.indexOf(u8, block, "\n...\n") == null);
    // What came before the crash is not the crash's.
    try testing.expect(std.mem.indexOf(u8, block, "an earlier test's line") == null);
}

test "a crash far above the end of the output: its first lines, a gap, then the end" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var buf: [16384]u8 = undefined;
    const trace = panicTrace(&buf, 60);
    var rec: sched.TestRecord = .{ .batch = 0, .position = 3, .first = .crash, .ran = true, .verdict = .fail, .output = @constCast(trace) };
    rec.alone[0] = .crash;
    rec.alone_len = 1;
    try writeVerdictBlock(&aw.writer, "x.test.deep", &rec, 0x3);
    const block = aw.written();
    try testing.expect(std.mem.indexOf(u8, block, "thread 1 panic: attempt to use null value\n/src/f0.zig") != null);
    try testing.expect(std.mem.indexOf(u8, block, "\n...\n") != null);
    try testing.expect(std.mem.indexOf(u8, block, "in f30 (t)") == null);
    try testing.expect(std.mem.indexOf(u8, block, "f59();\n    ^\n") != null);
}

test "the crash that ends the output is the one shown: a signal, or a sanitizer's report" {
    inline for (.{ "Segmentation fault at address 0x10", "Bus error at address 0x8", "Illegal instruction at address 0x4", "WARNING: ThreadSanitizer: data race (pid=1)" }) |first| {
        var aw: std.Io.Writer.Allocating = .init(testing.allocator);
        defer aw.deinit();
        var output: [8192]u8 = undefined;
        var w: std.Io.Writer = .fixed(&output);
        // An earlier test's expected panic, long before the crash.
        try w.writeAll("thread 2 panic: an expected one\n");
        for (0..50) |i| try w.print("line {d}\n", .{i});
        try w.print("{s}\n", .{first});
        for (0..60) |i| try w.print("frame {d}\n", .{i});
        var rec: sched.TestRecord = .{ .batch = 0, .position = 9, .first = .crash, .ran = true, .verdict = .fail, .output = w.buffered() };
        rec.alone[0] = .crash;
        rec.alone_len = 1;
        try writeVerdictBlock(&aw.writer, "x.test.signal", &rec, 0x9);
        const block = aw.written();
        try testing.expect(std.mem.indexOf(u8, block, first ++ "\nframe 0\n") != null);
        try testing.expect(std.mem.indexOf(u8, block, "an expected one") == null);
        try testing.expect(std.mem.indexOf(u8, block, "frame 59") != null);
    }
}

test "output with no crash in it, or one inside the end: the end alone, as before" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var output: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&output);
    for (0..100) |i| try w.print("line {d}\n", .{i});
    var rec: sched.TestRecord = .{ .batch = 0, .position = 0, .first = .fail, .ran = true, .verdict = .fail, .output = w.buffered() };
    try writeVerdictBlock(&aw.writer, "x.test.plain", &rec, 0x1);
    const expected = try std.fmt.allocPrint(testing.allocator, "FAIL x.test.plain (first run: fail, batch 0 position 0, seed 0x1; alone:)\n{s}\n", .{lastLines(w.buffered(), 40)});
    defer testing.allocator.free(expected);
    try testing.expectEqualStrings(expected, aw.written());

    // A crash inside the last 40 lines is shown by the end alone.
    aw.clearRetainingCapacity();
    w = .fixed(&output);
    for (0..100) |i| try w.print("line {d}\n", .{i});
    try w.writeAll("thread 1 panic: near the end\n");
    for (0..10) |i| try w.print("frame {d}\n", .{i});
    rec.output = w.buffered();
    try writeVerdictBlock(&aw.writer, "x.test.plain", &rec, 0x1);
    const expected_near = try std.fmt.allocPrint(testing.allocator, "FAIL x.test.plain (first run: fail, batch 0 position 0, seed 0x1; alone:)\n{s}\n", .{lastLines(w.buffered(), 40)});
    defer testing.allocator.free(expected_near);
    try testing.expectEqualStrings(expected_near, aw.written());
}

test "a test the launcher could not start: its block says it did not run, and why" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var cause = "launcher: could not start the test process: could not spawn /x/t: FileNotFound (ENOENT); it is not there now\n".*;
    const rec: sched.TestRecord = .{ .batch = 0, .position = 4, .first = .launcher_error, .ran = true, .verdict = .launcher_error, .cause = &cause };
    try writeVerdictBlock(&aw.writer, "x.test.it", &rec, 0x1f);
    try testing.expectEqualStrings(
        "LAUNCHER-ERROR x.test.it (not run: the launcher could not start its process, batch 0 position 4, seed 0x1f)\n" ++
            "launcher: could not start the test process: could not spawn /x/t: FileNotFound (ENOENT); it is not there now\n",
        aw.written(),
    );
}

test "a failure whose classification the launcher could not finish: its runs, the cause, then its output" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var cause = "launcher: could not start the test process: no slot\n".*;
    var output = "expected 1, found 2\n".*;
    var rec: sched.TestRecord = .{ .batch = 1, .position = 2, .first = .fail, .ran = true, .verdict = .launcher_error, .cause = &cause, .output = &output };
    rec.alone[0] = .launcher_error;
    rec.alone_len = 1;
    try writeVerdictBlock(&aw.writer, "x.test.it", &rec, 0x2);
    try testing.expectEqualStrings(
        "LAUNCHER-ERROR x.test.it (first run: fail, batch 1 position 2, seed 0x2; alone: launcher_error)\n" ++
            "launcher: could not start the test process: no slot\nexpected 1, found 2\n",
        aw.written(),
    );
}

test "the launcher errors of a run, once, grouped by cause, with the tests they hit" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var slot_cause = "launcher: could not start the test process: could not take a test-process slot, /c/slot-0: FileNotFound (ENOENT)\n".*;
    var spawn_cause = "launcher: could not start the test process: could not spawn /x/t: FileBusy (ETXTBSY); it is there now\n".*;
    const names = [_][]const u8{ "s.test.0", "s.test.1", "s.test.2", "s.test.3", "s.test.4", "s.test.5", "s.test.6", "s.test.7", "s.test.8" };
    var records: [names.len]sched.TestRecord = @splat(.{ .verdict = .pass });
    for (0..7) |t| records[t] = .{ .first = .launcher_error, .verdict = .launcher_error, .cause = &slot_cause };
    records[8] = .{ .first = .launcher_error, .verdict = .launcher_error, .cause = &spawn_cause };
    try writeLauncherErrors(&aw.writer, testing.allocator, "tests-s", &names, &records);
    try testing.expectEqualStrings(
        "error: 'test tests-s' failed: LAUNCHER-ERROR, 7 tests not run (the launcher failed, not them): launcher: could not start the test process: could not take a test-process slot, /c/slot-0: FileNotFound (ENOENT)\n" ++
            "      s.test.0\n      s.test.1\n      s.test.2\n      s.test.3\n      s.test.4\n      and 2 more\n" ++
            "error: 'test tests-s' failed: LAUNCHER-ERROR, 1 test not run (the launcher failed, not it): launcher: could not start the test process: could not spawn /x/t: FileBusy (ETXTBSY); it is there now\n" ++
            "      s.test.8\n",
        aw.written(),
    );
    // What the gate scripts grep finds every cause, and nothing else.
    var it = std.mem.splitScalar(u8, aw.written(), '\n');
    var gate_lines: u32 = 0;
    while (it.next()) |line| {
        if (std.mem.startsWith(u8, line, "error: '")) gate_lines += 1;
    }
    try testing.expectEqual(@as(u32, 2), gate_lines);
    // None: nothing printed.
    var clean: std.Io.Writer.Allocating = .init(testing.allocator);
    defer clean.deinit();
    try writeLauncherErrors(&clean.writer, testing.allocator, "tests-s", &names, records[7..8]);
    try testing.expectEqual(@as(usize, 0), clean.written().len);
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

test "a LAUNCHER-ERROR result line carries its cause" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var cause = "launcher: could not start the test process: no slot\n".*;
    const rec: sched.TestRecord = .{ .first = .launcher_error, .ran = true, .verdict = .launcher_error, .cause = &cause };
    try writeLine(&aw.writer, "x.test.it", 0, &rec, 0x1);
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, aw.written(), .{});
    defer parsed.deinit();
    try testing.expectEqualStrings("LAUNCHER-ERROR", parsed.value.object.get("status").?.string);
    try testing.expectEqualStrings("launcher_error", parsed.value.object.get("first").?.string);
    try testing.expectEqualStrings("launcher: could not start the test process: no slot", parsed.value.object.get("cause").?.string);
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
