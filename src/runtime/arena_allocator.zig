//! Arena allocator for variable-sized FullState allocations
//!
//! This allocator manages FullState structs (variable sizes) using an arena
//! approach for fast allocation with batch deallocation during GC sweeps.
//!
//! Design:
//! - Wraps std.heap.ArenaAllocator for bump allocation
//! - No individual frees (arena reset during GC sweep)
//! - Supports variable-size allocations (Node, Element, Text have different sizes)
//! - Reset retains capacity for next GC cycle
//!
//! Thread safety: Single-threaded (no locks)

const std = @import("std");

/// Arena allocator for variable-sized FullState structs
pub const ArenaAllocator = struct {
    /// Underlying arena allocator
    arena: std.heap.ArenaAllocator,

    /// Statistics
    total_allocations: usize,
    total_bytes_allocated: usize,
    total_resets: usize,

    /// Global instance
    var global: ?ArenaAllocator = null;

    /// Initialize the global arena allocator
    pub fn init(backing_allocator: std.mem.Allocator) void {
        global = ArenaAllocator{
            .arena = std.heap.ArenaAllocator.init(backing_allocator),
            .total_allocations = 0,
            .total_bytes_allocated = 0,
            .total_resets = 0,
        };
    }

    /// Get the global arena allocator instance
    pub fn get() *ArenaAllocator {
        return &(global orelse @panic("ArenaAllocator not initialized - call init() first"));
    }

    /// Deinitialize the global allocator
    pub fn deinit() void {
        if (global) |*g| {
            g.arena.deinit();
            global = null;
        }
    }

    /// Create (allocate) a single instance of type T
    ///
    /// This is the primary allocation method used by generated code:
    ///   const state = try ArenaAllocator.get().create(FullState);
    pub fn create(self: *ArenaAllocator, comptime T: type) !*T {
        const ptr = try self.arena.allocator().create(T);
        self.total_allocations += 1;
        self.total_bytes_allocated += @sizeOf(T);
        return ptr;
    }

    /// Allocate a slice of items
    pub fn alloc(self: *ArenaAllocator, comptime T: type, n: usize) ![]T {
        const slice = try self.arena.allocator().alloc(T, n);
        self.total_allocations += 1;
        self.total_bytes_allocated += @sizeOf(T) * n;
        return slice;
    }

    /// Duplicate a slice
    pub fn dupe(self: *ArenaAllocator, comptime T: type, m: []const T) ![]T {
        const slice = try self.arena.allocator().dupe(T, m);
        self.total_allocations += 1;
        self.total_bytes_allocated += @sizeOf(T) * m.len;
        return slice;
    }

    /// Reset the arena (called during GC sweep phase)
    ///
    /// Frees all allocated memory but retains capacity for next cycle.
    /// This is much faster than individual frees.
    ///
    /// Important: Caller must ensure all FullState deinit() functions
    /// have been called before reset to clean up owned resources.
    pub fn reset(self: *ArenaAllocator) void {
        _ = self.arena.reset(.retain_capacity);
        self.total_resets += 1;
        // Note: We don't reset statistics - they're cumulative
    }

    /// Get allocation statistics
    pub fn stats(self: *const ArenaAllocator) Stats {
        return Stats{
            .total_allocations = self.total_allocations,
            .total_bytes_allocated = self.total_bytes_allocated,
            .total_resets = self.total_resets,
            .arena_state = self.arena.state,
        };
    }

    /// Allocation statistics
    pub const Stats = struct {
        total_allocations: usize,
        total_bytes_allocated: usize,
        total_resets: usize,
        arena_state: std.heap.ArenaAllocator.State,
    };
};

// Unit tests
const testing = std.testing;

test "ArenaAllocator init and deinit" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();
    try testing.expect(arena.total_allocations == 0);
    try testing.expect(arena.total_bytes_allocated == 0);
}

test "ArenaAllocator.create allocates single item" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    const TestStruct = struct {
        value: u32,
    };

    const item = try arena.create(TestStruct);
    item.value = 42;

    try testing.expectEqual(@as(u32, 42), item.value);
    try testing.expectEqual(@as(usize, 1), arena.total_allocations);
    try testing.expectEqual(@as(usize, @sizeOf(TestStruct)), arena.total_bytes_allocated);
}

