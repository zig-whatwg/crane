//! The WPT runner's allocators, pinned so they behave the same in every build
//! mode the runner is built in.
//!
//! The runner builds ReleaseSafe by default and Debug on request
//! (`-Dwpt-runner-optimize=Debug`; tests/wpt_runner/build_mode.zig), and what a
//! run reports must not depend on which.
//!
//! `std.heap.DebugAllocator`'s defaults do depend on it:
//!
//! - `safety` defaults to `std.debug.runtime_safety`: true in Debug and
//!   ReleaseSafe, false in ReleaseFast. It gates double-free detection
//!   ("Double free detected", the line sweep logs are grepped for) and the leak
//!   report at `deinit`. Pinned to true here, so neither can vanish with a mode.
//! - `stack_trace_frames` defaults to 6 in Debug and 0 in every release mode.
//!   The fast allocator wants 0 in every mode (see `Fast`); the traced one
//!   (`CRANE_LEAK_TRACES=1`) exists for its traces, and a ReleaseSafe runner
//!   would otherwise give it none.
//!
//! std-only, so `zig build test` runs these tests (main.zig links V8 and never
//! runs its own).

const std = @import("std");

/// The sweep allocator: leak and double-free DETECTION, no per-operation
/// stack capture.
///
/// A DebugAllocator that captures a trace per allocation and per free made a
/// two-subtest page take 37 seconds to exit: Zig 0.16's unwinder parses DWARF
/// CFI byte by byte for every capture, and tearing down one page frees
/// hundreds of thousands of objects
/// (docs/lessons/debugging-a-two-subtest-page-took-37-seconds-to-exit-and.md).
/// Zero frames keeps the count and the addresses of every leak and every
/// double free.
pub const fast_config: std.heap.DebugAllocatorConfig = .{
    .stack_trace_frames = 0,
    .safety = true,
};

/// `CRANE_LEAK_TRACES=1`: the same checks with six-frame traces, for the run
/// where the traces are the point (they named the setTimeoutCallback and
/// ProgressEvent leaks, and the two frees of every double free since).
pub const traced_config: std.heap.DebugAllocatorConfig = .{
    .stack_trace_frames = 6,
    .safety = true,
};

pub const Fast = std.heap.DebugAllocator(fast_config);
pub const Traced = std.heap.DebugAllocator(traced_config);

/// Whether `CRANE_LEAK_TRACES` asks for the traced allocator: set, non-empty,
/// and not starting with '0'.
pub fn wantsTraces(value: ?[]const u8) bool {
    const v = value orelse return false;
    return v.len != 0 and v[0] != '0';
}

/// Whether per-file leak attribution (`Attributing`) is on without
/// `CRANE_LEAK_FILES`: a sweep's `leaked:` lines then name their files with
/// no flag to remember. Measured cost: see the lane leaks6 report.
pub const attribution_by_default = true;

/// Whether `CRANE_LEAK_FILES` asks for per-file leak attribution: unset is
/// `attribution_by_default`; set, it is on unless it starts with '0'.
pub fn wantsAttribution(value: ?[]const u8) bool {
    const v = value orelse return attribution_by_default;
    return !(v.len != 0 and v[0] == '0');
}

/// What a `CRANE_LEAK_TRACES=1` run in an optimized runner must say first, or
/// null. DebugAllocator starts a trace at the allocator's caller
/// (`@returnAddress()` in std.mem.Allocator's alloc/dupe), and in an
/// optimized build those are inlined into Crane's code, which is inlined into
/// the binding callback: the trace starts at a return address above the
/// allocation site - in V8's builtins, where the unwinder repeats one frame -
/// and names nothing. Measured on FileAPI/FileReaderSync.worker.js (6 leaks
/// in both modes): Debug names packageData and the FileReaderSync member,
/// ReleaseSafe six frames of _Builtins_CallApiCallbackGeneric. The counts are
/// the same in every mode; only the traces need the Debug runner.
pub fn tracesNote(mode: std.builtin.OptimizeMode, want_traces: bool) ?[]const u8 {
    if (!want_traces or mode == .Debug) return null;
    return "CRANE_LEAK_TRACES in an optimized runner: inlined allocations are traced from their callers' return addresses and the traces name no allocation site; build the Debug runner (-Dwpt-runner-optimize=Debug) for traces. Leak and double-free reports are complete in every mode.";
}

