//! The quarantine of a poisoning arena (lane uaf1; the HIGH safety item
//! "does any code read a released node's NodeBase after its block went back
//! to the arena?").
//!
//! The arena handed a freed state block to the very next request of its
//! size class (a LIFO free list). So the poison a detection build writes
//! over a freed block was readable only until the next node of that size
//! was made: a read through a pointer kept past the free found the NEW
//! occupant, in every build, and no gate saw it. A poisoning arena now
//! keeps a freed block out of reuse - all poison, in a FIFO queue with a
//! byte budget, as AddressSanitizer's quarantine does - and checks that it
//! is still all poison when it leaves the queue (a write after the free).
//! Production keeps the LIFO lists: `createRaw` is the same code either way.
//!
//! RED at 7fd36b074a9 (lane wb1's tip merged, before the quarantine): no
//! `quarantine_bytes`, and a poisoned block comes straight back.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");

const ArenaAllocator = runtime.ArenaAllocator;
const has_quarantine = @hasDecl(ArenaAllocator, "quarantine_bytes");

/// The queue's header: its link and the block's class.
const header = 2 * @sizeOf(usize);

fn poisoningArena() ArenaAllocator {
    var arena = ArenaAllocator.init(testing.allocator);
    arena.poison_freed = true;
    return arena;
}

test "a bare arena does not poison or quarantine: a freed block goes to the next request of its class" {
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expect(!arena.poison_freed);
    const block = try arena.createRaw(112, 8);
    arena.destroyRaw(block, 112, 8);
    if (has_quarantine) try testing.expectEqual(@as(usize, 0), arena.quarantinedBytes());
    const again = try arena.createRaw(112, 8);
    try testing.expectEqual(block, again);
    arena.destroyRaw(again, 112, 8);
}

test "a scope's arena poisons freed state by default in a Debug build, and in no release build" {
    if (comptime !@hasDecl(runtime.BrowserScope, "poisonsFreedStateByDefault")) return error.NoDebugDefault;
    const rule = runtime.BrowserScope.poisonsFreedStateByDefault;
    try testing.expect(rule(.debug));
    inline for (.{ std.builtin.OptimizeMode.safe, .fast, .small }) |mode| try testing.expect(!rule(mode));

    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    try testing.expectEqual(rule(@import("builtin").mode), scope.arena.poison_freed);
    // A released NodeBase is poisoned wherever a freed block is.
    try testing.expectEqual(scope.arena.poison_freed, scope.poisonsReleasedNodes());
}

test "a poisoning arena keeps a freed block out of reuse, all poison to the end of its class" {
    if (comptime !has_quarantine) return error.NoQuarantine;
    var arena = poisoningArena();
    defer arena.deinit();

    // A div-sized state: 112 bytes, its own class; and a request that does
    // not fill its class (100 -> 112): the whole block is poisoned.
    for ([_]usize{ 112, 100 }) |size| {
        const held = ArenaAllocator.heldBytes(size, 8);
        const before = arena.quarantinedBytes();
        const block = try arena.createRaw(size, 8);
        @memset(block[0..held], 0x11);
        arena.destroyRaw(block, size, 8);
        try testing.expectEqual(before + held, arena.quarantinedBytes());
        for (block[header..held]) |byte| try testing.expectEqual(ArenaAllocator.poison_byte, byte);

        // The next requests of its class are other blocks; the freed one
        // still reads as poison - what a stale read finds.
        var others: [8][*]u8 = undefined;
        for (&others) |*other| {
            other.* = try arena.createRaw(size, 8);
            try testing.expect(other.* != block);
        }
        for (block[header..held]) |byte| try testing.expectEqual(ArenaAllocator.poison_byte, byte);
        try testing.expectEqual(@as(?usize, null), ArenaAllocator.firstNonPoison(block[header..held]));
        for (others) |other| arena.destroyRaw(other, size, 8);
    }
}

