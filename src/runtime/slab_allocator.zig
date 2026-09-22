//! Slab allocator for fixed-size Instance handles
//!
//! This allocator manages Instance structs (24 bytes each) using a slab-based
//! approach for O(1) allocation and deallocation with zero fragmentation.
//!
//! Design:
//! - Each slab contains 256 slots (4KB per slab)
//! - Slots are either in-use (holding Instance) or free (linked list node)
//! - Free list is maintained across all slabs for O(1) allocation
//! - Slabs are never freed (retained for lifetime of program)
//!
//! Thread safety: Single-threaded (no locks)

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const VTable = @import("instance.zig").VTable;

/// Slab allocator for fixed-size Instance structs
pub const SlabAllocator = struct {
    /// Slot data - raw bytes that can hold either Instance or free list pointer,
    /// followed by the slot's generation. `extern` pins `data` at offset 0, which
    /// is what `asInstance` and `free` rely on.
    const Slot = extern struct {
        data: [24]u8,
        /// Identity of whatever occupies this slot. Stamped from a monotonic
        /// counter on every alloc and set to `dead_generation` on free, so a
        /// holder that recorded the value when it took the Instance can tell
        /// "still mine" from "freed" and from "reissued to someone else". The
        /// address alone cannot: the slab recycles it, and a same-type
        /// newcomer whose state block was recycled too is indistinguishable
        /// by vtable and state.
        generation: u64,

        /// Get this slot as an Instance pointer
        fn asInstance(self: *Slot) *Instance {
            return @as(*Instance, @ptrCast(self));
        }

        /// Get the next free slot pointer
        fn getNextFree(self: *const Slot) ?*Slot {
            const ptr_addr: *const ?*Slot = @ptrCast(@alignCast(&self.data));
            return ptr_addr.*;
        }

        /// Set the next free slot pointer
        fn setNextFree(self: *Slot, next: ?*Slot) void {
            const ptr_addr: *?*Slot = @ptrCast(@alignCast(&self.data));
            ptr_addr.* = next;
        }
    };

    /// Slab containing multiple slots
    const Slab = struct {
        /// Array of slots
        slots: [SLOTS_PER_SLAB]Slot,
        /// Link to next slab
        next: ?*Slab,

        /// Initialize a new slab with all slots in free list
        fn init(self: *Slab) void {
            // A slot nobody has issued yet reads dead
            for (&self.slots) |*slot| slot.generation = dead_generation;
            // Link all slots together in free list
            var i: usize = 0;
            while (i < SLOTS_PER_SLAB - 1) : (i += 1) {
                self.slots[i].setNextFree(&self.slots[i + 1]);
            }
            // Last slot points to null
            self.slots[SLOTS_PER_SLAB - 1].setNextFree(null);
            self.next = null;
        }
    };

    /// Number of slots per slab (256 slots * 24 bytes = 4KB)
    const SLOTS_PER_SLAB = 256;

    /// Head of slab list
    slabs: ?*Slab,

    /// Head of free list (spans all slabs)
    free_list: ?*Slot,

    /// Backing allocator for slab allocation
    backing_allocator: std.mem.Allocator,

    /// Statistics
    total_slabs: usize,
    total_allocated: usize,
    total_freed: usize,
    /// Next generation to stamp; never reused within a process
    next_generation: u64,

    /// What `generationOf` reads for a slot that is free (or never issued)
    pub const dead_generation: u64 = 0;

    /// Global instance
    var global: ?SlabAllocator = null;

    /// Initialize the global slab allocator
    pub fn init(backing_allocator: std.mem.Allocator) void {
        global = SlabAllocator{
            .slabs = null,
            .free_list = null,
            .backing_allocator = backing_allocator,
            .total_slabs = 0,
            .total_allocated = 0,
            .total_freed = 0,
            .next_generation = dead_generation + 1,
        };
    }

    /// Error type for slab allocator operations
    pub const SlabError = error{
        /// The allocator was not initialized before use
        NotInitialized,
    };

    /// Get the global slab allocator instance
    /// Panics if the allocator was not initialized - this is a programming error.
    /// Use tryGet() for error-returning variant.
    pub fn get() *SlabAllocator {
        return &(global orelse @panic("SlabAllocator not initialized - call init() first"));
    }

    /// Get the global slab allocator instance, returning error if not initialized
    /// Use this in contexts where you need to handle missing initialization gracefully.
    pub fn tryGet() SlabError!*SlabAllocator {
        if (global) |*g| {
            return g;
        }
        return SlabError.NotInitialized;
    }

    /// Deinitialize the global allocator (free all slabs)
    pub fn deinit() void {
        if (global) |*g| {
            var current = g.slabs;
            while (current) |slab| {
                const next = slab.next;
                g.backing_allocator.destroy(slab);
                current = next;
            }
            global = null;
        }
    }

    /// Allocate an Instance with the given vtable
    pub fn alloc(self: *SlabAllocator, vtable: *const VTable) !*Instance {
        // Try to get a slot from the free list
        if (self.free_list) |slot| {
            // Remove from free list
            self.free_list = slot.getNextFree();

            return self.issue(slot, vtable);
        }

        // No free slots - allocate a new slab
        const slab = try self.backing_allocator.create(Slab);
        errdefer self.backing_allocator.destroy(slab);

        // Initialize the slab
        slab.init();

        // Add to slab list
        slab.next = self.slabs;
        self.slabs = slab;
        self.total_slabs += 1;

        // Take the first slot
        const slot = &slab.slots[0];

        // Add remaining slots to free list
        self.free_list = slot.getNextFree();

        return self.issue(slot, vtable);
    }

    /// Hand `slot` out as a fresh Instance under a generation no earlier
    /// occupant of that address ever carried.
    fn issue(self: *SlabAllocator, slot: *Slot, vtable: *const VTable) *Instance {
        slot.generation = self.next_generation;
        self.next_generation += 1;

        const inst = slot.asInstance();
        inst.* = Instance{
            .vtable = vtable,
            .state = undefined, // Caller will set this
            .ctx = undefined, // Caller will set this
        };

        self.total_allocated += 1;
        return inst;
    }

    /// The generation stamped on the slot holding `inst`, or `dead_generation`
    /// once it has been freed. Valid only for Instances the slab issued, which
    /// is every one `Instance.init` creates. A holder compares this against the
    /// value it read at acquisition to learn whether the address still means
    /// its instance.
    pub fn generationOf(inst: *const Instance) u64 {
        const slot: *const Slot = @ptrCast(inst);
        return slot.generation;
    }

    /// Free an Instance (return slot to free list)
    pub fn free(self: *SlabAllocator, inst: *Instance) void {
        const slot: *Slot = @ptrCast(inst);
        slot.generation = dead_generation;

        // Add to free list
        slot.setNextFree(self.free_list);
        self.free_list = slot;

        self.total_freed += 1;
    }

    /// Get allocation statistics
    pub fn stats(self: *const SlabAllocator) Stats {
        return Stats{
            .total_slabs = self.total_slabs,
            .total_allocated = self.total_allocated,
            .total_freed = self.total_freed,
            .currently_allocated = self.total_allocated - self.total_freed,
            .total_capacity = self.total_slabs * SLOTS_PER_SLAB,
        };
    }

    /// Allocation statistics
    pub const Stats = struct {
        total_slabs: usize,
        total_allocated: usize,
        total_freed: usize,
        currently_allocated: usize,
        total_capacity: usize,
    };
};

