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
//! One per Browser (runtime.BrowserScope.arena, docs/instances.md): a
//! Browser's platform objects take their state from its own arena, and its
//! end frees exactly them.
//!
//! Thread safety: every thread that makes platform objects takes its state
//! from here - a Browser's thread and each of its workers' (docs/instances.md)
//! - so every method takes `mutex`.

const std = @import("std");

/// How the state arena rounds a request to a block it can recycle.
///
/// Lane perf2 batch 5 (tmp/plans/perf2b5-design.md 3.1): a node is ONE State
/// block now - the generated State with every level's InternalState and the
/// NodeBase by value (runtime.FlattenedState, Z7) - so the block's class is a
/// node's whole storage. Power-of-two classes put a div's ~1,250 bytes in a
/// 2,048-byte block and a Document's 2,168-byte state in 4,096 (lane nav2
/// batch 7). Classes trade slack against reuse: a freed block serves only
/// requests of its own class, and finer classes are narrower bands - jemalloc
/// and PartitionAlloc keep four to eight per doubling, macOS malloc a 16-byte
/// quantum to 1 KiB and 512 bytes above. The choice is MEASURED (the perf
/// window's memory rows, both schemes) and stays one constant away.
pub const ClassScheme = enum {
    /// Every multiple of 16 bytes to 4 KiB, then 8 and 16 KiB: a block holds
    /// its request with less than 16 bytes to spare.
    quantum16,
    /// 16-byte steps to 512 bytes, then eight classes per doubling to 16 KiB:
    /// at most 12.5% slack, wider bands to recycle in.
    eighths,
    /// Powers of two from 16 bytes to 16 KiB: the classes before batch 5.
    powers_of_two,
};

/// The scheme the state arena uses.
pub const class_scheme: ClassScheme = .quantum16;