/// Error-level reports DebugAllocator has logged in this process (a double
/// free, an invalid free, each leaked address at deinit). DebugAllocator logs
/// and carries on, so this count is the only trace of a report besides the log
/// line itself; the runner's log function feeds it (`noteLog`).
var reports: std.atomic.Value(usize) = .init(0);

/// Called by the runner's `std_options.logFn` for every message it logs.
pub fn noteLog(comptime level: std.log.Level, comptime scope: @TypeOf(.enum_literal)) void {
    if (level == .err and scope == .DebugAllocator) _ = reports.fetchAdd(1, .monotonic);
}

pub fn reportCount() usize {
    return reports.load(.monotonic);
}

/// Per-file leak attribution: which test file was running when each
/// allocation still live at the run's end was made.
///
/// A shard process runs many files in one Browser (one isolate), so its
/// DebugAllocator's `leaked:` reports, printed when the run ends, name no file
/// (docs/lessons/testing-attribute-a-sweep-s-leak-reports-shard-then-file-then-trace.md).
/// A DebugAllocator per file cannot be had - process and Browser state made
/// during one file is freed during another - and a per-file live count cannot
/// tell a cache that grows on first use from a leak. So this allocator, put
/// in front of the run's DebugAllocator, tags every live allocation with the
/// file running when it was made: a map from address to {file, length}, kept
/// in `std.heap.page_allocator` memory (never the tracked allocator's, so the
/// map neither recurses nor shows in the leak check) under a mutex of its own.
/// At the end, the entries still in the map are exactly the allocations the
/// DebugAllocator is about to report as leaked, grouped by file.
///
/// The charging rule: an allocation is charged to the file named by the last
/// `enterFile` before it, whichever thread makes it. The index changes only
/// at `enterFile`, so a worker-thread allocation made after file k journalled
/// and before k+1 starts is charged to k; one made before the first file is
/// charged to "(before the first file)".
pub const Attributing = struct {
    child: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    live: std.AutoHashMapUnmanaged(usize, Live) = .empty,
    /// Every file entered, copied; index 0 is the time before the first.
    files: std.ArrayListUnmanaged([]const u8) = .empty,
    current: u32 = 0,
    /// Allocations the map could not record (its own memory ran out): the
    /// attributed total then falls short of the DebugAllocator's by this many.
    unrecorded: usize = 0,
    /// Set by `deinit`: from then on allocations pass straight through.
    closed: bool = false,
    /// The map's and the paths' own memory: never the tracked allocator
    /// (the map would record its own growth). page_allocator in the runner;
    /// a test passes a leak-checked one, so `deinit` is checked too.
    meta: std.mem.Allocator = std.heap.page_allocator,
    pub const before_first_file = "(before the first file)";

    const Live = struct {
        file: u32,
        len: usize,
    };

    pub fn init(child: std.mem.Allocator) Attributing {
        return .{ .child = child };
    }

    pub fn allocator(self: *Attributing) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    fn lock(self: *Attributing) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }

    fn unlock(self: *Attributing) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    /// Record `address` as live, made under the current file. Holds the lock.
    fn record(self: *Attributing, address: usize, len: usize) void {
        if (self.closed) return;
        self.live.put(self.meta, address, .{ .file = self.current, .len = len }) catch {
            self.unrecorded += 1;
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *Attributing = @ptrCast(@alignCast(ctx));
        const ptr = self.child.rawAlloc(len, alignment, ret_addr) orelse return null;
        self.lock();
        defer self.unlock();
        self.record(@intFromPtr(ptr), len);
        return ptr;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *Attributing = @ptrCast(@alignCast(ctx));
        if (!self.child.rawResize(memory, alignment, new_len, ret_addr)) return false;
        self.lock();
        defer self.unlock();
        if (self.live.getPtr(@intFromPtr(memory.ptr))) |entry| entry.len = new_len;
        return true;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *Attributing = @ptrCast(@alignCast(ctx));
        const ptr = self.child.rawRemap(memory, alignment, new_len, ret_addr) orelse return null;
        self.lock();
        defer self.unlock();
        // The same allocation, moved: it keeps the file that made it.
        if (self.live.fetchRemove(@intFromPtr(memory.ptr))) |old| {
            if (!self.closed) self.live.put(self.meta, @intFromPtr(ptr), .{ .file = old.value.file, .len = new_len }) catch {
                self.unrecorded += 1;
            };
        }
        return ptr;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *Attributing = @ptrCast(@alignCast(ctx));
        {
            // Off the map before the child frees it: once freed, another
            // thread's allocation may be given the same address.
            self.lock();
            defer self.unlock();
            _ = self.live.remove(@intFromPtr(memory.ptr));
        }
        self.child.rawFree(memory, alignment, ret_addr);
    }

    /// From now on, allocations are charged to `path` (copied). Entering the
    /// file already current changes nothing.
    pub fn enterFile(self: *Attributing, path: []const u8) void {
        self.lock();
        defer self.unlock();
        if (self.closed) return;
        if (self.current != 0 and std.mem.eql(u8, self.files.items[self.current], path)) return;
        if (self.files.items.len == 0) self.files.append(self.meta, before_first_file) catch return;
        const copy = self.meta.dupe(u8, path) catch return;
        self.files.append(self.meta, copy) catch {
            self.meta.free(copy);
            return;
        };
        self.current = @intCast(self.files.items.len - 1);
    }

    /// The file allocations are charged to now. Valid until `deinit`.
    pub fn currentFile(self: *Attributing) []const u8 {
        self.lock();
        defer self.unlock();
        if (self.current == 0) return before_first_file;
        return self.files.items[self.current];
    }

    pub const FileLeaks = struct {
        /// Valid until `deinit`.
        path: []const u8,
        count: usize,
        bytes: usize,
    };

    pub const Summary = struct {
        /// Most allocations first; `allocator`'s, freed with `freeSummary`.
        files: []FileLeaks,
        count: usize,
        bytes: usize,
        unrecorded: usize,
    };

    /// The allocations still live, grouped by the file that made them. Made
    /// with `out` - the caller must not pass this allocator.
    pub fn summarize(self: *Attributing, out: std.mem.Allocator) error{OutOfMemory}!Summary {
        self.lock();
        defer self.unlock();
        const slots = @max(self.files.items.len, 1);
        const per_file = try out.alloc(FileLeaks, slots);
        defer out.free(per_file);
        for (per_file, 0..) |*f, i| f.* = .{
            .path = if (i == 0) before_first_file else self.files.items[i],
            .count = 0,
            .bytes = 0,
        };
        var count: usize = 0;
        var bytes: usize = 0;
        var it = self.live.valueIterator();
        while (it.next()) |entry| {
            per_file[entry.file].count += 1;
            per_file[entry.file].bytes += entry.len;
            count += 1;
            bytes += entry.len;
        }
        var nonzero: usize = 0;
        for (per_file) |f| {
            if (f.count != 0) nonzero += 1;
        }
        const files = try out.alloc(FileLeaks, nonzero);
        var i: usize = 0;
        for (per_file) |f| {
            if (f.count == 0) continue;
            files[i] = f;
            i += 1;
        }
        std.mem.sort(FileLeaks, files, {}, struct {
            fn more(_: void, a: FileLeaks, b: FileLeaks) bool {
                if (a.count != b.count) return a.count > b.count;
                return std.mem.lessThan(u8, a.path, b.path);
            }
        }.more);
        return .{ .files = files, .count = count, .bytes = bytes, .unrecorded = self.unrecorded };
    }

    pub fn freeSummary(out: std.mem.Allocator, summary: Summary) void {
        out.free(summary.files);
    }

    /// Free the map and the copied paths. Allocations made afterwards pass
    /// straight through, unrecorded; frees still reach the child.
    pub fn deinit(self: *Attributing) void {
        self.lock();
        defer self.unlock();
        self.live.deinit(self.meta);
        self.live = .empty;
        if (self.files.items.len > 0) {
            for (self.files.items[1..]) |path| self.meta.free(path);
        }
        self.files.deinit(self.meta);
        self.files = .empty;
        self.current = 0;
        self.closed = true;
    }
};