test "ArenaAllocator.create multiple items" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    const TestStruct = struct {
        value: u32,
    };

    const item1 = try arena.create(TestStruct);
    const item2 = try arena.create(TestStruct);
    const item3 = try arena.create(TestStruct);

    item1.value = 1;
    item2.value = 2;
    item3.value = 3;

    try testing.expectEqual(@as(u32, 1), item1.value);
    try testing.expectEqual(@as(u32, 2), item2.value);
    try testing.expectEqual(@as(u32, 3), item3.value);

    try testing.expectEqual(@as(usize, 3), arena.total_allocations);
    try testing.expectEqual(@as(usize, @sizeOf(TestStruct) * 3), arena.total_bytes_allocated);
}

test "ArenaAllocator.alloc allocates slice" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    const slice = try arena.alloc(u32, 10);
    try testing.expectEqual(@as(usize, 10), slice.len);

    for (slice, 0..) |*item, i| {
        item.* = @intCast(i);
    }

    for (slice, 0..) |item, i| {
        try testing.expectEqual(@as(u32, @intCast(i)), item);
    }

    try testing.expectEqual(@as(usize, 1), arena.total_allocations);
    try testing.expectEqual(@as(usize, @sizeOf(u32) * 10), arena.total_bytes_allocated);
}

test "ArenaAllocator.dupe duplicates slice" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    const original = [_]u32{ 1, 2, 3, 4, 5 };
    const duplicated = try arena.dupe(u32, &original);

    try testing.expectEqual(original.len, duplicated.len);
    for (original, duplicated) |orig, dup| {
        try testing.expectEqual(orig, dup);
    }

    // Verify they're different allocations
    try testing.expect(&original[0] != &duplicated[0]);

    try testing.expectEqual(@as(usize, 1), arena.total_allocations);
    try testing.expectEqual(@as(usize, @sizeOf(u32) * 5), arena.total_bytes_allocated);
}

test "ArenaAllocator.reset frees memory but retains capacity" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    // Allocate some items
    _ = try arena.create(u32);
    _ = try arena.create(u64);
    _ = try arena.alloc(u8, 100);

    const stats_before = arena.stats();
    try testing.expectEqual(@as(usize, 3), stats_before.total_allocations);

    // Reset
    arena.reset();

    const stats_after = arena.stats();
    try testing.expectEqual(@as(usize, 3), stats_after.total_allocations); // Cumulative
    try testing.expectEqual(@as(usize, 1), stats_after.total_resets);

    // Can allocate again after reset
    const item = try arena.create(u32);
    item.* = 42;
    try testing.expectEqual(@as(u32, 42), item.*);
}

test "ArenaAllocator supports variable-sized types" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    const SmallStruct = struct {
        value: u8,
    };

    const MediumStruct = struct {
        value: u64,
        data: [16]u8,
    };

    const LargeStruct = struct {
        values: [100]u64,
    };

    _ = try arena.create(SmallStruct);
    _ = try arena.create(MediumStruct);
    _ = try arena.create(LargeStruct);

    try testing.expectEqual(@as(usize, 3), arena.total_allocations);

    const expected_bytes = @sizeOf(SmallStruct) + @sizeOf(MediumStruct) + @sizeOf(LargeStruct);
    try testing.expectEqual(expected_bytes, arena.total_bytes_allocated);
}

test "ArenaAllocator.stats accuracy" {
    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const arena = ArenaAllocator.get();

    // Initial stats
    var s = arena.stats();
    try testing.expectEqual(@as(usize, 0), s.total_allocations);
    try testing.expectEqual(@as(usize, 0), s.total_bytes_allocated);
    try testing.expectEqual(@as(usize, 0), s.total_resets);

    // Allocate some items
    _ = try arena.create(u32);
    _ = try arena.alloc(u64, 5);

    s = arena.stats();
    try testing.expectEqual(@as(usize, 2), s.total_allocations);
    try testing.expectEqual(@as(usize, @sizeOf(u32) + @sizeOf(u64) * 5), s.total_bytes_allocated);

    // Reset
    arena.reset();

    s = arena.stats();
    try testing.expectEqual(@as(usize, 2), s.total_allocations); // Cumulative
    try testing.expectEqual(@as(usize, 1), s.total_resets);

    // Allocate more after reset
    _ = try arena.create(u8);

    s = arena.stats();
    try testing.expectEqual(@as(usize, 3), s.total_allocations);
    try testing.expectEqual(@as(usize, 1), s.total_resets); // Still 1 reset
}
