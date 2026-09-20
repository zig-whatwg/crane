//! Phase 6: discarded state memory must be reusable.
//!
//! The measured problem (`zig build gc-bench`): 10,000 `document.createElement`
//! + discard cycles retain 55 MB, and profiling attributes essentially all of the
//! Zig-side share to one place - the state arena's chunk list, 18 doubling
//! allocations reaching 29.8 MB that are never given back.
//!
//! ## Why not just call reset()
//!
//! `onGCSweep` already exists and calls `ArenaAllocator.reset()`. Nothing calls
//! `onGCSweep`, and wiring it to `AddGCEpilogueCallback` would be worse than the
//! leak: a blanket reset frees the state of every LIVE instance at the same time.
//! The arena is process-global and holds the Window, the Document and every node
//! still in the tree.
//!
//! ## What this requires instead
//!
//! Reuse, not bulk release. A freed state goes onto a free list for its size, and
//! the next state of that size takes it back. Then a create/discard loop occupies
//! a bounded amount of memory no matter how long it runs, which is exactly the
//! exit criterion, and no live instance is ever touched.
//!
//! The size comes from the vtable: `buildVTable` already receives the State type
//! at all 1,271 call sites, so recording its size costs no codegen change.
//!
//! ## Safety
//!
//! Recycling state is not a new category of risk. The slab allocator already
//! recycles Instance handles - `instance.zig` resets lifecycle flags on alloc
//! precisely "because the slab allocator reuses memory addresses". Both frees
//! happen after `vtable.deinit` has run, which is where owned resources are
//! released.

const std = @import("std");
const runtime = @import("runtime");

const ArenaAllocator = runtime.ArenaAllocator;

const SmallState = struct { a: u64, b: u64 };
const LargeState = struct { data: [64]u64 };

test "PHASE 6 EXIT: freed state is handed back out instead of growing the arena" {
    ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    const first = try arena.create(SmallState);
    const first_addr = @intFromPtr(first);
    arena.destroy(SmallState, first);

    const second = try arena.create(SmallState);
    defer arena.destroy(SmallState, second);

    // The same memory, not merely "some memory". Anything else means the create
    // /discard loop still grows without bound, which is the measured bug.
    try std.testing.expectEqual(first_addr, @intFromPtr(second));
}

test "a create/discard loop occupies a bounded amount of memory" {
    // The criterion itself, in miniature: 10,000 cycles must not cost 10,000
    // allocations. Before the free list, `bytes_in_use` rose by sizeof(State)
    // every single iteration.
    ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    var i: usize = 0;
    while (i < 10_000) : (i += 1) {
        const s = try arena.create(SmallState);
        arena.destroy(SmallState, s);
    }

    // One state's worth is outstanding at most - whatever the last iteration took
    // and gave back. Allow a little slack for alignment, but not 10,000 states.
    try std.testing.expect(arena.stats().bytes_in_use <= @sizeOf(SmallState) * 4);
}

test "free lists do not mix sizes" {
    // Handing a small block back for a large request is a buffer overflow, and it
    // would only show up as corruption far from here.
    ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    const small = try arena.create(SmallState);
    arena.destroy(SmallState, small);

    const large = try arena.create(LargeState);
    defer arena.destroy(LargeState, large);

    try std.testing.expect(@intFromPtr(large) != @intFromPtr(small));

    // ...and the small block is still on its own list, unclaimed by the large one.
    const small_again = try arena.create(SmallState);
    defer arena.destroy(SmallState, small_again);
    try std.testing.expectEqual(@intFromPtr(small), @intFromPtr(small_again));
}

test "recycled state is zeroed, as a fresh allocation would be" {
    // `Instance.init` @memsets state to zero because Zig does not apply struct
    // defaults through an allocator. Recycled memory carries the previous
    // occupant's bytes, so if reuse did not clear them, an optional pointer field
    // would come back non-null and be dereferenced.
    ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    const first = try arena.create(SmallState);
    first.* = .{ .a = 0xDEAD_BEEF, .b = 0xFEED_FACE };
    arena.destroy(SmallState, first);

    const second = try arena.create(SmallState);
    defer arena.destroy(SmallState, second);

    try std.testing.expectEqual(@as(u64, 0), second.a);
    try std.testing.expectEqual(@as(u64, 0), second.b);
}

test "bytes_in_use falls when state is freed, unlike the cumulative counter" {
    // `total_bytes_allocated` is cumulative and cannot answer "how much is held" -
    // it rises identically whether or not anything is freed. The benchmark reads
    // this to report retention, so it has to be the live figure.
    ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    const before = arena.stats().bytes_in_use;
    const s = try arena.create(LargeState);
    const during = arena.stats().bytes_in_use;
    arena.destroy(LargeState, s);
    const after = arena.stats().bytes_in_use;

    try std.testing.expect(during >= before + @sizeOf(LargeState));
    try std.testing.expectEqual(before, after);

    // And the cumulative counter still only rises, which is what makes it the
    // wrong number for this question.
    try std.testing.expect(arena.stats().total_bytes_allocated >= @sizeOf(LargeState));
}

test "the vtable carries its state size, so a freed instance knows what to return" {
    // `Instance.deinit` has a `*Instance` and nothing else. Without the size on the
    // vtable it cannot put the state on the right free list, and every call site
    // that builds a vtable already passes the State type - so this costs no
    // codegen change.
    const State = struct { base: void, mixins: struct {}, own: struct { x: u64 } };
    // comptime: buildVTable walks the state ancestry, which only exists at compile
    // time. Every generated interface already builds its vtable this way.
    const vtable = comptime blk: {
        const delegates = .{};
        break :blk runtime.buildVTable(&delegates, "TestInterface", State);
    };

    try std.testing.expectEqual(@sizeOf(State), vtable.state_size);
    try std.testing.expectEqual(@alignOf(State), vtable.state_align);
}