/// What the runner prints before its DebugAllocator's leak reports: one line
/// per file that made an allocation still live, most first, then the total
/// (`leaked-by-file: total N ...`), which must equal the number of `leaked:`
/// lines that follow. Nothing when nothing is live.
pub fn printLeaksByFile(summary: Attributing.Summary, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    if (summary.count == 0 and summary.unrecorded == 0) return;
    for (summary.files) |f| {
        try writer.print("leaked-by-file: {d} allocations, {d} B, allocated while running {s}\n", .{ f.count, f.bytes, f.path });
    }
    try writer.print("leaked-by-file: total {d} allocations, {d} B, in {d} files", .{ summary.count, summary.bytes, summary.files.len });
    if (summary.unrecorded != 0) try writer.print(" (and {d} the attribution could not record)", .{summary.unrecorded});
    try writer.writeAll(" - DebugAllocator's leaked: lines follow\n");
}

pub const SelfCheck = struct {
    double_free_reported: bool,
    leak_reported: bool,
    /// Whether the attribution named the seeded leak's file, with the count
    /// the DebugAllocator reported.
    leak_attributed: bool,

    pub fn passed(self: SelfCheck) bool {
        return self.double_free_reported and self.leak_reported and self.leak_attributed;
    }
};

/// Seed one double free and one leak in a private `Fast` allocator and say
/// whether DebugAllocator caught each - `wpt_runner --allocator-self-check`.
///
/// Only meaningful inside the runner, whose log function calls `noteLog`; the
/// reports also reach stderr as "Double free detected" and "memory address ...
/// leaked", which is what a sweep log is grepped for. Not run by the unit
/// tests: the test runner fails any test that logs an error.
pub fn selfCheck() SelfCheck {
    const failed: SelfCheck = .{ .double_free_reported = false, .leak_reported = false, .leak_attributed = false };
    var gpa: Fast = .{};
    // Through the attribution, as the runner allocates.
    var attributing = Attributing.init(gpa.allocator());
    defer attributing.deinit();
    const a = attributing.allocator();

    // A neighbour in the same size class keeps the slot's bucket mapped, so the
    // second free reaches the used-bit check rather than an unmapped page.
    attributing.enterFile("self-check/leaks.html");
    const neighbour = a.create(u64) catch return failed;
    attributing.enterFile("self-check/double-free.html");
    const twice = a.create(u64) catch return failed;
    a.destroy(twice);
    const before = reportCount();
    a.destroy(twice);
    const double_free_reported = reportCount() > before;

    // `neighbour` is never freed: the leak, made while the first file ran.
    _ = neighbour;
    const summary = attributing.summarize(std.heap.page_allocator) catch return failed;
    defer Attributing.freeSummary(std.heap.page_allocator, summary);
    const reports_before = reportCount();
    const leak_reported = gpa.deinit() == .leak;
    const leak_reports = reportCount() - reports_before;
    const leak_attributed = summary.count == leak_reports and summary.files.len == 1 and
        std.mem.eql(u8, summary.files[0].path, "self-check/leaks.html") and summary.files[0].count == 1;
    return .{ .double_free_reported = double_free_reported, .leak_reported = leak_reported, .leak_attributed = leak_attributed };
}

