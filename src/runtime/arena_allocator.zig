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

    /// Bytes currently held by live states - allocated and not yet destroyed.
    ///
    /// `total_bytes_allocated` is cumulative and cannot answer "how much is held":
    /// it rises identically whether or not anything is freed, which is exactly why
    /// the retention it was used to report looked unfixable.
    bytes_in_use: usize = 0,

    /// Free lists, one per size class, of blocks handed back by `destroy`.
    ///
    /// This is what makes a create/discard loop bounded. The arena underneath still
    /// only grows - it has no way to release an individual block - but a freed
    /// block is handed straight back out, so the loop stops asking for new memory.
    ///
    /// Reuse rather than `reset()` deliberately. The arena is process-global and
    /// holds the Window, the Document and every node still in the tree, so a
    /// blanket reset would free live state along with dead. Reuse touches only
    /// blocks their owners have already given up.
    free_lists: [size_class_count]?*FreeBlock = @splat(null),
    /// Blocks recycled rather than taken from the arena. Diagnostic: if this stays
    /// at zero while a discard loop runs, states are not being returned at all.
    total_recycled: usize = 0,

    /// Global instance
    var global: ?ArenaAllocator = null;

    /// A freed block, with the next pointer written into the block itself.
    ///
    /// Costs no side allocation, which matters because this runs on the free path
    /// of every DOM node. It does require every recycled block to be at least
    /// pointer-sized and pointer-aligned; `sizeClassOf` enforces that by refusing
    /// anything smaller.
    const FreeBlock = struct {
        next: ?*FreeBlock,
    };

    /// Size classes are powers of two from 16 bytes to 16 KiB.
    ///
    /// Exact-size lists would be ideal but there are 1,263 distinct state types;
    /// power-of-two classes keep the table small while guaranteeing a block is
    /// never handed to a request larger than itself - the failure that would turn
    /// into silent corruption far from here.
    const min_class_shift = 4; // 16 bytes
    const max_class_shift = 14; // 16 KiB
    const size_class_count = max_class_shift - min_class_shift + 1;

    /// The class a request of `size`/`alignment` belongs to, or null if it must not
    /// be recycled.
    ///
    /// Null for anything under 16 bytes (no room for the next pointer), anything
    /// over 16 KiB (rare, and pooling them would hold a lot of memory hostage), and
    /// anything needing alignment beyond the class size.
    fn sizeClassOf(size: usize, alignment: usize) ?usize {
        if (size < @sizeOf(FreeBlock) or alignment > @alignOf(FreeBlock)) return null;

        var shift: usize = min_class_shift;
        while (shift <= max_class_shift) : (shift += 1) {
            const class_size = @as(usize, 1) << @intCast(shift);
            if (size <= class_size and alignment <= class_size) {
                return shift - min_class_shift;
            }
        }
        return null;
    }

    /// Bytes a block of the given class holds.
    fn classSize(class: usize) usize {
        return @as(usize, 1) << @intCast(class + min_class_shift);
    }

    /// Take a block of `class` off its free list, or null if the list is empty.
    fn popFree(self: *ArenaAllocator, class: usize) ?[*]u8 {
        const head = self.free_lists[class] orelse return null;
        self.free_lists[class] = head.next;
        self.total_recycled += 1;
        return @ptrCast(head);
    }

    /// Put a block of `class` back on its free list.
    fn pushFree(self: *ArenaAllocator, class: usize, ptr: [*]u8) void {
        const block: *FreeBlock = @ptrCast(@alignCast(ptr));
        block.next = self.free_lists[class];
        self.free_lists[class] = block;
    }

    /// Initialize the global arena allocator
    pub fn init(backing_allocator: std.mem.Allocator) void {
        global = ArenaAllocator{
            .arena = std.heap.ArenaAllocator.init(backing_allocator),
            .total_allocations = 0,
            .total_bytes_allocated = 0,
            .total_resets = 0,
        };
    }

    /// Error type for arena allocator operations
    pub const ArenaError = error{
        /// The allocator was not initialized before use
        NotInitialized,
    };

    /// Get the global arena allocator instance
    /// Panics if the allocator was not initialized - this is a programming error.
    /// Use tryGet() for error-returning variant.
    pub fn get() *ArenaAllocator {
        return &(global orelse @panic("ArenaAllocator not initialized - call init() first"));
    }

    /// Get the global arena allocator instance, returning error if not initialized
    /// Use this in contexts where you need to handle missing initialization gracefully.
    pub fn tryGet() ArenaError!*ArenaAllocator {
        if (global) |*g| {
            return g;
        }
        return ArenaError.NotInitialized;
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
        return @ptrCast(@alignCast(try self.createRaw(@sizeOf(T), @alignOf(T))));
    }

    /// `create` for a size known only at runtime.
    ///
    /// `Instance.deinit` has a `*Instance` and a vtable, not a type, so the free
    /// path is necessarily untyped; the allocate path has to match it or the two
    /// would disagree about which class a block belongs to.
    ///
    /// The returned memory is ZEROED. `Instance.init` already memsets state,
    /// because Zig does not apply struct defaults through an allocator - but a
    /// recycled block also carries the previous occupant's bytes, and an optional
    /// pointer field coming back non-null would be dereferenced.
    pub fn createRaw(self: *ArenaAllocator, size: usize, alignment: usize) ![*]u8 {
        self.total_allocations += 1;
        self.total_bytes_allocated += size;
        self.bytes_in_use += size;

        if (sizeClassOf(size, alignment)) |class| {
            if (self.popFree(class)) |recycled| {
                @memset(recycled[0..classSize(class)], 0);
                return recycled;
            }
            // Allocate the whole class, not the request: the block goes back on
            // this class's list, and a later request in the same class may be
            // larger than this one.
            const bytes = try self.arena.allocator().alignedAlloc(
                u8,
                .of(FreeBlock),
                classSize(class),
            );
            @memset(bytes, 0);
            return bytes.ptr;
        }

        const bytes = self.arena.allocator().rawAlloc(
            size,
            std.mem.Alignment.fromByteUnits(@max(alignment, 1)),
            @returnAddress(),
        ) orelse return error.OutOfMemory;
        @memset(bytes[0..size], 0);
        return bytes;
    }

    /// Hand a state block back for reuse.
    ///
    /// Callers must have run the type's own cleanup first - this releases the
    /// block, not what it points to. Both call sites (`Instance.deinit` and
    /// `gc_integration.onObjectFreed`) invoke `vtable.deinit` before getting here,
    /// which is the same ordering the slab allocator already relies on for the
    /// Instance handle.
    pub fn destroy(self: *ArenaAllocator, comptime T: type, ptr: *T) void {
        self.destroyRaw(@ptrCast(ptr), @sizeOf(T), @alignOf(T));
    }

    /// `destroy` for a size known only at runtime - the shape the vtable provides.
    ///
    /// A block outside every size class is simply dropped: the arena cannot release
    /// an individual allocation, so the alternative to leaking it is corrupting
    /// something. `bytes_in_use` is still decremented, so the figure stays honest
    /// about what callers hold rather than what the arena has reserved.
    pub fn destroyRaw(self: *ArenaAllocator, ptr: [*]u8, size: usize, alignment: usize) void {
        self.bytes_in_use -|= size;
        if (sizeClassOf(size, alignment)) |class| {
            self.pushFree(class, ptr);
        }
    }

    /// Allocate a slice of items
    pub fn alloc(self: *ArenaAllocator, comptime T: type, n: usize) ![]T {
        const slice = try self.arena.allocator().alloc(T, n);
        self.total_allocations += 1;
        self.total_bytes_allocated += @sizeOf(T) * n;
        self.bytes_in_use += @sizeOf(T) * n;
        return slice;
    }

    /// Duplicate a slice
    pub fn dupe(self: *ArenaAllocator, comptime T: type, m: []const T) ![]T {
        const slice = try self.arena.allocator().dupe(T, m);
        self.total_allocations += 1;
        self.total_bytes_allocated += @sizeOf(T) * m.len;
        self.bytes_in_use += @sizeOf(T) * m.len;
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
        // The free lists point into the memory just released. Dropping them is not
        // optional: reusing a block from a reset arena hands out memory the arena
        // has already given to someone else.
        self.free_lists = @splat(null);
        self.bytes_in_use = 0;
        // Note: We don't reset statistics - they're cumulative
    }

    /// Get allocation statistics
    pub fn stats(self: *const ArenaAllocator) Stats {
        return Stats{
            .total_allocations = self.total_allocations,
            .total_bytes_allocated = self.total_bytes_allocated,
            .total_resets = self.total_resets,
            .bytes_in_use = self.bytes_in_use,
            .total_recycled = self.total_recycled,
            .arena_state = self.arena.state,
        };
    }

    /// Allocation statistics
    pub const Stats = struct {
        total_allocations: usize,
        total_bytes_allocated: usize,
        total_resets: usize,
        /// Bytes held by live states right now. The figure to read for retention;
        /// `total_bytes_allocated` only ever rises.
        bytes_in_use: usize,
        /// How many allocations were satisfied from a free list.
        total_recycled: usize,
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
