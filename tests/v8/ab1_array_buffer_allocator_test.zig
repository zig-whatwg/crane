//! Crane's in-sandbox allocator as the process runs it (lane ab1): the one
//! v8_Platform_Start hands to V8, behind every isolate's ArrayBuffer
//! allocator (v8_wrapper.cpp CraneInSandboxAllocator,
//! CraneArrayBufferAllocator). Its data structure is tested over a model
//! address space in ab1_sandbox_allocator_test.zig, and what the OS charges
//! in ab1_array_buffer_footprint_test.zig; here: its lifetime (a
//! BackingStore that outlives the isolate that allocated it, released on
//! another thread), its lock (threads allocating at once), and its zero-fill
//! on real memory.

const std = @import("std");
const test_process = @import("test_process.zig");
const v8 = @import("v8");
const ffi = v8.ffi;
const sa = v8.sandbox_allocator;
const hooks = v8.sandbox_allocator_exports;

const testing = std.testing;

const MiB: usize = 1024 * 1024;

fn stats() !sa.Stats {
    var out: sa.Stats = .{};
    if (!hooks.v8_test_SandboxAllocator_Stats(&out)) return error.NoSandboxAllocator;
    return out;
}

test "every isolate allocates ArrayBuffers from the process's in-sandbox allocator" {
    var agent: test_process.TestAgent = .{};
    const isolate = try agent.open(.{});
    defer agent.close();

    const first = ffi.v8_ArrayBuffer_New(isolate, 3 * MiB) orelse return error.ArrayBufferAllocationFailed;
    const before = try stats();
    const buffer = ffi.v8_ArrayBuffer_New(isolate, 3 * MiB) orelse return error.ArrayBufferAllocationFailed;
    const with = try stats();
    // A 3 MiB block is a run of three chunks; the count is the process's,
    // which V8's own threads may move by a small block at any time.
    try testing.expect(with.live_bytes >= before.live_bytes + 3 * MiB);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(ffi.v8_ArrayBuffer_Data(buffer).?) % sa.chunk_size);

    ffi.v8_ArrayBuffer_Detach(buffer);
    ffi.v8_ArrayBuffer_Dispose(buffer);
    const after = try stats();
    try testing.expect(after.live_bytes + 3 * MiB <= with.live_bytes + 64 * 1024);
    ffi.v8_ArrayBuffer_Detach(first);
    ffi.v8_ArrayBuffer_Dispose(first);
}

test "a 1 MiB ArrayBuffer made and detached in a loop: no page operation per round" {
    var agent: test_process.TestAgent = .{};
    const isolate = try agent.open(.{});
    defer agent.close();

    // A live buffer above the loop's, so that a freed chunk is not simply
    // the top of the used range.
    const top = ffi.v8_ArrayBuffer_New(isolate, 3 * MiB) orelse return error.ArrayBufferAllocationFailed;
    defer ffi.v8_ArrayBuffer_Dispose(top);

    const rounds = 500;
    var before: sa.Stats = undefined;
    var round: usize = 0;
    while (round < rounds + 2) : (round += 1) {
        // The first two rounds settle which chunk the loop uses.
        if (round == 2) before = try stats();
        const buffer = ffi.v8_ArrayBuffer_New(isolate, MiB) orelse return error.ArrayBufferAllocationFailed;
        const data: [*]u8 = @ptrCast(ffi.v8_ArrayBuffer_Data(buffer).?);
        // Zero each time, though the round before wrote it.
        try testing.expectEqual(@as(u8, 0), data[0]);
        try testing.expectEqual(@as(u8, 0), data[MiB - 1]);
        data[0] = 0xee;
        data[MiB - 1] = 0xee;
        // Detaching frees the store at once.
        ffi.v8_ArrayBuffer_Detach(buffer);
        ffi.v8_ArrayBuffer_Dispose(buffer);
    }
    const after = try stats();
    // V8's default discarded the chunk at every free; with a discard and a
    // recommit per round this would read 1,000. The process's other users
    // may make a few page operations of their own meanwhile.
    const moved = (after.discards - before.discards) + (after.recommits - before.recommits) +
        (after.decommits - before.decommits) + (after.grows - before.grows);
    if (moved > 8) {
        std.debug.print("{d} page operations in {d} rounds: discards {d}, recommits {d}, decommits {d}, grows {d}\n", .{ moved, rounds, after.discards - before.discards, after.recommits - before.recommits, after.decommits - before.decommits, after.grows - before.grows });
        return error.PageOperationPerRound;
    }
}

fn releaseOnThisThread(held: *hooks.HeldBackingStore) void {
    hooks.v8_test_BackingStore_Release(held);
}