const testing = std.testing;

test "both allocators keep double-free and leak detection in every build mode" {
    // The default is std.debug.runtime_safety, which is false in ReleaseFast:
    // a runner built that way would report no double free and no leak, and
    // every sweep log would read clean. Pinned, not inherited.
    try testing.expect(fast_config.safety);
    try testing.expect(traced_config.safety);
}

test "the fast allocator captures no traces, the traced one six, whatever the mode" {
    // DebugAllocator's default is 6 frames in Debug and 0 in release modes, so
    // inheriting it would make the fast allocator slow in Debug (the 37-second
    // exit) and the traced allocator useless in ReleaseSafe.
    try testing.expectEqual(@as(usize, 0), fast_config.stack_trace_frames);
    try testing.expectEqual(@as(usize, 6), traced_config.stack_trace_frames);
}

test "a clean run deinits clean under the sweep allocator" {
    var gpa: Fast = .{};
    const a = gpa.allocator();
    const bytes = try a.alloc(u8, 64);
    a.free(bytes);
    try testing.expectEqual(std.heap.Check.ok, gpa.deinit());
}

test "an optimized runner says its leak traces name no allocation site; Debug says nothing" {
    try testing.expect(tracesNote(.Debug, true) == null);
    try testing.expect(tracesNote(.ReleaseSafe, false) == null);
    try testing.expect(tracesNote(.ReleaseSafe, true) != null);
    try testing.expect(tracesNote(.ReleaseFast, true) != null);
}