// Compile-time verification
comptime {
    // The Instance occupies the slot's first 24 bytes exactly - `asInstance`,
    // `free` and `generationOf` all cast between the two - and the generation
    // sits after it. `extern` layout is what pins `data` at offset 0.
    const Slot = SlabAllocator.Slot;
    if (@offsetOf(Slot, "data") != 0) @compileError("Slot.data must be at offset 0");
    if (@sizeOf(Instance) != 24) {
        @compileError(std.fmt.comptimePrint("Instance is {d} bytes; Slot.data holds 24", .{@sizeOf(Instance)}));
    }
    if (@alignOf(Slot) < @alignOf(Instance)) @compileError("Slot must be at least Instance-aligned");
    if (@sizeOf(Slot) != 32) {
        @compileError(std.fmt.comptimePrint("Slot size ({d}) must be 32: 24 bytes of Instance plus the generation", .{@sizeOf(Slot)}));
    }

    // Verify Slab size is reasonable (8KB for 32-byte slots)
    const slab_size = @sizeOf(SlabAllocator.Slab);
    if (slab_size > 8192 + 64) { // Allow some overhead
        @compileError(std.fmt.comptimePrint("Slab size ({d}) is unexpectedly large", .{slab_size}));
    }
}

// Unit tests
const testing = std.testing;