test "a BackingStore outlives the isolate that allocated it and is freed on another thread" {
    var held: *hooks.HeldBackingStore = undefined;
    var with: sa.Stats = undefined;
    {
        var agent: test_process.TestAgent = .{};
        const isolate = try agent.open(.{});
        defer agent.close();
        const buffer = ffi.v8_ArrayBuffer_New(isolate, 2 * MiB) orelse return error.ArrayBufferAllocationFailed;
        defer ffi.v8_ArrayBuffer_Dispose(buffer);
        // Held as a transferred ArrayBuffer's store is: by no isolate.
        held = hooks.v8_test_BackingStore_Hold(buffer);
        with = try stats();
    }
    // The isolate has ended; the store, and its memory, have not.
    const data: [*]u8 = @ptrCast(hooks.v8_test_BackingStore_Data(held).?);
    @memset(data[0 .. 2 * MiB], 0x5a);
    try testing.expectEqual(@as(u8, 0x5a), data[2 * MiB - 1]);
    try testing.expect((try stats()).live_bytes + 64 * 1024 >= with.live_bytes);

    // Its last reference goes on another thread, as V8's sweeper or a
    // worker's end would drop it: the block returns to the allocator.
    const thread = try std.Thread.spawn(.{}, releaseOnThisThread, .{held});
    thread.join();
    try testing.expect((try stats()).live_bytes + 2 * MiB <= with.live_bytes + 64 * 1024);
}

test "a zero-filled block reads zero where a freed block's bytes were" {
    test_process.start();
    // A size no other user of the process is likely to ask for: 3,000 bytes
    // is the 3,072-byte class.
    const size = 3000;
    var dirty: [64][*]u8 = undefined;
    for (&dirty) |*block| {
        block.* = hooks.v8_test_SandboxAllocator_Allocate(size, false) orelse return error.NoBlock;
        try testing.expectEqual(@as(usize, 0), @intFromPtr(block.*) % sa.alignment);
        @memset(block.*[0..size], 0xff);
    }
    for (dirty) |block| hooks.v8_test_SandboxAllocator_Free(block);

    var clean: [64][*]u8 = undefined;
    var reused: usize = 0;
    for (&clean) |*block| {
        block.* = hooks.v8_test_SandboxAllocator_Allocate(size, true) orelse return error.NoBlock;
        try testing.expect(std.mem.allEqual(u8, block.*[0..size], 0));
        for (dirty) |old| reused += @intFromBool(old == block.*);
    }
    for (clean) |block| hooks.v8_test_SandboxAllocator_Free(block);
    // The freed slots were handed out again (the lowest free slot first), so
    // the zeroes above were written over 0xff.
    try testing.expect(reused >= 32);
}

const Worker = struct {
    seed: u64,
    failed: bool = false,

    const rounds = 20_000;
    const held = 32;

    /// Allocate, fill with the thread's own byte, check and free: a block
    /// two threads were both given shows as the other's byte.
    fn run(self: *Worker) void {
        var prng = std.Random.DefaultPrng.init(self.seed);
        const random = prng.random();
        const mark: u8 = @truncate(self.seed);
        var blocks: [held]?[]u8 = @splat(null);
        var round: usize = 0;
        while (round < rounds) : (round += 1) {
            const slot = random.uintLessThan(usize, held);
            if (blocks[slot]) |block| {
                if (!std.mem.allEqual(u8, block, mark)) self.failed = true;
                hooks.v8_test_SandboxAllocator_Free(block.ptr);
                blocks[slot] = null;
                continue;
            }
            const size: usize = switch (random.uintLessThan(u32, 100)) {
                0...79 => 1 + random.uintLessThan(usize, 512),
                80...98 => 1 + random.uintLessThan(usize, 96 * 1024),
                else => MiB + random.uintLessThan(usize, MiB),
            };
            const zero = random.boolean();
            const block = hooks.v8_test_SandboxAllocator_Allocate(size, zero) orelse {
                self.failed = true;
                return;
            };
            if (zero and !std.mem.allEqual(u8, block[0..size], 0)) self.failed = true;
            @memset(block[0..size], mark);
            blocks[slot] = block[0..size];
        }
        for (blocks) |maybe| if (maybe) |block| {
            if (!std.mem.allEqual(u8, block, mark)) self.failed = true;
            hooks.v8_test_SandboxAllocator_Free(block.ptr);
        };
    }
};

test "four threads allocate and free at once: no block is given to two of them" {
    test_process.start();
    const before = try stats();
    var workers: [4]Worker = undefined;
    var threads: [4]std.Thread = undefined;
    for (&workers, 0..) |*worker, i| worker.* = .{ .seed = 0xa1 + i };
    for (&threads, &workers) |*thread, *worker| thread.* = try std.Thread.spawn(.{}, Worker.run, .{worker});
    for (threads) |thread| thread.join();
    for (workers) |worker| try testing.expect(!worker.failed);
    // Everything the threads took is back (V8's own threads may hold a
    // small block of their own).
    const after = try stats();
    try testing.expect(after.live_bytes <= before.live_bytes + 64 * 1024);
    // What waits to be reused is bounded.
    try testing.expect(after.retained_bytes <= sa.retained_max);
}
