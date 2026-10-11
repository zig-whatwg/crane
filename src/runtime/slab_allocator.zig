//! Slab allocator for fixed-size Instance handles
//!
//! This allocator manages Instance structs (24 bytes each) using a slab-based
//! approach for O(1) allocation and deallocation with zero fragmentation.
//!
//! Design:
//! - Each slab is one `slab_bytes` block, aligned to its own size: a header
//!   (the allocator that owns it, the next slab) and 255 slots
//! - Slots are either in-use (holding Instance) or free (linked list node)
//! - Free list is maintained across all slabs for O(1) allocation
//! - Slabs are freed only with their allocator (`deinit`)
//!
//! One per Browser (runtime.BrowserScope.slab, docs/instances.md): a
//! Browser's platform objects come from its own slab, and its end frees
//! exactly them. Because a slab is aligned to its size, the slab - and so the
//! allocator, and its Browser - that issued an Instance is found from the
//! Instance's address alone (`ownerOf`), never from its context, which a
//! teardown may already have freed.
//!
//! Each slot also carries the Instance's lifecycle flags
//! (runtime.instance_lifecycle) beside its generation: they live and die with
//! the slot, so they need no registry and belong to the slot's Browser.
//!
//! Thread safety: every thread that makes platform objects allocates here - a
//! Browser's thread and each of its workers' (docs/instances.md) - so `alloc`,
//! `free` and `stats` take `mutex`. `generationOf` and the lifecycle flags
//! read one slot without it: a holder only ever asks about an object of its
//! own thread, which no other thread frees.

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const VTable = @import("instance.zig").VTable;

