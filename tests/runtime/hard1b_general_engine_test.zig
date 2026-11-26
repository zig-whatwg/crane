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
    // Objects large runs stay class-stable per bucket: one empty run stays
    // committed for the next block of its length; the other two decommit at free.
    {
        var blocks: [3][*]u8 = undefined;
        for (&blocks) |*block| block.* = try engine.allocGeneral(.objects, size, 8, @returnAddress());
        const before = engine.stats().objects;
        for (blocks) |block| engine.freeGeneral(block, size, 8);
        const after = engine.stats().objects;
        try testing.expectEqual(before.spans_decommitted + 2, after.spans_decommitted);
        const again = try engine.allocGeneral(.objects, size, 8, @returnAddress());
        const now = engine.stats().objects;
        try testing.expectEqual(after.spans_decommitted, now.spans_decommitted);
        engine.freeGeneral(again, size, 8);
    }
}

test "M8-4b: objects large runs keep a bounded 256 KiB / 4-slot MRU ring and evict oldest past budget" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    // Hot objects large runs (32K + 48K + 80K + 96K = 256 KiB <= 256 KiB / 4 slots)
    // stay committed across reuse with zero decommits.
    const hot = [_]usize{ 32 * 1024, 48 * 1024, 80 * 1024, 96 * 1024 };
    const before = engine.stats().objects;
    for (0..3) |_| {
        for (hot) |sz| {
            const p = try engine.allocGeneral(.objects, sz, 8, @returnAddress());
            engine.freeGeneral(p, sz, 8);
        }
    }
    const after_hot = engine.stats().objects;
    try testing.expectEqual(before.spans_decommitted, after_hot.spans_decommitted);
    // Pushing distinct objects large runs past 256 KiB evicts oldest runs immediately.
    const extra = [_]usize{ 128 * 1024, 192 * 1024 };
    for (extra) |sz| {
        const p = try engine.allocGeneral(.objects, sz, 8, @returnAddress());
        engine.freeGeneral(p, sz, 8);
    }
    const after_extra = engine.stats().objects;
    try testing.expect(after_extra.spans_decommitted >= before.spans_decommitted + 3);
    try testing.expect(after_extra.committed_span_bytes <= before.committed_span_bytes + 256 * 1024);
}

test "M8-4b: general class spans start tight (<= 2 empty for <= 2 KiB, <= 1 for > 2 KiB) and adapt when thrashing" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const blocks_per_span = heap.span_bytes / 64;
    const total = blocks_per_span * 10;
    const ptrs = try testing.allocator.alloc([*]u8, total);
    defer testing.allocator.free(ptrs);
    engine.setNow(1_000);
    inline for (.{ heap.PartitionId.bytes, heap.PartitionId.objects }) |pid| {
        const alignment: usize = if (pid == .bytes) 1 else 8;
        const before = engine.stats();
        const b = if (pid == .bytes) before.bytes else before.objects;
        // 2 spans freed: both stay committed (zero decommits).
        for (ptrs[0 .. blocks_per_span * 2]) |*slot| slot.* = try engine.allocGeneral(pid, 64, alignment, @returnAddress());
        for (ptrs[0 .. blocks_per_span * 2]) |slot| engine.freeGeneral(slot, 64, alignment);
        const after2 = engine.stats();
        const a2 = if (pid == .bytes) after2.bytes else after2.objects;
        try testing.expectEqual(b.spans_decommitted, a2.spans_decommitted);
        // 10 spans freed: at least 8 decommit immediately (at most 2 empty kept initially).
        for (ptrs) |*slot| slot.* = try engine.allocGeneral(pid, 64, alignment, @returnAddress());
        for (ptrs) |slot| engine.freeGeneral(slot, 64, alignment);
        const after10 = engine.stats();
        const a10 = if (pid == .bytes) after10.bytes else after10.objects;
        try testing.expect(a10.spans_decommitted >= b.spans_decommitted + 8);
        try testing.expect(a10.spans_empty <= b.spans_empty + 2);
        // Thrashing: immediately re-allocating + freeing 10 spans within < 200 ms
        // adapts the bucket's empty cap upward so the second cycle stops thrashing.
        for (ptrs) |*slot| slot.* = try engine.allocGeneral(pid, 64, alignment, @returnAddress());
        const d_mid = (if (pid == .bytes) engine.stats().bytes else engine.stats().objects).spans_decommitted;
        for (ptrs) |slot| engine.freeGeneral(slot, 64, alignment);
        const after_thrash = if (pid == .bytes) engine.stats().bytes else engine.stats().objects;
        try testing.expect(after_thrash.spans_empty > b.spans_empty + 2);
        try testing.expect(after_thrash.spans_decommitted < d_mid + 8);
    }
    // Non-cached classes (> 2 KiB, e.g. 4096 B) keep at most 1 empty span.
    const big_blocks_per_span = heap.span_bytes / 4096;
    var big_ptrs: [big_blocks_per_span * 4][*]u8 = undefined;
    const before_big = engine.stats().objects;
    for (&big_ptrs) |*slot| slot.* = try engine.allocGeneral(.objects, 4096, 8, @returnAddress());
    for (big_ptrs) |slot| engine.freeGeneral(slot, 4096, 8);
    const after_big = engine.stats().objects;
    try testing.expect(after_big.spans_decommitted >= before_big.spans_decommitted + 3);
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

