//! The poison and the quarantine of a Browser's State blocks (lane uaf1; the
//! HIGH safety item "does any code read a released node's NodeBase after
//! its block went back to the arena?"), as the span engine has them since
//! lane hard1 (allocator-hardening batch A, design 3.4-3.5).
//!
//! The arena handed a freed state block to the very next request of its
//! size class (a LIFO free list), so the poison a detection build writes
//! over a freed block was readable only until the next node of that size
//! was made. Lane uaf1 gave the bug-finding run a FIFO quarantine. The heap
//! now gives every build a task-scoped quarantine with random eviction
//! (Chrome's scheduler-loop quarantine): a block freed while the window
//! agent's loop runs a task is held until the task ends - all fill (zero in
//! production, poison in Debug and the bug-finding run) - and checked for a
//! write when it is issued again. The bug-finding run's cap is 8 MiB.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");

const ArenaAllocator = runtime.ArenaAllocator;
const heap = runtime.heap;

/// A heap as the bug-finding WPT runner's Browser has it
/// (BrowserConfig.poison_freed_state): poison, the 8 MiB quarantine.
fn bugFindingScope(scope: *runtime.BrowserScope) !*heap.Engine {
    scope.arena.poison_freed = true;
    scope.arena.quarantine_freed = true;
    const engine = try scope.heapEngine();
    try testing.expectEqual(heap.Config.bug_finding_quarantine_cap, engine.config.quarantine_cap);
    try testing.expectEqual(heap.Fill.poison, engine.config.fill);
    return engine;
}

test "outside a task nothing is held: a freed block goes to the next request of its class" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try scope.heapEngine();
    const block = try scope.arena.createRaw(112, 8);
    scope.arena.destroyRaw(block, 112, 8);
    try testing.expectEqual(@as(usize, 0), engine.stats().quarantine_bytes);
    const again = try scope.arena.createRaw(112, 8);
    try testing.expectEqual(block, again);
    scope.arena.destroyRaw(again, 112, 8);
}

test "a scope's heap poisons freed state by default in a Debug build, and in no release build" {
    const rule = runtime.BrowserScope.poisonsFreedStateByDefault;
    try testing.expect(rule(.debug));
    inline for (.{ std.builtin.OptimizeMode.safe, .fast, .small }) |mode| try testing.expect(!rule(mode));

    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    try testing.expectEqual(rule(@import("builtin").mode), scope.arena.poison_freed);
    // The bug-finding detection is no default's: only a Browser whose config
    // asked has it (tests/html/perf2b5_poison_config_test.zig).
    try testing.expect(!scope.arena.quarantine_freed);
    const engine = try scope.heapEngine();
    try testing.expectEqual(heap.Config.of(scope.arena.poison_freed, false), engine.config);
    // A released NodeBase is poisoned wherever a freed block is.
    try testing.expectEqual(scope.arena.poison_freed, scope.poisonsReleasedNodes());
}

test "a poisoning heap poisons to the end of the class, and writes nothing else into the block" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    scope.arena.poison_freed = true;
    const held = ArenaAllocator.heldBytes(100, 8);
    const block = try scope.arena.createRaw(100, 8);
    @memset(block[0..held], 0x11);
    scope.arena.destroyRaw(block, 100, 8);
    for (block[0..held]) |byte| try testing.expectEqual(ArenaAllocator.poison_byte, byte);
    try testing.expectEqual(block, try scope.arena.createRaw(100, 8));
    scope.arena.destroyRaw(block, 100, 8);
}

test "in a task, the bug-finding heap keeps a freed block out of reuse, all poison to the end of its class" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try bugFindingScope(&scope);
    engine.beginTask();
    defer engine.endTask();

    for ([_]usize{ 112, 100 }) |size| {
        const held = ArenaAllocator.heldBytes(size, 8);
        const before = engine.stats().quarantine_bytes;
        const block = try scope.arena.createRaw(size, 8);
        @memset(block[0..held], 0x11);
        scope.arena.destroyRaw(block, size, 8);
        try testing.expectEqual(before + held, engine.stats().quarantine_bytes);
        try testing.expect(engine.isQuarantined(block));
        // The next requests of its class are other blocks; the freed one
        // still reads as poison - what a stale read finds.
        var others: [8][*]u8 = undefined;
        for (&others) |*other| {
            other.* = try scope.arena.createRaw(size, 8);
            try testing.expect(other.* != block);
        }
        for (block[0..held]) |byte| try testing.expectEqual(ArenaAllocator.poison_byte, byte);
        for (others) |other| scope.arena.destroyRaw(other, size, 8);
    }
}

test "the quarantine ends with the task: every held block is free again, lowest first" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try bugFindingScope(&scope);
    const first = try scope.arena.createRaw(112, 8);
    const second = try scope.arena.createRaw(112, 8);
    engine.beginTask();
    scope.arena.destroyRaw(second, 112, 8);
    scope.arena.destroyRaw(first, 112, 8);
    try testing.expect(engine.isQuarantined(first) and engine.isQuarantined(second));
    engine.endTask();
    try testing.expectEqual(@as(usize, 0), engine.stats().quarantine_bytes);
    // Lowest address first, never last in, first out.
    const lower = @min(@intFromPtr(first), @intFromPtr(second));
    const again = try scope.arena.createRaw(112, 8);
    try testing.expectEqual(lower, @intFromPtr(again));
    // Reissued zeroed, as any block is.
    for (again[0..112]) |byte| try testing.expectEqual(@as(u8, 0), byte);
    scope.arena.destroyRaw(again, 112, 8);
}

test "a create/discard loop in a task holds the cap, not the loop" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try bugFindingScope(&scope);
    engine.beginTask();
    defer engine.endTask();
    const size = 112;
    for (0..100_000) |_| {
        const block = try scope.arena.createRaw(size, 8);
        scope.arena.destroyRaw(block, size, 8);
    }
    const stats = engine.stats();
    try testing.expect(stats.quarantine_bytes <= heap.Config.bug_finding_quarantine_cap);
    // 100,000 states of 112 bytes are 11.2 MB; the heap held the cap's
    // worth and evicted at random for the rest.
    try testing.expect(stats.quarantine_total_evicted > 100_000 - heap.Config.bug_finding_quarantine_cap / size - 2);
    try testing.expect(stats.objects.committed_span_bytes <= heap.Config.bug_finding_quarantine_cap + 64 * heap.span_bytes);
}

test "a write after the free is caught when the block is issued again, in the poisoning heap too" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try bugFindingScope(&scope);
    engine.checks = .report;
    const block = try scope.arena.createRaw(112, 8);
    scope.arena.destroyRaw(block, 112, 8);
    // A write through a pointer kept past the free - a node's owner word,
    // at +64.
    block[64] = 0;
    const again = try scope.arena.createRaw(112, 8);
    try testing.expectEqual(block, again);
    try testing.expectEqual(@as(?heap.Violation, .write_after_free), engine.takeViolation());
    scope.arena.destroyRaw(again, 112, 8);
}

test "a large block - past the largest class - is a run of whole spans, poisoned on free and reissued as such" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    _ = try bugFindingScope(&scope);
    const big = try scope.arena.createRaw(20_000, 8);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(big) % heap.span_bytes);
    scope.arena.destroyRaw(big, 20_000, 8);
    // A run's span is the bucket's only one: it is not retired.
    for (big[0..20_000]) |byte| try testing.expectEqual(ArenaAllocator.poison_byte, byte);
    const again = try scope.arena.createRaw(20_000, 8);
    try testing.expectEqual(big, again);
    scope.arena.destroyRaw(again, 20_000, 8);
}
