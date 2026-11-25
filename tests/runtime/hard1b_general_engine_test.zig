//! Allocator hardening, batch B, the span engine's general partitions
//! (lane hard1-b; tmp/plans/allocator-hardening-design.md 3.1-3.5 and
//! section 7 batch B item 1): `Engine.allocGeneral` / `freeGeneral`, the
//! entry points the general allocator (heap.general) routes every
//! `std.mem.Allocator` call through.
//!
//! - The BYTES partition takes the page's bytes: its own range, its own
//!   buckets, every free validated as a State block's is - and no quarantine
//!   and no zeroing (design 1.2: "the reason it has no quarantine and no
//!   zeroing"; std's allocator fills a block on issue).
//! - A general OBJECTS block (pointer-bearing) shares the State blocks'
//!   buckets in the objects partition, and so their zero on free, their
//!   verify on issue and the window thread's quarantine (decision D4).
//!
//! Each needs a rung with general pools (the full one); a smaller rung (a
//! sanitizer's address map) keeps general memory on the host allocator, and
//! these skip there.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const BrowserScope = runtime.BrowserScope;
const heap = runtime.heap;

fn generalEngine(scope: *BrowserScope) !*heap.Engine {
    const engine = try scope.heapEngine();
    if (!engine.heap.general_pools) return error.SkipZigTest;
    return engine;
}

test "a bytes block is the bytes partition's, a general objects block the objects partition's" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);

    const text = try engine.allocGeneral(.bytes, 200, 1, @returnAddress());
    defer engine.freeGeneral(text, 200, 1);
    try testing.expectEqual(heap.PartitionId.bytes, engine.partitionOf(text).?);
    const record = try engine.allocGeneral(.objects, 48, 8, @returnAddress());
    defer engine.freeGeneral(record, 48, 8);
    try testing.expectEqual(heap.PartitionId.objects, engine.partitionOf(record).?);
    // A pointer-bearing block is issued zero, as every objects block is.
    try testing.expect(std.mem.allEqual(u8, record[0..48], 0));
}

test "a bytes free is validated: a double, an interior, a wrong-size and another Browser's free are caught" {
    var a = BrowserScope.init(testing.allocator);
    defer a.deinit();
    var b = BrowserScope.init(testing.allocator);
    defer b.deinit();
    const engine_a = try generalEngine(&a);
    const engine_b = try generalEngine(&b);
    engine_a.checks = .report;
    engine_b.checks = .report;

    const text = try engine_a.allocGeneral(.bytes, 96, 1, @returnAddress());
    engine_a.freeGeneral(text + 16, 80, 1);
    try testing.expectEqual(@as(?heap.Violation, .invalid_free), engine_a.takeViolation());
    engine_a.freeGeneral(text, 4000, 1);
    try testing.expectEqual(@as(?heap.Violation, .wrong_size), engine_a.takeViolation());
    engine_b.freeGeneral(text, 96, 1);
    try testing.expectEqual(@as(?heap.Violation, .other_heap), engine_b.takeViolation());
    engine_a.freeGeneral(text, 96, 1);
    try testing.expectEqual(@as(?heap.Violation, null), engine_a.takeViolation());
    engine_a.freeGeneral(text, 96, 1);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine_a.takeViolation());
}

test "a bytes block freed inside a task is free at once; a general objects block is held until the task ends" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);

    engine.beginTask();
    // Bytes: no quarantine, so lowest-address-first gives the same slot back.
    const text = try engine.allocGeneral(.bytes, 64, 1, @returnAddress());
    engine.freeGeneral(text, 64, 1);
    const text_again = try engine.allocGeneral(.bytes, 64, 1, @returnAddress());
    try testing.expectEqual(@intFromPtr(text), @intFromPtr(text_again));
    engine.freeGeneral(text_again, 64, 1);

    // Objects: held while the task runs; another block meanwhile.
    const record = try engine.allocGeneral(.objects, 64, 8, @returnAddress());
    engine.freeGeneral(record, 64, 8);
    const other = try engine.allocGeneral(.objects, 64, 8, @returnAddress());
    try testing.expect(@intFromPtr(other) != @intFromPtr(record));
    engine.freeGeneral(other, 64, 8);
    engine.endTask();
}

