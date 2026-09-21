//! An interface whose State is zero-sized must be instantiable.
//!
//! `ArenaAllocator.create(T)` forwards `@sizeOf(T)` to `createRaw`, which hands
//! it to std's `ArenaAllocator.rawAlloc`. That function opens with
//! `assert(n > 0)` (std/heap/ArenaAllocator.zig:493), so a zero-sized state
//! aborted the process:
//!
//!     thread ... panic: reached unreachable code
//!       std.debug.assert
//!       heap.ArenaAllocator.alloc
//!       arena_allocator.ArenaAllocator.createRaw        (:190)
//!       instance.Instance.init                          (:130)
//!       interface.V8Interface(URL).StaticMethodCallback("call_static_createObjectURL")
//!
//! Zero-sized states are not exotic here. Any interface that keeps no internal
//! state has one - `Geolocation.zig` and `Clipboard.zig` both declare
//! `InternalState = struct {}` - and every such interface aborted the whole
//! process the first time script touched it. This was one of the systemic crash
//! clusters behind `html/syntax/parsing` at a 57.9% crash rate.
//!
//! Zig's allocator contract already says what to do: a zero-length allocation
//! returns a non-null, correctly-aligned pointer that must never be
//! dereferenced. These tests pin that.

const std = @import("std");
const runtime = @import("runtime");

const ArenaAllocator = runtime.ArenaAllocator;

test "createRaw survives a zero-byte request" {
    ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();
    const arena = ArenaAllocator.get();

    // The call that aborted. It must return a usable, aligned pointer.
    const ptr = try arena.createRaw(0, @alignOf(u64));
    try std.testing.expect(@intFromPtr(ptr) != 0);
    try std.testing.expect(std.mem.isAligned(@intFromPtr(ptr), @alignOf(u64)));
}

test "create() of a zero-sized struct returns an aligned pointer" {
    ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();
    const arena = ArenaAllocator.get();

    // The shape real interfaces have: an InternalState holding nothing.
    const Empty = struct {};
    try std.testing.expectEqual(@as(usize, 0), @sizeOf(Empty));

    const p = try arena.create(Empty);
    try std.testing.expect(@intFromPtr(p) != 0);
}

test "destroyRaw of a zero-byte block is a no-op, not a corruption" {
    ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();
    const arena = ArenaAllocator.get();

    const ptr = try arena.createRaw(0, @alignOf(u64));

    // The free path must not push a zero-byte block onto a size-class free
    // list: a later allocation of that class would hand back a pointer into
    // nothing. Round-tripping must leave the accounting where it started.
    const before = arena.stats().bytes_in_use;
    arena.destroyRaw(ptr, 0, @alignOf(u64));
    try std.testing.expectEqual(before, arena.stats().bytes_in_use);
}

test "a zero-byte block is never recycled into a real allocation" {
    ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();
    const arena = ArenaAllocator.get();

    const zero = try arena.createRaw(0, @alignOf(u64));
    arena.destroyRaw(zero, 0, @alignOf(u64));

    // If the zero-byte pointer had gone onto a free list, this could return it.
    const real = try arena.createRaw(64, @alignOf(u64));
    try std.testing.expect(@intFromPtr(real) != @intFromPtr(zero));

    // And it must be genuinely writable for its whole length.
    @memset(real[0..64], 0xAB);
    try std.testing.expectEqual(@as(u8, 0xAB), real[63]);
}