/// Slab allocator for fixed-size Instance structs
pub const SlabAllocator = struct {
    /// Slot data - raw bytes that can hold either Instance or free list pointer,
    /// followed by the slot's stamp. `extern` pins `data` at offset 0, which
    /// is what `asInstance` and `free` rely on.
    const Slot = extern struct {
        data: [24]u8,
        /// The slot's generation (the low 56 bits) and its occupant's
        /// lifecycle flags (the high 8, runtime.instance_lifecycle).
        ///
        /// The generation is the identity of whatever occupies this slot.
        /// Stamped from a monotonic counter on every alloc and set to
        /// `dead_generation` on free, so a holder that recorded the value when
        /// it took the Instance can tell "still mine" from "freed" and from
        /// "reissued to someone else". The address alone cannot: the slab
        /// recycles it, and a same-type newcomer whose state block was
        /// recycled too is indistinguishable by vtable and state.
        ///
        /// The flags survive the free (a teardown still asks whether a freed
        /// node's cleanup ran) and are cleared when the slot is issued again.
        stamp: u64,

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

    const generation_bits = 56;
    const generation_mask: u64 = (@as(u64, 1) << generation_bits) - 1;

    /// Bytes of one slab, and its alignment: the slab of a slot is the slot's
    /// address with these low bits cleared.
    pub const slab_bytes = 8192;

    /// Slab containing multiple slots, behind its header.
    const Slab = extern struct {
        /// The allocator that made this slab.
        owner: *SlabAllocator,
        /// Link to next slab
        next: ?*Slab,
        /// Array of slots
        slots: [SLOTS_PER_SLAB]Slot,

        /// Initialize a new slab with all slots in free list
        fn init(self: *Slab, owner: *SlabAllocator) void {
            self.owner = owner;
            // A slot nobody has issued yet reads dead
            for (&self.slots) |*slot| slot.stamp = dead_generation;
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

    /// Number of slots per slab: as many as fit behind the header in
    /// `slab_bytes` (255 slots * 32 bytes + 16).
    pub const SLOTS_PER_SLAB = (slab_bytes - 16) / @sizeOf(Slot);

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
    /// Next generation to stamp; never reused within this allocator
    next_generation: u64,

    /// Protects `slabs`, `free_list`, `next_generation` and the statistics:
    /// every thread that makes or frees a platform object takes it, for the
    /// few instructions of a pop, a push or a slab's linking - never across a
    /// call out of this file.
    mutex: std.Io.Mutex = .init,

    /// What `generationOf` reads for a slot that is free (or never issued)
    pub const dead_generation: u64 = 0;

    /// An allocator with no slab yet. It must not move once it has issued an
    /// Instance: every slab it makes records its address (`ownerOf`).
    pub fn init(backing_allocator: std.mem.Allocator) SlabAllocator {
        return .{
            .slabs = null,
            .free_list = null,
            .backing_allocator = backing_allocator,
            .total_slabs = 0,
            .total_allocated = 0,
            .total_freed = 0,
            .next_generation = dead_generation + 1,
        };
    }

    /// Free every slab - every Instance this allocator issued.
    pub fn deinit(self: *SlabAllocator) void {
        var current = self.slabs;
        while (current) |slab| {
            const next = slab.next;
            self.backing_allocator.free(slabBytes(slab));
            current = next;
        }
        self.slabs = null;
        self.free_list = null;
    }

    fn slabBytes(slab: *Slab) []align(slab_bytes) u8 {
        const bytes: [*]align(slab_bytes) u8 = @ptrCast(@alignCast(slab));
        return bytes[0..@sizeOf(Slab)];
    }

    /// The allocator that issued `inst`. Valid for every Instance an
    /// allocator issued - every one `Instance.init` creates - until that
    /// allocator's `deinit`, whether or not the Instance has been freed.
    pub fn ownerOf(inst: *const Instance) *SlabAllocator {
        const slab: *const Slab = @ptrFromInt(@intFromPtr(inst) & ~@as(usize, slab_bytes - 1));
        return slab.owner;
    }

    /// Allocate an Instance with the given vtable
    pub fn alloc(self: *SlabAllocator, vtable: *const VTable) !*Instance {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        // Try to get a slot from the free list
        if (self.free_list) |slot| {
            // Remove from free list
            self.free_list = slot.getNextFree();

            return self.issue(slot, vtable);
        }

        // No free slots - allocate a new slab, aligned to its size
        const bytes = try self.backing_allocator.alignedAlloc(u8, .fromByteUnits(slab_bytes), @sizeOf(Slab));
        const slab: *Slab = @ptrCast(bytes.ptr);

        // Initialize the slab
        slab.init(self);

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
    /// occupant of that address ever carried, with no lifecycle flags.
    fn issue(self: *SlabAllocator, slot: *Slot, vtable: *const VTable) *Instance {
        slot.stamp = self.next_generation & generation_mask;
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
        return slot.stamp & generation_mask;
    }

    /// The lifecycle flags of the slot holding `inst` (runtime.instance_lifecycle).
    pub fn lifecycleBitsOf(inst: *const Instance) u8 {
        const slot: *const Slot = @ptrCast(inst);
        return @truncate(slot.stamp >> generation_bits);
    }

    /// Set the lifecycle flags of the slot holding `inst`.
    pub fn setLifecycleBits(inst: *const Instance, bits: u8) void {
        const slot: *Slot = @ptrCast(@constCast(inst));
        slot.stamp = (slot.stamp & generation_mask) | (@as(u64, bits) << generation_bits);
    }

    /// Free an Instance (return slot to free list). Its lifecycle flags stay
    /// until the slot is issued again.
    pub fn free(self: *SlabAllocator, inst: *Instance) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const slot: *Slot = @ptrCast(inst);
        slot.stamp = (slot.stamp & ~generation_mask) | dead_generation;

        // Add to free list
        slot.setNextFree(self.free_list);
        self.free_list = slot;

        self.total_freed += 1;
    }

    /// Get allocation statistics
    pub fn stats(self: *SlabAllocator) Stats {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
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
    // `free` and `generationOf` all cast between the two - and the stamp sits
    // after it. `extern` layout is what pins `data` at offset 0.
    const Slot = SlabAllocator.Slot;
    if (@offsetOf(Slot, "data") != 0) @compileError("Slot.data must be at offset 0");
    if (@sizeOf(Instance) != 24) {
        @compileError(std.fmt.comptimePrint("Instance is {d} bytes; Slot.data holds 24", .{@sizeOf(Instance)}));
    }
    if (@alignOf(Slot) < @alignOf(Instance)) @compileError("Slot must be at least Instance-aligned");
    if (@sizeOf(Slot) != 32) {
        @compileError(std.fmt.comptimePrint("Slot size ({d}) must be 32: 24 bytes of Instance plus the stamp", .{@sizeOf(Slot)}));
    }

    // The slab - header and slots - fits the block it is aligned to, so
    // `ownerOf` finds its header from any slot.
    const Slab = SlabAllocator.Slab;
    if (@sizeOf(Slab) > SlabAllocator.slab_bytes) {
        @compileError(std.fmt.comptimePrint("Slab ({d} bytes) exceeds its {d}-byte block", .{ @sizeOf(Slab), SlabAllocator.slab_bytes }));
    }
    if (@offsetOf(Slab, "owner") != 0) @compileError("the slab header must open the block");
}

// Unit tests
const testing = std.testing;

const delegates = .{}; // Empty delegates struct
const test_vtable = VTable{
    .name = "SlabTest",
    .deinit = null,
    .methods_ptr = &delegates,
};

test "SlabAllocator init and deinit" {
    var slab_allocator = SlabAllocator.init(testing.allocator);
    defer slab_allocator.deinit();

    try testing.expect(slab_allocator.slabs == null);
    try testing.expectEqual(@as(usize, 0), slab_allocator.total_slabs);
}

test "SlabAllocator.alloc creates first slab" {
    var slab_allocator = SlabAllocator.init(testing.allocator);
    defer slab_allocator.deinit();

    // Allocate first instance
    const inst = try slab_allocator.alloc(&test_vtable);
    try testing.expect(inst.vtable == &test_vtable);
    try testing.expectEqual(@as(usize, 1), slab_allocator.total_slabs);
    try testing.expectEqual(@as(usize, 1), slab_allocator.total_allocated);

    const s = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 1), s.currently_allocated);
}

test "SlabAllocator.alloc reuses freed slots" {
    var slab_allocator = SlabAllocator.init(testing.allocator);
    defer slab_allocator.deinit();

    // Allocate and free
    const inst1 = try slab_allocator.alloc(&test_vtable);
    slab_allocator.free(inst1);

    try testing.expectEqual(@as(usize, 1), slab_allocator.total_allocated);
    try testing.expectEqual(@as(usize, 1), slab_allocator.total_freed);

    // Allocate again - should reuse the slot
    const inst2 = try slab_allocator.alloc(&test_vtable);
    try testing.expectEqual(@as(usize, 2), slab_allocator.total_allocated);
    try testing.expectEqual(@as(usize, 1), slab_allocator.total_slabs); // Still only 1 slab

    // Verify they're the same address (slot was reused)
    try testing.expectEqual(@intFromPtr(inst1), @intFromPtr(inst2));
}

test "SlabAllocator.alloc expands to multiple slabs" {
    var slab_allocator = SlabAllocator.init(testing.allocator);
    defer slab_allocator.deinit();

    // Allocate more than one slab worth
    var instances: [SlabAllocator.SLOTS_PER_SLAB + 1]*Instance = undefined;
    for (&instances) |*inst| {
        inst.* = try slab_allocator.alloc(&test_vtable);
    }

    // Should have 2 slabs now
    try testing.expectEqual(@as(usize, 2), slab_allocator.total_slabs);
    try testing.expectEqual(instances.len, slab_allocator.total_allocated);

    const s = slab_allocator.stats();
    try testing.expectEqual(instances.len, s.currently_allocated);
    try testing.expectEqual(2 * SlabAllocator.SLOTS_PER_SLAB, s.total_capacity);

    // Every instance names its allocator, whichever slab it is in
    for (instances) |inst| try testing.expectEqual(&slab_allocator, SlabAllocator.ownerOf(inst));

    // Free all
    for (instances) |inst| {
        slab_allocator.free(inst);
    }

    try testing.expectEqual(instances.len, slab_allocator.total_freed);
    const s2 = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 0), s2.currently_allocated);
}