test "M8-4a: general blocks take span-divisor-clean halves_span classes (19: 5120 B span/3, no 12288 B)" {
    try testing.expectEqual(@as(usize, 19), heap.GeneralClasses.count);
    // 4800 B (e.g. querySelectorAll 200-node static NodeList) lands in 5120 B
    // (3 slots per 16 KiB span instead of 2 in 6144 B).
    try testing.expectEqual(@as(usize, 5120), heap.GeneralClasses.bytes(heap.GeneralClasses.of(4800)));
    try testing.expectEqual(@as(usize, 3), heap.span_bytes / heap.GeneralClasses.bytes(heap.GeneralClasses.of(4800)));
    // 12288 B is dropped (1 slot/span == 16384 B).
    try testing.expectEqual(@as(usize, 16384), heap.GeneralClasses.bytes(heap.GeneralClasses.of(12288)));
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const before = engine.stats().bytes.live_bytes;
    const text = try engine.allocGeneral(.bytes, 200, 1, @returnAddress());
    defer engine.freeGeneral(text, 200, 1);
    try testing.expectEqual(before + 256, engine.stats().bytes.live_bytes);
    const med = try engine.allocGeneral(.bytes, 600, 1, @returnAddress());
    defer engine.freeGeneral(med, 600, 1);
    try testing.expectEqual(before + 256 + 768, engine.stats().bytes.live_bytes);
    // Every class is a multiple of 16, holds its requests, and every
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

test "M8-1a: lock-free per-agent objects quarantine recycles directly to AgentCache on eviction and purge, preserving cap and write-after-free" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    var cfg = heap.Config.production;
    cfg.quarantine_cap = 4096;
    engine.configureForTest(cfg);
    const cache = try engine.attachAgent();
    defer engine.detachAgent(cache);
    const allocator = cache.allocator();

    engine.beginTask();
    // Free 1 block during task: quarantined, live_blocks drops to 0.
    const a = try allocator.alloc(usize, 16); // 128 B
    allocator.free(a);
    try testing.expect(engine.isQuarantined(a.ptr));
    const s_q = engine.stats();
    try testing.expectEqual(@as(usize, 0), s_q.general_objects.live_blocks);
    try testing.expectEqual(@as(usize, 1), s_q.quarantine_blocks);

    // Overflow the 4 KiB quarantine with 128 B objects blocks: evicted victims
    // recycle straight into AgentCache (and spill cleanly when cache_depth fills).
    for (0..64) |_| {
        const blk = try allocator.alloc(usize, 16);
        allocator.free(blk);
    }
    const s_ov = engine.stats();
    try testing.expect(s_ov.quarantine_bytes <= 4096);
    try testing.expect(s_ov.quarantine_total_evicted > 0);
    // At least one victim recycled straight into the agent cache's stack.
    try testing.expect(cache.counts[0][heap.GeneralClasses.of(128)] > 0);

    // Purge at endTask moves remaining cache-owned quarantined entries directly
    // into AgentCache; next alloc reuses them and detects a write-after-free.
    engine.endTask();
    try testing.expectEqual(@as(usize, 0), engine.stats().quarantine_blocks);
    const c_idx = heap.GeneralClasses.of(128);
    try testing.expect(cache.counts[0][c_idx] > 0);

    // Corrupt the top cached block to verify write-after-free is caught on issue.
    const top_off = @as(usize, cache.slots[0][c_idx][cache.counts[0][c_idx] - 1]) * 16;
    const top_ptr: [*]u8 = @ptrFromInt(cache.window_base + top_off);
    top_ptr[7] = 0x55;
    engine.checks = .report;
    const reused = try allocator.alloc(usize, 16);
    try testing.expectEqual(@as(?heap.Violation, .write_after_free), engine.takeViolation());
    engine.checks = .panic;
    allocator.free(reused);
}