test "the leak report and the stats count live general blocks, bytes and objects" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);

    const before = engine.stats();
    const text = try engine.allocGeneral(.bytes, 300, 1, @returnAddress());
    const record = try engine.allocGeneral(.objects, 40, 8, @returnAddress());
    const during = engine.stats();
    try testing.expectEqual(before.bytes.live_blocks + 1, during.bytes.live_blocks);
    try testing.expectEqual(before.general_objects.live_blocks + 1, during.general_objects.live_blocks);
    // The State blocks' figures do not move: the general blocks have their
    // own buckets (a freed general block never becomes a State block).
    try testing.expectEqual(before.objects.live_blocks, during.objects.live_blocks);
    const Count = struct {
        fn line(_: void, _: heap.LeakLine) void {}
    };
    try testing.expectEqual(@as(usize, 2), engine.leakReport({}, Count.line));
    engine.freeGeneral(text, 300, 1);
    engine.freeGeneral(record, 40, 8);
    try testing.expectEqual(@as(usize, 0), engine.leakReport({}, Count.line));
}

test "a huge bytes block (past a large run) is the bytes partition's, and its address space is reused after its free" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);

    const size = 5 * 1024 * 1024 + 123;
    const body = try engine.allocGeneral(.bytes, size, 1, @returnAddress());
    try testing.expectEqual(heap.PartitionId.bytes, engine.partitionOf(body).?);
    body[0] = 1;
    body[size - 1] = 2;
    engine.freeGeneral(body, size, 1);
    // The same size again takes the same range back (first fit by super
    // pages), so churning large bodies cannot use up the partition.
    const again = try engine.allocGeneral(.bytes, size, 1, @returnAddress());
    try testing.expectEqual(@intFromPtr(body), @intFromPtr(again));
    engine.freeGeneral(again, size, 1);
    // A free of a huge block at a wrong size is caught too.
    engine.checks = .report;
    const third = try engine.allocGeneral(.bytes, size, 1, @returnAddress());
    engine.freeGeneral(third, size + 4 * 1024 * 1024, 1);
    try testing.expectEqual(@as(?heap.Violation, .wrong_size), engine.takeViolation());
    engine.freeGeneral(third, size, 1);
    try testing.expectEqual(@as(?heap.Violation, null), engine.takeViolation());
}

test "a general block made on one thread is freed on another, both ways, under the partitions' locks" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const allocator = heap.general.allocatorOf(engine);

    // Each side makes blocks of both partitions for the other to free, in
    // rounds, while it frees the other side's: under ThreadSanitizer a race
    // on a span's state or a bucket's lists is a report.
    const rounds = 200;
    const per_round = 64;
    const Exchange = struct {
        allocator: std.mem.Allocator,
        made: [rounds][per_round][]u8 = undefined,
        words: [rounds][per_round][]usize = undefined,
        ready: std.atomic.Value(usize) = .init(0),

        fn make(self: *@This()) !void {
            for (0..rounds) |r| {
                for (0..per_round) |i| {
                    self.made[r][i] = try self.allocator.alloc(u8, 16 + (i * 37) % 900);
                    self.words[r][i] = try self.allocator.alloc(usize, 1 + i % 40);
                }
                self.ready.store(r + 1, .release);
            }
        }

        fn takeFrom(self: *@This(), other: *@This()) void {
            for (0..rounds) |r| {
                while (other.ready.load(.acquire) <= r) std.Thread.yield() catch {};
                for (0..per_round) |i| {
                    self.allocator.free(other.made[r][i]);
                    self.allocator.free(other.words[r][i]);
                }
            }
        }
    };
    // Off the stack: two sides' block tables are 800 KiB.
    const window_side = try testing.allocator.create(Exchange);
    defer testing.allocator.destroy(window_side);
    window_side.* = .{ .allocator = allocator };
    const worker_side = try testing.allocator.create(Exchange);
    defer testing.allocator.destroy(worker_side);
    worker_side.* = .{ .allocator = allocator };
    const Worker = struct {
        fn run(mine: *Exchange, theirs: *Exchange) void {
            mine.make() catch @panic("the worker's side could not allocate");
            mine.takeFrom(theirs);
        }
    };
    const thread = try std.Thread.spawn(.{}, Worker.run, .{ worker_side, window_side });
    try window_side.make();
    window_side.takeFrom(worker_side);
    thread.join();
    const Count = struct {
        fn line(_: void, _: heap.LeakLine) void {}
    };
    try testing.expectEqual(@as(usize, 0), engine.leakReport({}, Count.line));
}