test "SlabAllocator init and deinit" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    const slab_allocator = SlabAllocator.get();
    try testing.expect(slab_allocator.slabs == null);
    try testing.expectEqual(@as(usize, 0), slab_allocator.total_slabs);
}

test "SlabAllocator.alloc creates first slab" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    const slab_allocator = SlabAllocator.get();

    // Create dummy vtable
    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Allocate first instance
    const inst = try slab_allocator.alloc(&vtable);
    try testing.expect(inst.vtable == &vtable);
    try testing.expectEqual(@as(usize, 1), slab_allocator.total_slabs);
    try testing.expectEqual(@as(usize, 1), slab_allocator.total_allocated);

    const s = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 1), s.currently_allocated);
}

test "SlabAllocator.alloc reuses freed slots" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    const slab_allocator = SlabAllocator.get();

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Allocate and free
    const inst1 = try slab_allocator.alloc(&vtable);
    slab_allocator.free(inst1);

    try testing.expectEqual(@as(usize, 1), slab_allocator.total_allocated);
    try testing.expectEqual(@as(usize, 1), slab_allocator.total_freed);

    // Allocate again - should reuse the slot
    const inst2 = try slab_allocator.alloc(&vtable);
    try testing.expectEqual(@as(usize, 2), slab_allocator.total_allocated);
    try testing.expectEqual(@as(usize, 1), slab_allocator.total_slabs); // Still only 1 slab

    // Verify they're the same address (slot was reused)
    try testing.expectEqual(@intFromPtr(inst1), @intFromPtr(inst2));
}

test "SlabAllocator.alloc expands to multiple slabs" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    const slab_allocator = SlabAllocator.get();

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Allocate more than one slab worth (256 + 1)
    var instances: [257]*Instance = undefined;
    for (&instances) |*inst| {
        inst.* = try slab_allocator.alloc(&vtable);
    }

    // Should have 2 slabs now
    try testing.expectEqual(@as(usize, 2), slab_allocator.total_slabs);
    try testing.expectEqual(@as(usize, 257), slab_allocator.total_allocated);

    const s = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 257), s.currently_allocated);
    try testing.expectEqual(@as(usize, 512), s.total_capacity);

    // Free all
    for (instances) |inst| {
        slab_allocator.free(inst);
    }

    try testing.expectEqual(@as(usize, 257), slab_allocator.total_freed);
    const s2 = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 0), s2.currently_allocated);
}

test "SlabAllocator.free and alloc maintains free list" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    const slab_allocator = SlabAllocator.get();

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Allocate 3 instances
    const inst1 = try slab_allocator.alloc(&vtable);
    const inst2 = try slab_allocator.alloc(&vtable);
    const inst3 = try slab_allocator.alloc(&vtable);

    // Free middle one
    slab_allocator.free(inst2);

    // Allocate new one - should get inst2's slot
    const inst4 = try slab_allocator.alloc(&vtable);
    try testing.expectEqual(@intFromPtr(inst2), @intFromPtr(inst4));

    // Free all
    slab_allocator.free(inst1);
    slab_allocator.free(inst3);
    slab_allocator.free(inst4);

    const s = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 0), s.currently_allocated);
}

test "SlabAllocator.stats accuracy" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    const slab_allocator = SlabAllocator.get();

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Initial stats
    var s = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 0), s.total_slabs);
    try testing.expectEqual(@as(usize, 0), s.currently_allocated);

    // Allocate 10
    var instances: [10]*Instance = undefined;
    for (&instances) |*inst| {
        inst.* = try slab_allocator.alloc(&vtable);
    }

    s = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 1), s.total_slabs);
    try testing.expectEqual(@as(usize, 10), s.total_allocated);
    try testing.expectEqual(@as(usize, 0), s.total_freed);
    try testing.expectEqual(@as(usize, 10), s.currently_allocated);

    // Free 5
    for (instances[0..5]) |inst| {
        slab_allocator.free(inst);
    }

    s = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 10), s.total_allocated);
    try testing.expectEqual(@as(usize, 5), s.total_freed);
    try testing.expectEqual(@as(usize, 5), s.currently_allocated);
}