test "M8-1b: detaching AgentCache mid-task safely migrates cache-owned quarantined entries to span-owned" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const cache = try engine.attachAgent();
    const allocator = cache.allocator();

    engine.beginTask();
    const p1 = try allocator.alloc(usize, 8);
    const p2 = try allocator.alloc(usize, 16);
    allocator.free(p1);
    allocator.free(p2);
    try testing.expect(engine.isQuarantined(p1.ptr));
    try testing.expect(engine.isQuarantined(p2.ptr));

    // Detach mid-task: entries stay quarantined (no premature reuse) and
    // double-free is still caught, then endTask purges cleanly with zero leaks.
    engine.detachAgent(cache);
    try testing.expect(engine.isQuarantined(p1.ptr));
    try testing.expect(engine.isQuarantined(p2.ptr));
    engine.checks = .report;
    engine.freeGeneral(@ptrCast(p1.ptr), 64, 8);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine.takeViolation());
    engine.checks = .panic;

    engine.endTask();
    try testing.expectEqual(@as(usize, 0), engine.stats().quarantine_blocks);
    try testing.expectEqual(@as(usize, 0), engine.stats().general_objects.live_blocks);
}

test "M8-1c: production general objects > 1 KiB zero and verify first 1 KiB on free and issue full zeroed request (Design 3.4)" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    engine.configureForTest(heap.Config.production);

    const a = try engine.allocGeneral(.objects, 4096, 8, @returnAddress());
    @memset(a[0..4096], 0xAB);
    engine.freeGeneral(a, 4096, 8);
    // First 1 KiB was zeroed on free.
    for (a[0..1024]) |byte| try testing.expectEqual(@as(u8, 0), byte);
    // Write-after-free within first 1 KiB is caught on reissue.
    a[512] = 0x77;
    engine.checks = .report;
    const b = try engine.allocGeneral(.objects, 4096, 8, @returnAddress());
    try testing.expectEqual(@as(?heap.Violation, .write_after_free), engine.takeViolation());
    engine.checks = .panic;
    // Issued block is fully zeroed across all 4096 bytes.
    for (b[0..4096]) |byte| try testing.expectEqual(@as(u8, 0), byte);
    engine.freeGeneral(b, 4096, 8);
}

test "M8-2: idle decommit reclaims inactive bitmap pages and recommits cleanly on span reuse" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    // Open enough spans in objects to cover at least 2 full OS bitmap pages
    // (16 spans/page on 4 KiB Linux, 64 spans/page on 16 KiB macOS -> 140 spans).
    const span_count: usize = 140;
    const ptrs = try testing.allocator.alloc([*]u8, span_count);
    defer testing.allocator.free(ptrs);
    engine.setNow(1_000);
    for (ptrs) |*slot| slot.* = try engine.allocGeneral(.objects, 16 * 1024, 8, @returnAddress());
    for (ptrs) |slot| engine.freeGeneral(slot, 16 * 1024, 8);

    _ = engine.decommitAged(1_300, heap.decommit_age_ms, std.math.maxInt(usize));
    const after_idle = engine.stats().objects;
    try testing.expect(after_idle.bitmap_pages_decommitted >= 1);

    // Reusing those spans recommits the bitmap page cleanly and still catches double-frees.
    const again = try engine.allocGeneral(.objects, 16 * 1024, 8, @returnAddress());
    engine.freeGeneral(again, 16 * 1024, 8);
    engine.checks = .report;
    engine.freeGeneral(again, 16 * 1024, 8);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine.takeViolation());
    engine.checks = .panic;
}