test "a general allocation that must open a span fails cleanly when the heap may not grow, and works once it may" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const Refuse = struct {
        var allowed = false;
        fn call(_: *anyopaque) bool {
            return allowed;
        }
    };
    const saved = engine.grow_hook;
    defer engine.grow_hook = saved;
    engine.grow_hook = .{ .context = engine, .call = Refuse.call };
    Refuse.allowed = false;
    // A class, a large run and a huge block of each general partition: each
    // needs a span opened.
    for ([_]usize{ 48, 40 * 1024, 3 * 1024 * 1024 }) |size| {
        try testing.expectError(error.OutOfMemory, engine.allocGeneral(.bytes, size, 1, @returnAddress()));
        try testing.expectError(error.OutOfMemory, engine.allocGeneral(.objects, size, 8, @returnAddress()));
    }
    Refuse.allowed = true;
    for ([_]usize{ 48, 40 * 1024, 3 * 1024 * 1024 }) |size| {
        const text = try engine.allocGeneral(.bytes, size, 1, @returnAddress());
        engine.freeGeneral(text, size, 1);
        const words = try engine.allocGeneral(.objects, size, 8, @returnAddress());
        engine.freeGeneral(words, size, 8);
    }
    const Count = struct {
        fn line(_: void, _: heap.LeakLine) void {}
    };
    try testing.expectEqual(@as(usize, 0), engine.leakReport({}, Count.line));
}

fn generalAllocations(allocator: std.mem.Allocator) !void {
    // A scope over the allocator under test: its heap asks it before each
    // span opens (Engine.grow_hook), so each class's first block fails in
    // turn.
    const scope = try allocator.create(BrowserScope);
    scope.* = BrowserScope.init(allocator);
    defer {
        scope.deinit();
        allocator.destroy(scope);
    }
    const engine = try scope.heapEngine();
    if (!engine.heap.general_pools) return;
    const general = heap.general.allocatorOf(engine);
    const text = try general.alloc(u8, 100);
    defer general.free(text);
    const words = try general.alloc(usize, 30);
    defer general.free(words);
    const body = try general.alloc(u8, 2 * 1024 * 1024 + 1);
    defer general.free(body);
    const units = try general.alloc(u16, 9000);
    defer general.free(units);
}

test "the general allocator's out-of-memory paths unwind every failed allocation (checkAllAllocationFailures, through the heap's failure injector)" {
    try testing.checkAllAllocationFailures(testing.allocator, generalAllocations, .{});
}

test "an agent's cache: a freed block is the next one issued on its thread, a double free of a cached block is caught, and the stats count it as no one's" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const cache = try engine.attachAgent();
    defer engine.detachAgent(cache);
    const allocator = cache.allocator();
    const before = engine.stats();

    const text = try allocator.alloc(u8, 40);
    const address = @intFromPtr(text.ptr);
    try testing.expectEqual(heap.PartitionId.bytes, engine.partitionOf(text.ptr).?);
    allocator.free(text);
    // LIFO on its thread: the block just given back.
    const again = try allocator.alloc(u8, 40);
    try testing.expectEqual(address, @intFromPtr(again.ptr));
    allocator.free(again);
    engine.checks = .report;
    allocator.free(again);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine.takeViolation());
    engine.checks = .panic;

    // The cache's blocks are out of their spans but no one's.
    const during = engine.stats();
    try testing.expectEqual(before.bytes.live_blocks, during.bytes.live_blocks);
    const words = try allocator.alloc(usize, 6);
    try testing.expectEqual(before.general_objects.live_blocks + 1, engine.stats().general_objects.live_blocks);
    allocator.free(words);
    engine.flushAllCaches();
    const Count = struct {
        fn line(_: void, _: heap.LeakLine) void {}
    };
    try testing.expectEqual(@as(usize, 0), engine.leakReport({}, Count.line));
}