test "the quarantine is bounded and first in, first out: the oldest block is reissued once the budget is behind it" {
    if (comptime !has_quarantine) return error.NoQuarantine;
    var arena = poisoningArena();
    defer arena.deinit();

    const size = 112;
    const first = try arena.createRaw(size, 8);
    const second = try arena.createRaw(size, 8);
    arena.destroyRaw(first, size, 8);
    arena.destroyRaw(second, size, 8);

    // Newer frees of ANOTHER class push them out: the budget is the
    // arena's, in bytes, not a class's.
    const filler = 4096;
    var freed: usize = 0;
    var kept: std.ArrayList([*]u8) = .empty;
    defer kept.deinit(testing.allocator);
    while (freed <= ArenaAllocator.quarantine_bytes) : (freed += filler) {
        try kept.append(testing.allocator, try arena.createRaw(filler, 8));
    }
    for (kept.items) |block| {
        arena.destroyRaw(block, filler, 8);
        try testing.expect(arena.quarantinedBytes() <= ArenaAllocator.quarantine_bytes);
    }

    // Both left the queue, oldest first: they are on their class's free
    // list, which is last in, first out - `second` on top.
    try testing.expectEqual(second, try arena.createRaw(size, 8));
    const first_again = try arena.createRaw(size, 8);
    try testing.expectEqual(first, first_again);
    // Reissued zeroed, as any block is.
    for (first_again[0..size]) |byte| try testing.expectEqual(@as(u8, 0), byte);
    arena.destroyRaw(first, size, 8);
    arena.destroyRaw(second, size, 8);
}

test "a create/discard loop in a poisoning arena holds the budget, not the loop" {
    if (comptime !has_quarantine) return error.NoQuarantine;
    var arena = poisoningArena();
    defer arena.deinit();
    const size = 112;
    var i: usize = 0;
    while (i < 100_000) : (i += 1) {
        const block = try arena.createRaw(size, 8);
        arena.destroyRaw(block, size, 8);
    }
    try testing.expect(arena.quarantinedBytes() <= ArenaAllocator.quarantine_bytes);
    // 100,000 states of 112 bytes are 11.2 MB; the arena took the budget's
    // worth of new blocks and one more, and recycled for the rest.
    const stats = arena.stats();
    const new_blocks = stats.total_allocations - stats.total_recycled;
    try testing.expect(new_blocks * size <= ArenaAllocator.quarantine_bytes + 2 * size);
    try testing.expect(stats.total_recycled > 80_000);
}

test "the write check's question: the first byte of a quarantined block that is not the poison" {
    if (comptime !has_quarantine) return error.NoQuarantine;
    var arena = poisoningArena();
    defer arena.deinit();
    const block = try arena.createRaw(112, 8);
    arena.destroyRaw(block, 112, 8);
    try testing.expectEqual(@as(?usize, null), ArenaAllocator.firstNonPoison(block[header..112]));
    // A write through a pointer kept past the free - a node's owner word,
    // at +64 - is what the block's exit from the queue panics on. Asked
    // here as the question; undone, so this arena's end does not panic.
    const saved = block[64];
    block[64] = 0;
    try testing.expectEqual(@as(?usize, 64 - header), ArenaAllocator.firstNonPoison(block[header..112]));
    block[64] = saved;
    try testing.expectEqual(@as(?usize, null), ArenaAllocator.firstNonPoison(block[header..112]));
}

test "a block of no class is poisoned and never reissued; a reset drops the queue" {
    if (comptime !has_quarantine) return error.NoQuarantine;
    var arena = poisoningArena();
    defer arena.deinit();
    const big = try arena.createRaw(20_000, 8);
    arena.destroyRaw(big, 20_000, 8);
    try testing.expectEqual(@as(usize, 0), arena.quarantinedBytes());
    for (big[0..20_000]) |byte| try testing.expectEqual(ArenaAllocator.poison_byte, byte);

    const block = try arena.createRaw(112, 8);
    arena.destroyRaw(block, 112, 8);
    try testing.expect(arena.quarantinedBytes() != 0);
    arena.reset();
    try testing.expectEqual(@as(usize, 0), arena.quarantinedBytes());
}
