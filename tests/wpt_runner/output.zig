//! Buffered, thread-safe display output for the WPT runner.
//!
//! The runner prints one line per subtest. That is not a small number: a single
//! run of `encoding/` emitted 948,845 such lines, and the worst individual file
//! (`legacy-mb-korean/euckr-encode-href-errors-han.html`) accounts for roughly
//! 11,000 of them on its own. Routing those through `std.debug.print` costs one
//! lock acquisition and one `write(2)` per line.
//!
//! Measured on this machine, at 11,183 lines:
//!
//!   1 process,  stderr -> file    6.57us/line
//!   8 processes sharing that fd  47.97us/line
//!
//! `--parallel=N` shards inherit a single stderr, so those writes serialize
//! against each other in the kernel, and the per-line cost rises ~7x going from
//! one process to eight.
//!
//! That did NOT translate into a faster run, and the microbenchmark above
//! should not be read as though it did. Measured end to end on `encoding/` at
//! `--parallel=8`, same corpus and same redirection:
//!
//!   unbuffered  789s
//!   buffered    824s
//!
//! Outcomes were equivalent (one flaky crash flipped to OK; 3 subtests of
//! 775,000 differed), so the difference is run-to-run variance, not a
//! regression - but it is emphatically not a win either. The syscalls overlap
//! with page fetches, V8 work and timeout waits, so taking them off the
//! critical path buys nothing measurable. A run of this corpus spends its time
//! elsewhere: 43 of 149 files time out and 19 crash, and each crash costs a
//! full supervisor restart.
//!
//! This module is therefore justified on correctness, not speed. `std.debug.print`
//! is disallowed for runner output by project convention, and the mutex here
//! replaces the global stderr lock that convention was implicitly relying on to
//! keep two shards from interleaving mid-line.
//!
//! Buffering removes the syscall from the per-line path. It does not remove it
//! from the per-file path: `Sink.flush` is called once a test file's results are
//! reported, and again before a child is spawned or the process exits. That
//! boundary is deliberate. `journal.zig` documents why its own records are
//! written straight through - identifying a test that segfaulted depends on the
//! record before it having reached the disk - and the same reasoning applies to
//! anything a human reads after a crash. Flushing per file keeps that property
//! at file granularity, which is the granularity the journal already restarts
//! at, while still collapsing ~11,000 syscalls into one.
//!
//! `Sink` takes a mutex because `runShard` runs each shard on its own thread and
//! all of them print. `std.debug.print` locked stderr globally; dropping that
//! lock without replacing it would let two shards interleave mid-line.

const std = @import("std");

/// A buffered sink that serializes whole writes against each other.
///
/// The buffer belongs to `w`, not to this type - construct `w` with whatever
/// capacity is appropriate and pass a pointer to its interface.
pub const Sink = struct {
    w: *std.Io.Writer,
    mutex: std.Io.Mutex = .init,

    /// Formats and buffers one write.
    ///
    /// Display output is not worth failing a run over: if the terminal or pipe
    /// has gone away there is nothing useful to do about it and no caller that
    /// could act on it, so a write error is dropped. Anything that must survive
    /// goes through `journal.zig` instead.
    pub fn print(self: *Sink, comptime fmt: []const u8, args: anytype) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.w.print(fmt, args) catch {};
    }

    /// Pushes everything buffered so far to the underlying sink.
    pub fn flush(self: *Sink) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.w.flush() catch {};
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// A `std.Io.Writer` that records what it was handed and how many times it was
/// asked to drain. The drain count is the whole point of this module, so the
/// tests assert on it directly rather than on elapsed time.
const Counting = struct {
    interface: std.Io.Writer,
    drains: usize = 0,
    seen: std.ArrayList(u8) = .empty,
    allocator: std.mem.Allocator,

    const vtable: std.Io.Writer.VTable = .{ .drain = drain };

    fn init(allocator: std.mem.Allocator, buffer: []u8) Counting {
        return .{
            .interface = .{ .vtable = &vtable, .buffer = buffer },
            .allocator = allocator,
        };
    }

    fn deinit(self: *Counting) void {
        self.seen.deinit(self.allocator);
    }

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *Counting = @fieldParentPtr("interface", w);
        self.drains += 1;

        // Buffered bytes are consumed first, and do not count toward the return.
        self.seen.appendSlice(self.allocator, w.buffer[0..w.end]) catch return error.WriteFailed;
        w.end = 0;

        var consumed: usize = 0;
        for (data[0 .. data.len - 1]) |d| {
            self.seen.appendSlice(self.allocator, d) catch return error.WriteFailed;
            consumed += d.len;
        }
        const last = data[data.len - 1];
        for (0..splat) |_| {
            self.seen.appendSlice(self.allocator, last) catch return error.WriteFailed;
        }
        consumed += last.len * splat;
        return consumed;
    }
};