test "agents on two threads, each through its own cache, free each other's blocks (into the freeing thread's cache), and nothing is left" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);

    const rounds = 100;
    const per_round = 64;
    const Side = struct {
        engine: *heap.Engine,
        made: [rounds][per_round][]u8 = undefined,
        words: [rounds][per_round][]usize = undefined,
        ready: std.atomic.Value(usize) = .init(0),
        done: std.atomic.Value(bool) = .init(false),

        fn run(self: *@This(), other: *@This()) !void {
            const cache = try self.engine.attachAgent();
            defer self.engine.detachAgent(cache);
            const allocator = cache.allocator();
            for (0..rounds) |r| {
                for (0..per_round) |i| {
                    self.made[r][i] = try allocator.alloc(u8, 16 + (i * 37) % 900);
                    self.words[r][i] = try allocator.alloc(usize, 1 + i % 40);
                }
                self.ready.store(r + 1, .release);
                while (other.ready.load(.acquire) <= r) std.Thread.yield() catch {};
                for (0..per_round) |i| {
                    allocator.free(other.made[r][i]);
                    allocator.free(other.words[r][i]);
                }
            }
            self.done.store(true, .release);
            // Stay attached until the other side freed every block of ours.
            while (!other.done.load(.acquire)) std.Thread.yield() catch {};
        }
    };
    const a = try testing.allocator.create(Side);
    defer testing.allocator.destroy(a);
    a.* = .{ .engine = engine };
    const b = try testing.allocator.create(Side);
    defer testing.allocator.destroy(b);
    b.* = .{ .engine = engine };
    const Worker = struct {
        fn run(mine: *Side, theirs: *Side) void {
            mine.run(theirs) catch @panic("an agent's side could not allocate");
        }
    };
    const thread = try std.Thread.spawn(.{}, Worker.run, .{ b, a });
    try a.run(b);
    thread.join();
    const Count = struct {
        fn line(_: void, _: heap.LeakLine) void {}
    };
    try testing.expectEqual(@as(usize, 0), engine.leakReport({}, Count.line));
}

test "M1: a freed general large run gives its pages back at once, past one empty run its bucket keeps" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const size = 64 * 1024;
    inline for (.{ heap.PartitionId.bytes, heap.PartitionId.objects }) |pid| {
        const alignment: usize = if (pid == .bytes) 1 else 8;
        var blocks: [3][*]u8 = undefined;
        for (&blocks) |*block| block.* = try engine.allocGeneral(pid, size, alignment, @returnAddress());
        const before = engine.stats();
        for (blocks) |block| engine.freeGeneral(block, size, alignment);
        const after = engine.stats();
        const b = if (pid == .bytes) before.bytes else before.objects;
        const a = if (pid == .bytes) after.bytes else after.objects;
        // One empty run stays committed for the next block of its length;
        // the other two are decommitted at their free (libc gives a large
        // block back at once too: main's malloc, the pair's base).
        try testing.expectEqual(b.spans_decommitted + 2, a.spans_decommitted);
        // The kept run is the next one issued: nothing is recommitted.
        const again = try engine.allocGeneral(pid, size, alignment, @returnAddress());
        const now = engine.stats();
        try testing.expectEqual(a.spans_decommitted, (if (pid == .bytes) now.bytes else now.objects).spans_decommitted);
        engine.freeGeneral(again, size, alignment);
    }
}