/// The size classes of `scheme`, for requests of 8 bytes to `max_size`.
pub fn SizeClasses(comptime scheme: ClassScheme) type {
    return struct {
        /// The largest request a class holds; past it nothing is recycled.
        pub const max_size: usize = 16 * 1024;

        /// How many classes there are (one free list each).
        pub const count: usize = switch (scheme) {
            .quantum16 => 4096 / 16 + 2,
            .eighths => 512 / 16 + 5 * 8,
            .powers_of_two => 14 - 4 + 1,
        };

        /// The class of a request of `size` bytes, 8 <= size <= max_size.
        pub fn of(size: usize) usize {
            std.debug.assert(size >= 8 and size <= max_size);
            switch (scheme) {
                .quantum16 => {
                    if (size <= 4096) return (size + 15) / 16 - 1;
                    return if (size <= 8192) 256 else 257;
                },
                .eighths => {
                    if (size <= 512) return (size + 15) / 16 - 1;
                    // The doubling (base, 2 * base] the size falls in, and its
                    // eighth: classes base + k * base / 8, k = 1..8.
                    const d: usize = std.math.log2_int(usize, size - 1);
                    const base = @as(usize, 1) << @intCast(d);
                    const step = base / 8;
                    const k = (size - base + step - 1) / step;
                    return 32 + (d - 9) * 8 + (k - 1);
                },
                .powers_of_two => {
                    const shift = std.math.log2_int_ceil(usize, @max(size, 16));
                    return shift - 4;
                },
            }
        }

        /// The bytes a block of `class` holds.
        pub fn bytes(class: usize) usize {
            std.debug.assert(class < count);
            switch (scheme) {
                .quantum16 => {
                    if (class < 256) return (class + 1) * 16;
                    return if (class == 256) 8192 else 16384;
                },
                .eighths => {
                    if (class < 32) return (class + 1) * 16;
                    const i = class - 32;
                    const base = @as(usize, 1) << @intCast(9 + i / 8);
                    return base + (i % 8 + 1) * (base / 8);
                },
                .powers_of_two => return @as(usize, 1) << @intCast(class + 4),
            }
        }
    };
}

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
    /// Reuse rather than `reset()` deliberately. The arena is the Browser's and
    /// holds the Window, the Document and every node still in the tree, so a
    /// blanket reset would free live state along with dead. Reuse touches only
    /// blocks their owners have already given up.
    free_lists: [Classes.count]?*FreeBlock = @splat(null),
    /// Blocks recycled rather than taken from the arena. Diagnostic: if this stays
    /// at zero while a discard loop runs, states are not being returned at all.
    total_recycled: usize = 0,

    /// Whether `destroyRaw` overwrites a freed block with `poison_byte`, so a
    /// read of a freed state faults instead of finding its old bytes - the
    /// poison-on-free the WPT correctness runner's allocator gives every
    /// block it frees (the user, 2026-11-05: on by default there, never in
    /// Crane's builds or the release runner). Set once, by the Browser,
    /// before any state is made (BrowserConfig.poison_freed_state); off by
    /// default, so a product build never pays it. Since lane perf2 batch 5 a
    /// node's NodeBase and InternalStates are its State block's (Z7): their
    /// release frees nothing the runner's allocator would have poisoned.
    poison_freed: bool = false,

    /// Protects `arena`, `free_lists` and the statistics: every thread that
    /// makes or frees a platform object's state takes it, for one bump or one
    /// free-list push or pop - never across a call out of this file.
    mutex: std.Io.Mutex = .init,

    /// A freed block, with the next pointer written into the block itself.
    ///
    /// Costs no side allocation, which matters because this runs on the free path
    /// of every DOM node. It does require every recycled block to be at least
    /// pointer-sized and pointer-aligned; `sizeClassOf` enforces that by refusing
    /// anything smaller.
    const FreeBlock = struct {
        next: ?*FreeBlock,
    };

    /// The byte a freed block is overwritten with when `poison_freed` is set:
    /// the tests' and the WPT runner's poison (tests/test_runner/poisoning.zig).
    pub const poison_byte: u8 = 0xdd;

    /// The size classes (`class_scheme`, `SizeClasses`).
    const Classes = SizeClasses(class_scheme);

    /// The class a request of `size`/`alignment` belongs to, or null if it must not
    /// be recycled.
    ///
    /// Null for anything under 8 bytes (no room for the next pointer), anything
    /// over 16 KiB (rare, and pooling them would hold a lot of memory hostage), and
    /// anything needing more than a pointer's alignment (a class block is aligned
    /// to a pointer).
    fn sizeClassOf(size: usize, alignment: usize) ?usize {
        if (size < @sizeOf(FreeBlock) or alignment > @alignOf(FreeBlock)) return null;
        if (size > Classes.max_size) return null;
        return Classes.of(size);
    }

    /// Bytes a block of the given class holds.
    fn classSize(class: usize) usize {
        return Classes.bytes(class);
    }

    /// The bytes a state of `size`/`alignment` holds once made: its class's
    /// block, or the request itself when it is not recycled (`createRaw`).
    /// What a Browser's DOM memory counts for a node's state
    /// (dom.instance_bridge.storageBytes).
    pub fn heldBytes(size: usize, alignment: usize) usize {
        const class = sizeClassOf(size, alignment) orelse return size;
        return classSize(class);
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

    /// An empty arena over `backing_allocator`.
    pub fn init(backing_allocator: std.mem.Allocator) ArenaAllocator {
        return .{
            .arena = std.heap.ArenaAllocator.init(backing_allocator),
            .total_allocations = 0,
            .total_bytes_allocated = 0,
            .total_resets = 0,
        };
    }

    /// Free every block - the state of every platform object made from it.
    pub fn deinit(self: *ArenaAllocator) void {
        self.arena.deinit();
        self.free_lists = @splat(null);
    }

    /// Create (allocate) a single instance of type T
    ///
    /// This is the primary allocation method used by generated code:
    ///   const state = try runtime.arenaOf(instance).create(FullState);
    pub fn create(self: *ArenaAllocator, comptime T: type) !*T {
        return @ptrCast(@alignCast(try self.createRaw(@sizeOf(T), @alignOf(T))));
    }

    /// `create` for a size known only at runtime.
    ///
    /// `Instance.deinit` has a `*Instance` and a vtable, not a type, so the free
    /// path is necessarily untyped; the allocate path has to match it or the two
    /// would disagree about which class a block belongs to.
    ///
    /// The request's bytes are ZEROED, here and only here: Zig does not apply
    /// struct defaults through an allocator, and a recycled block carries its
    /// previous occupant's bytes - an optional pointer field coming back non-null
    /// would be dereferenced. Instance.init, OwnState.createIn and
    /// InstanceRegistry.createIn rely on it and do not zero again (lane perf2,
    /// batch 3: a div's state block was zeroed twice, the whole 2,048-byte class
    /// and then the State, and a fresh block was first filled with 0xAA by std's
    /// `alignedAlloc` in ReleaseSafe - 2.0% of dom.create-element, MEASURED).
    ///
    /// Only the request, never the rest of its class: this occupant never reads
    /// past its own bytes, and a later, larger occupant of the block zeroes its
    /// own request when it takes it.
    pub fn createRaw(self: *ArenaAllocator, size: usize, alignment: usize) ![*]u8 {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.total_allocations += 1;
        self.total_bytes_allocated += size;
        self.bytes_in_use += size;

        // A zero-sized state is not exotic: any interface that keeps no internal
        // state has one, and `Geolocation` and `Clipboard` both declare
        // `InternalState = struct {}`. std's ArenaAllocator opens `alloc` with
        // `assert(n > 0)`, so forwarding the request aborted the process the
        // first time script touched such an interface:
        //
        //     panic: reached unreachable code
        //       heap.ArenaAllocator.alloc
        //       arena_allocator.createRaw
        //       instance.Instance.init
        //
        // Zig's allocator contract already says what to hand back - a non-null,
        // correctly-aligned pointer that must never be dereferenced. The
        // alignment itself is such an address, and it deliberately never
        // reaches a size class, so `destroyRaw` cannot push it onto a free list
        // where a later real allocation would take it.
        if (size == 0) {
            return @ptrFromInt(@max(alignment, 1));
        }

        if (sizeClassOf(size, alignment)) |class| {
            if (self.popFree(class)) |recycled| {
                @memset(recycled[0..size], 0);
                return recycled;
            }
            // Allocate the whole class, not the request: the block goes back on
            // this class's list, and a later request in the same class may be
            // larger than this one. `rawAlloc`, not `alignedAlloc`: the latter
            // writes `undefined` over the whole block first (0xAA in ReleaseSafe),
            // a pass the zeroing below would only overwrite.
            const bytes = self.arena.allocator().rawAlloc(
                classSize(class),
                .of(FreeBlock),
                @returnAddress(),
            ) orelse return error.OutOfMemory;
            @memset(bytes[0..size], 0);
            return bytes;
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
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.bytes_in_use -|= size;
        // Before the free list writes its link into the block's first word.
        if (self.poison_freed) @memset(ptr[0..size], poison_byte);
        if (sizeClassOf(size, alignment)) |class| {
            self.pushFree(class, ptr);
        }
    }

    /// Allocate a slice of items
    pub fn alloc(self: *ArenaAllocator, comptime T: type, n: usize) ![]T {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const slice = try self.arena.allocator().alloc(T, n);
        self.total_allocations += 1;
        self.total_bytes_allocated += @sizeOf(T) * n;
        self.bytes_in_use += @sizeOf(T) * n;
        return slice;
    }

    /// Duplicate a slice
    pub fn dupe(self: *ArenaAllocator, comptime T: type, m: []const T) ![]T {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
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
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
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
    pub fn stats(self: *ArenaAllocator) Stats {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
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
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;
    try testing.expect(arena.total_allocations == 0);
    try testing.expect(arena.total_bytes_allocated == 0);
}

test "ArenaAllocator.create allocates single item" {
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;

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
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;

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
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;

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
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;

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
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;

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
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;

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
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;

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

test "heldBytes is the block createRaw hands out: a freed block of that size comes back to it, one byte more does not" {
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;
    for ([_]usize{ 16, 17, 100, 1100, 1700, 2048, 2049, 9000, 16384 }) |size| {
        const held = ArenaAllocator.heldBytes(size, 8);
        try testing.expect(held >= size);
        const block = try arena.createRaw(size, 8);
        arena.destroyRaw(block, size, 8);
        // The whole block is the class's: a request of `held` bytes takes it back.
        const again = try arena.createRaw(held, 8);
        try testing.expectEqual(block, again);
        arena.destroyRaw(again, held, 8);
        // One byte more is the next class: a new block.
        const bigger = try arena.createRaw(held + 1, 8);
        try testing.expect(bigger != block);
        arena.destroyRaw(bigger, held + 1, 8);
    }
    // Past the largest class nothing is rounded: the request is what is held.
    try testing.expectEqual(@as(usize, 20000), ArenaAllocator.heldBytes(20000, 8));
}