test "a sink drains once per flush, not once per line" {
    const allocator = std.testing.allocator;

    var buffer: [64 * 1024]u8 = undefined;
    var counting = Counting.init(allocator, &buffer);
    defer counting.deinit();

    var sink = Sink{ .w = &counting.interface };

    // The shape and volume the runner actually produces for one heavy file.
    const lines = 11_183;
    for (0..lines) |i| {
        sink.print("  |-- OK subtest {d}\n", .{i});
    }
    sink.flush();

    // Every line landed...
    try std.testing.expect(counting.seen.items.len > 0);
    try std.testing.expectEqual(
        @as(usize, lines),
        std.mem.count(u8, counting.seen.items, "\n"),
    );

    // ...but nowhere near one syscall per line. 64KiB holds many lines, so the
    // count is bounded by total bytes / buffer size, plus one for the flush.
    const bound = counting.seen.items.len / buffer.len + 2;
    try std.testing.expect(counting.drains <= bound);
    try std.testing.expect(counting.drains < lines / 100);
}

test "buffered output preserves every byte and its order" {
    const allocator = std.testing.allocator;

    var buffer: [64]u8 = undefined; // small on purpose: forces real drains
    var counting = Counting.init(allocator, &buffer);
    defer counting.deinit();

    var sink = Sink{ .w = &counting.interface };

    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);

    for (0..500) |i| {
        sink.print("  |-- {d} {s}\n", .{ i, "cjk U+4E00" });
        try expected.print(allocator, "  |-- {d} {s}\n", .{ i, "cjk U+4E00" });
    }
    sink.flush();

    try std.testing.expectEqualStrings(expected.items, counting.seen.items);
}

test "a single write larger than the buffer is not truncated" {
    const allocator = std.testing.allocator;

    var buffer: [16]u8 = undefined;
    var counting = Counting.init(allocator, &buffer);
    defer counting.deinit();

    var sink = Sink{ .w = &counting.interface };

    // Stack traces and failure messages routinely exceed any fixed buffer.
    const long = "x" ** 4096;
    sink.print("  |      {s}\n", .{long});
    sink.flush();

    // 9-byte prefix + 4096 payload + newline
    try std.testing.expectEqual(@as(usize, 9 + 4096 + 1), counting.seen.items.len);
    try std.testing.expectEqualStrings("  |      ", counting.seen.items[0..9]);
    try std.testing.expectEqual(@as(u8, '\n'), counting.seen.items[counting.seen.items.len - 1]);
}

test "flush on an empty sink is harmless and repeatable" {
    const allocator = std.testing.allocator;

    var buffer: [1024]u8 = undefined;
    var counting = Counting.init(allocator, &buffer);
    defer counting.deinit();

    var sink = Sink{ .w = &counting.interface };
    sink.flush();
    sink.flush();

    try std.testing.expectEqual(@as(usize, 0), counting.seen.items.len);
}

test "concurrent shards do not interleave within a line" {
    const allocator = std.testing.allocator;

    var buffer: [8 * 1024]u8 = undefined;
    var counting = Counting.init(allocator, &buffer);
    defer counting.deinit();

    var sink = Sink{ .w = &counting.interface };

    // Each shard writes lines made of a single repeated character, so any
    // interleaving inside a line shows up as a line with mixed characters.
    const shards = 8;
    const per_shard = 200;

    const Worker = struct {
        fn run(s: *Sink, id: usize) void {
            const glyph: u8 = @intCast('a' + id);
            var line: [64]u8 = undefined;
            @memset(&line, glyph);
            for (0..per_shard) |_| {
                s.print("{s}\n", .{line[0..]});
            }
        }
    };

    var threads: [shards]std.Thread = undefined;
    for (0..shards) |i| {
        threads[i] = try std.Thread.spawn(.{}, Worker.run, .{ &sink, i });
    }
    for (threads) |t| t.join();
    sink.flush();

    var it = std.mem.splitScalar(u8, counting.seen.items, '\n');
    var lines: usize = 0;
    while (it.next()) |line| {
        if (line.len == 0) continue;
        lines += 1;
        try std.testing.expectEqual(@as(usize, 64), line.len);
        for (line) |c| try std.testing.expectEqual(line[0], c);
    }
    try std.testing.expectEqual(@as(usize, shards * per_shard), lines);
}