test "M8-3: bytes large runs coalesce adjacent frees, resize in place, validate frees, and reclaim at 200 ms idle" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const cache = try engine.attachAgent();
    defer engine.detachAgent(cache);
    const allocator = cache.allocator();

    engine.setNow(1_000);
    // Allocate 32 KiB + 64 KiB + 32 KiB (contiguous in the same super page),
    // free all 3 -> coalesce into a single 128 KiB committed free run.
    const b1 = try allocator.alloc(u8, 32 * 1024);
    const b2 = try allocator.alloc(u8, 64 * 1024);
    const b3 = try allocator.alloc(u8, 32 * 1024);
    const va_before = engine.stats().bytes.va_assigned;
    allocator.free(b1);
    allocator.free(b2);
    allocator.free(b3);
    const big = try allocator.alloc(u8, 128 * 1024);
    try testing.expectEqual(va_before, engine.stats().bytes.va_assigned);
    try testing.expectEqual(@intFromPtr(b1.ptr), @intFromPtr(big.ptr));

    // In-place shrink (128 KiB -> 48 KiB) then in-place grow (48 KiB -> 96 KiB).
    try testing.expect(allocator.resize(big, 48 * 1024));
    const shrunk = big[0 .. 48 * 1024];
    try testing.expect(allocator.resize(shrunk, 96 * 1024));
    const grown = shrunk.ptr[0 .. 96 * 1024];
    @memset(grown, 0x33);

    // Validation: wrong size, interior, and double free.
    engine.checks = .report;
    engine.freeGeneral(grown.ptr, 48 * 1024, 1);
    try testing.expectEqual(@as(?heap.Violation, .wrong_size), engine.takeViolation());
    engine.freeGeneral(grown.ptr + 64, 96 * 1024, 1);
    try testing.expectEqual(@as(?heap.Violation, .invalid_free), engine.takeViolation());
    engine.checks = .panic;
    allocator.free(grown);
    engine.checks = .report;
    engine.freeGeneral(grown.ptr, 96 * 1024, 1);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine.takeViolation());
    engine.checks = .panic;

    // 200 ms idle decommits 100% of committed free bytes runs.
    _ = engine.decommitAged(1_300, heap.decommit_age_ms, std.math.maxInt(usize));
    try testing.expectEqual(@as(usize, 0), engine.stats().bytes.committed_span_bytes);
}

test "M8-4c: quarantine uses inline buffer up to 512 entries and spills cleanly to external memory above 512" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);
    const cache = try engine.attachAgent();
    defer engine.detachAgent(cache);
    const allocator = cache.allocator();

    engine.beginTask();
    // 100 small objects stay in the inline quarantine buffer (0 external bytes committed).
    for (0..100) |_| {
        const blk = try allocator.alloc(usize, 4); // 32 B
        allocator.free(blk);
    }
    try testing.expectEqual(@as(usize, 0), engine.stats().quarantine_external_bytes);
    try testing.expectEqual(@as(usize, 100), engine.stats().quarantine_blocks);

    // Pushing past 512 entries seamlessly commits external quarantine storage.
    for (0..500) |_| {
        const blk = try allocator.alloc(usize, 4);
        allocator.free(blk);
    }
    try testing.expect(engine.stats().quarantine_external_bytes > 0);
    try testing.expectEqual(@as(usize, 600), engine.stats().quarantine_blocks);
    engine.endTask();
    try testing.expectEqual(@as(usize, 0), engine.stats().quarantine_blocks);
}

test "M8-2b: decommitBitmapPages preserves active State spans whose bucket index equals bytes_large_bucket (320 B)" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try generalEngine(&scope);

    // State bucket index == GeneralClasses.count (19) in .quantum16 is 320 B
    // (the exact bucket of HTMLFormElement.InternalState). `bytes_large_bucket`
    // is a sentinel ONLY inside the `.bytes` partition; in `.objects` and
    // `.node`, bucket 19 is a regular active State span whose slot bitmap MUST
    // stay committed while live (on Linux MADV_DONTNEED immediately zeroes a
    // decommitted bitmap page, turning live slots into `.free` -> double_free).
    const colliding_bytes = (heap.GeneralClasses.count + 1) * 16;
    engine.setNow(1_000);
    const obj_blk = try engine.alloc(.objects, colliding_bytes, 8, null, @returnAddress());
    const node_blk = try engine.alloc(.{ .node = .element }, colliding_bytes, 8, null, @returnAddress());

    _ = engine.decommitAged(5_000, heap.decommit_age_ms, std.math.maxInt(usize));
    const st = engine.stats();
    try testing.expectEqual(@as(usize, 0), st.objects.bitmap_pages_decommitted);
    try testing.expectEqual(@as(usize, 0), st.node.bitmap_pages_decommitted);

    engine.checks = .report;
    engine.free(obj_blk, colliding_bytes, 8);
    try testing.expectEqual(@as(?heap.Violation, null), engine.takeViolation());
    engine.free(node_blk, colliding_bytes, 8);
    try testing.expectEqual(@as(?heap.Violation, null), engine.takeViolation());
    engine.checks = .panic;
}
