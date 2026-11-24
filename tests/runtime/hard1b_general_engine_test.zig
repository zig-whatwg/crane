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
    try testing.expectEqual(before.objects.live_blocks + 1, during.objects.live_blocks);
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