test "M7-2a: general large runs keep a bounded 4 MiB MRU ring for hot reuse and evict oldest past budget" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    // Hot streaming loop: 256 KiB, 512 KiB, 1 MiB, 1.5 MiB (total 3.25 MiB <=
    // 4 MiB budget) stay committed in the MRU ring across reuse with zero
    // decommits (no madvise + kernel zero-fill churn on fetch.loopback-*).
    const hot = [_]usize{ 256 * 1024, 512 * 1024, 1024 * 1024, 1536 * 1024 };
    inline for (.{ heap.PartitionId.bytes, heap.PartitionId.objects }) |pid| {
        const alignment: usize = if (pid == .bytes) 1 else 8;
        const before = engine.stats();
        const b = if (pid == .bytes) before.bytes else before.objects;
        for (0..3) |_| {
            for (hot) |sz| {
                const p = try engine.allocGeneral(pid, sz, alignment, @returnAddress());
                engine.freeGeneral(p, sz, alignment);
            }
        }
        const after_hot = engine.stats();
        const ah = if (pid == .bytes) after_hot.bytes else after_hot.objects;
        try testing.expectEqual(b.spans_decommitted, ah.spans_decommitted);
        // Pushing distinct large runs past the 4 MiB budget evicts oldest runs
        // immediately so empty large runs stay bounded (never 127 buckets).
        const extra = [_]usize{ 1280 * 1024, 1792 * 1024, 1920 * 1024 };
        for (extra) |sz| {
            const p = try engine.allocGeneral(pid, sz, alignment, @returnAddress());
            engine.freeGeneral(p, sz, alignment);
        }
        const after_extra = engine.stats();
        const ae = if (pid == .bytes) after_extra.bytes else after_extra.objects;
        try testing.expect(ae.spans_decommitted >= b.spans_decommitted + 3);
        try testing.expect(ae.committed_span_bytes <= b.committed_span_bytes + 4 * 1024 * 1024);
    }
}

test "M7-2b: general class spans keep up to 4 empty spans per bucket (capped at 512 KiB per partition) and decommit bursts immediately" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const blocks_per_span = heap.span_bytes / 64;
    const total = blocks_per_span * 20;
    const ptrs = try testing.allocator.alloc([*]u8, total);
    defer testing.allocator.free(ptrs);
    inline for (.{ heap.PartitionId.bytes, heap.PartitionId.objects }) |pid| {
        const alignment: usize = if (pid == .bytes) 1 else 8;
        const before = engine.stats();
        const b = if (pid == .bytes) before.bytes else before.objects;
        // 4 spans freed: all 4 stay committed for loop reuse (zero decommits).
        for (ptrs[0 .. blocks_per_span * 4]) |*slot| slot.* = try engine.allocGeneral(pid, 64, alignment, @returnAddress());
        for (ptrs[0 .. blocks_per_span * 4]) |slot| engine.freeGeneral(slot, 64, alignment);
        const after4 = engine.stats();
        const a4 = if (pid == .bytes) after4.bytes else after4.objects;
        try testing.expectEqual(b.spans_decommitted, a4.spans_decommitted);
        // 20 spans freed: at least 16 decommit immediately (at most 4 empty kept).
        for (ptrs) |*slot| slot.* = try engine.allocGeneral(pid, 64, alignment, @returnAddress());
        for (ptrs) |slot| engine.freeGeneral(slot, 64, alignment);
        const after20 = engine.stats();
        const a20 = if (pid == .bytes) after20.bytes else after20.objects;
        try testing.expect(a20.spans_decommitted >= b.spans_decommitted + 16);
        try testing.expect(a20.spans_empty <= b.spans_empty + 4);
    }
}

test "M7-3: idle decommit reclaims empty general class spans, MRU large runs, and AgentCache-held spans at general_decommit_age_ms (200 ms)" {
    try testing.expectEqual(@as(u32, 200), heap.general_decommit_age_ms);
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const cache = try engine.attachAgent();
    defer engine.detachAgent(cache);
    const allocator = cache.allocator();

    engine.setNow(1_000);
    // Hold blocks in AgentCache + empty large runs in MRU ring.
    const small = try allocator.alloc(u8, 64);
    allocator.free(small);
    const big = try engine.allocGeneral(.bytes, 512 * 1024, 1, @returnAddress());
    engine.freeGeneral(big, 512 * 1024, 1);
    // Also empty a State block in objects (must stay aged to decommit_age_ms = 1000 ms).
    const state_blk = try engine.alloc(.objects, 64, 8, null, @returnAddress());
    engine.free(state_blk, 64, 8);

    // At +200 ms: every general empty span (both MRU large run AND the span
    // AgentCache held!) decommits, while the State span stays committed until +1000 ms.
    const r200 = engine.decommitAged(1_200, heap.decommit_age_ms, std.math.maxInt(usize));
    try testing.expect(r200.decommitted >= 2);
    const s200 = engine.stats();
    try testing.expectEqual(@as(usize, 0), s200.bytes.spans_empty);
    try testing.expectEqual(@as(usize, 0), s200.bytes.spans_active);
    try testing.expect(s200.objects.spans_empty >= 1);
    // At +1000 ms: the State span decommits too.
    const r1000 = engine.decommitAged(2_000, heap.decommit_age_ms, std.math.maxInt(usize));
    try testing.expect(r1000.decommitted >= 1);
}