test "CRANE_LEAK_FILES: the default is pinned, and 0 turns it off" {
    try testing.expectEqual(attribution_by_default, wantsAttribution(null));
    try testing.expect(attribution_by_default);
    try testing.expect(!wantsAttribution("0"));
    try testing.expect(wantsAttribution("1"));
    try testing.expect(wantsAttribution(""));
}

test "CRANE_LEAK_TRACES: set and not starting with 0" {
    try testing.expect(!wantsTraces(null));
    try testing.expect(!wantsTraces(""));
    try testing.expect(!wantsTraces("0"));
    try testing.expect(wantsTraces("1"));
    try testing.expect(wantsTraces("yes"));
}

/// A child allocator for the attribution tests: testing.allocator's, with a
/// count of what is live, and a remap that always moves the allocation (so
/// the attribution's move path runs whatever the backing allocator does).
const CountingChild = struct {
    backing: std.mem.Allocator = testing.allocator,
    live: usize = 0,
    bytes: usize = 0,

    fn allocator(self: *CountingChild) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *CountingChild = @ptrCast(@alignCast(ctx));
        const ptr = self.backing.rawAlloc(len, alignment, ret_addr) orelse return null;
        self.live += 1;
        self.bytes += len;
        return ptr;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *CountingChild = @ptrCast(@alignCast(ctx));
        if (!self.backing.rawResize(memory, alignment, new_len, ret_addr)) return false;
        self.bytes = self.bytes - memory.len + new_len;
        return true;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *CountingChild = @ptrCast(@alignCast(ctx));
        const ptr = self.backing.rawAlloc(new_len, alignment, ret_addr) orelse return null;
        @memcpy(ptr[0..@min(memory.len, new_len)], memory[0..@min(memory.len, new_len)]);
        self.backing.rawFree(memory, alignment, ret_addr);
        self.bytes = self.bytes - memory.len + new_len;
        return ptr;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *CountingChild = @ptrCast(@alignCast(ctx));
        self.backing.rawFree(memory, alignment, ret_addr);
        self.live -= 1;
        self.bytes -= memory.len;
    }
};

test "attribution: a live allocation is charged to the file that made it, not the next" {
    var child: CountingChild = .{};
    var attributing = Attributing.init(child.allocator());
    attributing.meta = testing.allocator;
    defer attributing.deinit();
    const a = attributing.allocator();

    const early = try a.alloc(u8, 8);
    attributing.enterFile("dom/a.html");
    const kept = try a.alloc(u8, 100);
    const freed = try a.alloc(u8, 50);
    attributing.enterFile("dom/b.html");
    a.free(freed);
    const other = try a.create(u64);
    // Entering the current file again changes nothing.
    attributing.enterFile("dom/b.html");
    try testing.expectEqualStrings("dom/b.html", attributing.currentFile());

    const summary = try attributing.summarize(testing.allocator);
    defer Attributing.freeSummary(testing.allocator, summary);
    try testing.expectEqual(@as(usize, 3), summary.count);
    try testing.expectEqual(@as(usize, 3), summary.files.len);
    try testing.expectEqualStrings(Attributing.before_first_file, summary.files[0].path);
    try testing.expectEqualStrings("dom/a.html", summary.files[1].path);
    try testing.expectEqual(@as(usize, 100), summary.files[1].bytes);
    try testing.expectEqualStrings("dom/b.html", summary.files[2].path);
    try testing.expectEqual(@as(usize, 8), summary.files[2].bytes);

    a.free(early);
    a.free(kept);
    a.destroy(other);
    const after = try attributing.summarize(testing.allocator);
    defer Attributing.freeSummary(testing.allocator, after);
    try testing.expectEqual(@as(usize, 0), after.count);
    try testing.expectEqual(@as(usize, 0), after.files.len);
}