test "SlabAllocator.free and alloc maintains free list" {
    var slab_allocator = SlabAllocator.init(testing.allocator);
    defer slab_allocator.deinit();

    // Allocate 3 instances
    const inst1 = try slab_allocator.alloc(&test_vtable);
    const inst2 = try slab_allocator.alloc(&test_vtable);
    const inst3 = try slab_allocator.alloc(&test_vtable);

    // Free middle one
    slab_allocator.free(inst2);

    // Allocate new one - should get inst2's slot
    const inst4 = try slab_allocator.alloc(&test_vtable);
    try testing.expectEqual(@intFromPtr(inst2), @intFromPtr(inst4));

    // Free all
    slab_allocator.free(inst1);
    slab_allocator.free(inst3);
    slab_allocator.free(inst4);

    const s = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 0), s.currently_allocated);
}

test "SlabAllocator.stats accuracy" {
    var slab_allocator = SlabAllocator.init(testing.allocator);
    defer slab_allocator.deinit();

    // Initial stats
    var s = slab_allocator.stats();
    try testing.expectEqual(@as(usize, 0), s.total_slabs);
    try testing.expectEqual(@as(usize, 0), s.currently_allocated);

    // Allocate 10
    var instances: [10]*Instance = undefined;
    for (&instances) |*inst| {
        inst.* = try slab_allocator.alloc(&test_vtable);
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

test "SlabAllocator: two allocators' instances name their own allocator" {
    var a = SlabAllocator.init(testing.allocator);
    defer a.deinit();
    var b = SlabAllocator.init(testing.allocator);
    defer b.deinit();

    const from_a = try a.alloc(&test_vtable);
    const from_b = try b.alloc(&test_vtable);
    try testing.expectEqual(&a, SlabAllocator.ownerOf(from_a));
    try testing.expectEqual(&b, SlabAllocator.ownerOf(from_b));
    // Freed, the slot still names its allocator.
    a.free(from_a);
    try testing.expectEqual(&a, SlabAllocator.ownerOf(from_a));
}

test "SlabAllocator: lifecycle bits live in the slot, survive its free and clear at its reissue" {
    var slab_allocator = SlabAllocator.init(testing.allocator);
    defer slab_allocator.deinit();

    const inst = try slab_allocator.alloc(&test_vtable);
    const generation = SlabAllocator.generationOf(inst);
    try testing.expect(generation != SlabAllocator.dead_generation);
    try testing.expectEqual(@as(u8, 0), SlabAllocator.lifecycleBitsOf(inst));

    SlabAllocator.setLifecycleBits(inst, 0b11);
    // The flags never read as part of the generation.
    try testing.expectEqual(generation, SlabAllocator.generationOf(inst));
    try testing.expectEqual(@as(u8, 0b11), SlabAllocator.lifecycleBitsOf(inst));

    slab_allocator.free(inst);
    try testing.expectEqual(SlabAllocator.dead_generation, SlabAllocator.generationOf(inst));
    try testing.expectEqual(@as(u8, 0b11), SlabAllocator.lifecycleBitsOf(inst));

    const again = try slab_allocator.alloc(&test_vtable);
    try testing.expectEqual(inst, again);
    try testing.expectEqual(@as(u8, 0), SlabAllocator.lifecycleBitsOf(again));
    try testing.expect(SlabAllocator.generationOf(again) > generation);
}