test "M3: AgentCache uses depth 8 and refill never opens extra spans for large or fresh classes" {
    try testing.expectEqual(@as(usize, 8), heap.cache_depth);
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const cache = try engine.attachAgent();
    defer engine.detachAgent(cache);
    const allocator = cache.allocator();

    // One 16 KiB, one 4 KiB, one 2 KiB, and one 64 B allocation through the
    // agent cache must each open at most ONE span (not cache_depth spans!).
    const sizes = [_]usize{ 16 * 1024, 4 * 1024, 2 * 1024, 64 };
    for (sizes) |sz| {
        const before = engine.stats().bytes.spans_active;
        const buf = try allocator.alloc(u8, sz);
        defer allocator.free(buf);
        const after = engine.stats().bytes.spans_active;
        try testing.expect(after <= before + 1);
    }
}

test "M7-1: general blocks take the halves classes (20: 16-B steps to 64 B, then two per doubling) cutting idle span overhead" {
    try testing.expectEqual(@as(usize, 20), heap.GeneralClasses.count);
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const before = engine.stats().bytes.live_bytes;
    const text = try engine.allocGeneral(.bytes, 200, 1, @returnAddress());
    defer engine.freeGeneral(text, 200, 1);
    // 200 B is in (128, 256]: halves step 64 -> 256 B.
    try testing.expectEqual(before + 256, engine.stats().bytes.live_bytes);
    const med = try engine.allocGeneral(.bytes, 600, 1, @returnAddress());
    defer engine.freeGeneral(med, 600, 1);
    // 600 B is in (512, 1024]: halves step 256 -> 768 B.
    try testing.expectEqual(before + 256 + 768, engine.stats().bytes.live_bytes);
    // Every class is a multiple of 16 and holds its requests, and every
    // power-of-two alignment divides its class size.
    var align_shift: u6 = 0;
    while (align_shift <= 14) : (align_shift += 1) {
        const a = @as(usize, 1) << align_shift;
        var sz: usize = a;
        while (sz <= heap.GeneralClasses.max_size) : (sz += a) {
            const c = heap.GeneralClasses.of(sz);
            const bb = heap.GeneralClasses.bytes(c);
            try testing.expect(bb >= sz);
            try testing.expectEqual(@as(usize, 0), bb % a);
        }
    }
}

test "M4: AgentCache frees of objects inside a task go to quarantine and catch double/interior/wrong-size frees" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const cache = try engine.attachAgent();
    defer engine.detachAgent(cache);
    const allocator = cache.allocator();

    engine.beginTask();
    defer engine.endTask();
    const first = try allocator.alloc(usize, 8);
    const first_addr = @intFromPtr(first.ptr);
    allocator.free(first);
    try testing.expect(engine.isQuarantined(first.ptr));
    const second = try allocator.alloc(usize, 8);
    try testing.expect(@intFromPtr(second.ptr) != first_addr);
    // Double free of quarantined block caught through AgentCache.
    engine.checks = .report;
    allocator.free(first);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine.takeViolation());
    // Wrong-size free of live objects block during task caught through AgentCache.
    const wrong_slice: [*]usize = second.ptr;
    allocator.free(wrong_slice[0..16]);
    try testing.expectEqual(@as(?heap.Violation, .wrong_size), engine.takeViolation());
    // Interior free of live objects block during task caught through AgentCache.
    const raw_obj: [*]u8 = @ptrCast(second.ptr);
    allocator.free(raw_obj[8 .. 8 + 64]);
    try testing.expectEqual(@as(?heap.Violation, .invalid_free), engine.takeViolation());
    // Interior free of bytes block caught through AgentCache.
    const bytes = try allocator.alloc(u8, 64);
    allocator.free(bytes[3..]);
    try testing.expectEqual(@as(?heap.Violation, .invalid_free), engine.takeViolation());
    engine.checks = .panic;
    allocator.free(bytes);
    allocator.free(second);
}