test "attribution: the most leaking file comes first, and the total is the child's live count" {
    var child: CountingChild = .{};
    var attributing = Attributing.init(child.allocator());
    attributing.meta = testing.allocator;
    defer attributing.deinit();
    const a = attributing.allocator();

    var held: [7][]u8 = undefined;
    attributing.enterFile("one.html");
    held[0] = try a.alloc(u8, 10);
    attributing.enterFile("three.html");
    for (held[1..4]) |*h| h.* = try a.alloc(u8, 20);
    attributing.enterFile("two.html");
    for (held[4..6]) |*h| h.* = try a.alloc(u8, 30);
    attributing.enterFile("(teardown after the last file)");
    held[6] = try a.alloc(u8, 1);
    a.free(held[6]);

    const summary = try attributing.summarize(testing.allocator);
    defer Attributing.freeSummary(testing.allocator, summary);
    try testing.expectEqual(child.live, summary.count);
    try testing.expectEqual(child.bytes, summary.bytes);
    try testing.expectEqual(@as(usize, 0), summary.unrecorded);
    try testing.expectEqualStrings("three.html", summary.files[0].path);
    try testing.expectEqualStrings("two.html", summary.files[1].path);
    try testing.expectEqualStrings("one.html", summary.files[2].path);

    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try printLeaksByFile(summary, &out.writer);
    try testing.expectEqualStrings(
        \\leaked-by-file: 3 allocations, 60 B, allocated while running three.html
        \\leaked-by-file: 2 allocations, 60 B, allocated while running two.html
        \\leaked-by-file: 1 allocations, 10 B, allocated while running one.html
        \\leaked-by-file: total 6 allocations, 130 B, in 3 files - DebugAllocator's leaked: lines follow
        \\
    , out.written());

    for (held[0..6]) |h| a.free(h);
}

test "attribution: a moved allocation keeps its file, a resized one its new length" {
    var child: CountingChild = .{};
    var attributing = Attributing.init(child.allocator());
    attributing.meta = testing.allocator;
    defer attributing.deinit();
    const a = attributing.allocator();

    attributing.enterFile("grows.html");
    var buffer = try a.alloc(u8, 16);
    attributing.enterFile("later.html");
    // CountingChild's remap always moves.
    const moved = a.rawRemap(buffer, .@"1", 4096, @returnAddress()) orelse return error.TestUnexpectedResult;
    try testing.expect(moved != buffer.ptr);
    buffer = moved[0..4096];

    const summary = try attributing.summarize(testing.allocator);
    defer Attributing.freeSummary(testing.allocator, summary);
    try testing.expectEqual(@as(usize, 1), summary.count);
    try testing.expectEqualStrings("grows.html", summary.files[0].path);
    try testing.expectEqual(@as(usize, 4096), summary.bytes);

    a.free(buffer);
    const after = try attributing.summarize(testing.allocator);
    defer Attributing.freeSummary(testing.allocator, after);
    try testing.expectEqual(@as(usize, 0), after.count);
}

test "attribution: allocations from many threads are all recorded and all removed" {
    // CountingChild's counters are not atomic, so the child here is
    // testing.allocator itself, which is thread-safe.
    var attributing = Attributing.init(testing.allocator);
    attributing.meta = testing.allocator;
    defer attributing.deinit();
    attributing.enterFile("threads.html");

    const Worker = struct {
        fn run(alloc: std.mem.Allocator, keep: *[64]*u64) void {
            for (keep) |*k| k.* = alloc.create(u64) catch unreachable;
            for (0..256) |_| {
                const t = alloc.alloc(u8, 24) catch unreachable;
                alloc.free(t);
            }
        }
    };
    var kept: [4][64]*u64 = undefined;
    var threads: [4]std.Thread = undefined;
    for (&threads, &kept) |*t, *k| t.* = try std.Thread.spawn(.{}, Worker.run, .{ attributing.allocator(), k });
    for (threads) |t| t.join();

    const summary = try attributing.summarize(testing.allocator);
    defer Attributing.freeSummary(testing.allocator, summary);
    try testing.expectEqual(@as(usize, 4 * 64), summary.count);
    for (kept) |k| for (k) |p| attributing.allocator().destroy(p);
    const after = try attributing.summarize(testing.allocator);
    defer Attributing.freeSummary(testing.allocator, after);
    try testing.expectEqual(@as(usize, 0), after.count);
}

test "attribution: after deinit allocations pass straight through, and frees still reach the child" {
    var attributing = Attributing.init(testing.allocator);
    attributing.meta = testing.allocator;
    attributing.enterFile("before-deinit.html");
    const a = attributing.allocator();
    const made_before = try a.alloc(u8, 4);
    attributing.deinit();
    const made_after = try a.alloc(u8, 4);
    a.free(made_after);
    a.free(made_before);
    attributing.enterFile("ignored.html");
    try testing.expectEqualStrings(Attributing.before_first_file, attributing.currentFile());
}
