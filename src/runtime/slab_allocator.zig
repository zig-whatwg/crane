//! The Instance slots of a Browser's platform objects - now an objects-
//! partition bucket of the Browser's heap (lane hard1, allocator-hardening
//! batch A; tmp/plans/allocator-hardening-design.md 7 item 4).
//!
//! A slot is 32 bytes: the 24-byte Instance and its STAMP - the occupant's
//! generation (the low 56 bits) and its lifecycle flags (the high 8,
//! runtime.instance_lifecycle). The slots live in spans of their own bucket,
//! class-stable for the Browser's life: a freed slot is only ever reissued
//! as an Instance of the same Browser (design 3.2).
//!
//! On free the stamp is set dead (its lifecycle flags kept: a teardown still
//! asks whether a freed node's cleanup ran) and the Instance's three words
//! are zeroed (0xdd in a poisoning heap) - where the slab's free list wrote a
//! raw link before (design A7). Reissue checks they still are.
//!
//! One per Browser (runtime.BrowserScope.slab, docs/instances.md). The slot's
//! Browser is found from its address alone (`ownerOf`: browser_heap.heapOf),
//! never from its context, which a teardown may already have freed - valid
//! for every Instance the heap issued, freed or not, until the scope ends.
//! A span of slots is decommitted when empty and idle, never made
//! inaccessible: reading a freed slot's generation is a LEGAL read
//! (`generationOf`), and a decommitted slot reads generation 0, dead.
//!
//! Thread safety: every thread that makes platform objects allocates here -
//! a Browser's thread and each of its workers' (docs/instances.md) - and the
//! heap's objects partition takes its lock. `generationOf` and the
//! lifecycle flags read one slot without it: a holder only ever asks about
//! an object of its own thread, which no other thread frees. But any thread
//! REISSUES a slot once its own thread has freed it, so the stamp is read
//! and written atomically, and a holder reads nothing else of a slot unless
//! the stamp is still the generation it recorded (lane tsanfix1,
//! docs/testing/test-variant-findings-2026-11-02.tsv F2).

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const VTable = @import("instance.zig").VTable;
const heap = @import("heap/root.zig");
const browser_heap = @import("browser_heap.zig");

/// The Browser's Instance slots. Only ever a field of a runtime.BrowserScope.
pub const SlabAllocator = struct {
    /// A slot: the Instance, then its stamp. `extern` pins `data` at offset
    /// 0, which `asInstance` and `free` rely on.
    const Slot = extern struct {
        data: [24]u8,
        /// The slot's generation (the low 56 bits) and its occupant's
        /// lifecycle flags (the high 8, runtime.instance_lifecycle).
        ///
        /// The generation is the identity of whatever occupies this slot:
        /// stamped from a counter on every issue and set to
        /// `dead_generation` on free, so a holder that recorded the value
        /// when it took the Instance can tell "still mine" from "freed" and
        /// from "reissued to someone else".
        ///
        /// The flags survive the free and are cleared when the slot is
        /// issued again. Atomic (`loadStamp`, `storeStamp`).
        stamp: u64,

        fn loadStamp(self: *const Slot) u64 {
            return @atomicLoad(u64, &self.stamp, .monotonic);
        }

        fn storeStamp(self: *Slot, value: u64) void {
            @atomicStore(u64, &self.stamp, value, .monotonic);
        }

        fn asInstance(self: *Slot) *Instance {
            return @as(*Instance, @ptrCast(self));
        }
    };

    /// The bytes one Instance holds: its slot, the Instance and its stamp
    /// (what a Browser's DOM memory counts for a node's handle,
    /// dom.instance_bridge.storageBytes).
    pub const slot_bytes: usize = @sizeOf(Slot);

    const generation_bits = 56;
    const generation_mask: u64 = (@as(u64, 1) << generation_bits) - 1;

    /// The next generation to stamp; never reused within this Browser. A
    /// Browser's starts at its heap's random seed (runtime.BrowserScope.
    /// reserveHeap): a (pointer, generation) pair held across Browsers
    /// cannot match another Browser's object. Atomic: every thread of the
    /// Browser issues.
    next_generation: u64 = dead_generation + 1,

    /// What `generationOf` reads for a slot that is free (or never issued,
    /// or in a decommitted span).
    pub const dead_generation: u64 = 0;

    fn engine(self: *SlabAllocator) error{OutOfMemory}!*heap.Engine {
        const BrowserScope = @import("browser_scope.zig").BrowserScope;
        const scope: *BrowserScope = @fieldParentPtr("slab", self);
        return scope.heapEngine() catch return error.OutOfMemory;
    }

    /// The slab of the Browser whose heap issued `inst`. Valid for every
    /// Instance `alloc` issued, freed or not, until its scope ends.
    pub fn ownerOf(inst: *const Instance) *SlabAllocator {
        const BrowserScope = @import("browser_scope.zig").BrowserScope;
        return &BrowserScope.ofHeap(browser_heap.heapOf(inst)).slab;
    }

    /// A slot for an Instance with `vtable`, under a generation no earlier
    /// occupant of that address ever carried, with no lifecycle flags.
    pub fn alloc(self: *SlabAllocator, vtable: *const VTable) !*Instance {
        const e = try self.engine();
        const slot: *Slot = @ptrCast(@alignCast(try e.allocInstance()));
        const generation = @atomicRmw(u64, &self.next_generation, .Add, 1, .monotonic);
        slot.storeStamp(generation & generation_mask);
        const inst = slot.asInstance();
        inst.* = .{
            .vtable = vtable,
            .state = undefined, // Caller will set this
            .ctx = undefined, // Caller will set this
        };
        return inst;
    }

    /// `alloc`, and its State - a `StateType`, ZEROED, made as
    /// ArenaAllocator.create makes one - in one heap call
    /// (heap.Engine.allocInstanceWith: one lock, not two). What
    /// Instance.init makes.
    pub fn allocWithState(self: *SlabAllocator, vtable: *const VTable, comptime StateType: type) !*Instance {
        if (@sizeOf(StateType) == 0) {
            const inst = try self.alloc(vtable);
            inst.state = @ptrFromInt(@alignOf(StateType));
            return inst;
        }
        const e = try self.engine();
        const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;
        const blocks = try e.allocInstanceWith(comptime ArenaAllocator.targetOf(StateType), @sizeOf(StateType), @alignOf(StateType), heap.Site.of(StateType), @returnAddress());
        const slot: *Slot = @ptrCast(@alignCast(blocks.slot));
        const generation = @atomicRmw(u64, &self.next_generation, .Add, 1, .monotonic);
        slot.storeStamp(generation & generation_mask);
        const inst = slot.asInstance();
        inst.* = .{
            .vtable = vtable,
            .state = @ptrCast(@alignCast(blocks.state)),
            .ctx = undefined, // Caller will set this
        };
        return inst;
    }

    /// `free`, and the State block of `size`/`alignment` it points to, in
    /// one heap call (heap.Engine.freeInstanceWith): runtime.gc.releaseStorage.
    pub fn freeWithState(self: *SlabAllocator, inst: *Instance, size: usize, alignment: usize) void {
        if (size == 0) return self.free(inst);
        const state: [*]u8 = @ptrCast(inst.state);
        const slot: *Slot = @ptrCast(inst);
        slot.storeStamp((slot.loadStamp() & ~generation_mask) | dead_generation);
        const e = self.engine() catch @panic("SlabAllocator.freeWithState: an Instance of a scope that never had a heap");
        e.freeInstanceWith(@ptrCast(slot), state, size, alignment);
    }

    /// Raise the generation counter to at least `seed` (never back).
    pub fn seedGenerations(self: *SlabAllocator, seed: u64) void {
        _ = @atomicRmw(u64, &self.next_generation, .Max, seed, .monotonic);
    }

    /// The generation the next Instance this allocator issues will carry:
    /// every one issued after this reading carries one at or above it, every
    /// one issued before carries one below. An atomic load, for the agent's
    /// callback entry (dom_algorithm.enterCallback), the hottest place that
    /// asks. runtime.gc.DeferredTeardown's fresh rule reads it.
    pub fn generationNow(self: *const SlabAllocator) u64 {
        return @atomicLoad(u64, &self.next_generation, .monotonic);
    }

    /// The generation stamped on the slot holding `inst`, or `dead_generation`
    /// once it has been freed. Valid for every Instance the heap issued. A
    /// holder compares this against the value it read at acquisition.
    pub fn generationOf(inst: *const Instance) u64 {
        const slot: *const Slot = @ptrCast(inst);
        return slot.loadStamp() & generation_mask;
    }

    /// The lifecycle flags of the slot holding `inst` (runtime.instance_lifecycle).
    pub fn lifecycleBitsOf(inst: *const Instance) u8 {
        const slot: *const Slot = @ptrCast(inst);
        return @truncate(slot.loadStamp() >> generation_bits);
    }

    /// Set the lifecycle flags of the slot holding `inst` - its own thread's
    /// object, which only that thread frees.
    pub fn setLifecycleBits(inst: *const Instance, bits: u8) void {
        const slot: *Slot = @ptrCast(@constCast(inst));
        slot.storeStamp((slot.loadStamp() & generation_mask) | (@as(u64, bits) << generation_bits));
    }

    /// Free an Instance: its stamp reads dead (its lifecycle flags stay
    /// until the slot is issued again), then the heap takes the slot back -
    /// validated, its Instance words zeroed, held while its task runs.
    pub fn free(self: *SlabAllocator, inst: *Instance) void {
        const slot: *Slot = @ptrCast(inst);
        slot.storeStamp((slot.loadStamp() & ~generation_mask) | dead_generation);
        const e = self.engine() catch @panic("SlabAllocator.free: an Instance of a scope that never had a heap");
        e.freeInstance(@ptrCast(slot));
    }

    /// Call `visit(context, instance)` with every Instance this Browser has
    /// issued and not freed, span by span. The enumeration of a Browser's
    /// objects that runtime.OwnState's sweeps and counts walk.
    ///
    /// Only where no other thread makes or frees objects of this Browser
    /// meanwhile (a Browser's end, after every worker has ended; a test).
    /// `visit` may free objects of this allocator, but must not make any: a
    /// slot issued during the walk may or may not be visited.
    pub fn forEachLive(self: *SlabAllocator, context: anytype, comptime visit: fn (@TypeOf(context), *Instance) void) void {
        var it = self.iterateLive();
        while (it.next()) |instance| visit(context, instance);
    }

    /// `forEachLive` as an iterator, under the same rule.
    pub fn iterateLive(self: *SlabAllocator) LiveIterator {
        const BrowserScope = @import("browser_scope.zig").BrowserScope;
        const scope: *BrowserScope = @fieldParentPtr("slab", self);
        const e = scope.existingHeapEngine() orelse return .{ .slots = null };
        return .{ .slots = e.instanceSlots() };
    }

    pub const LiveIterator = struct {
        slots: ?heap.Engine.InstanceSlots,

        pub fn next(it: *LiveIterator) ?*Instance {
            const slots = if (it.slots) |*s| s else return null;
            while (slots.next()) |bytes| {
                const slot: *Slot = @ptrCast(@alignCast(bytes));
                if (slot.loadStamp() & generation_mask == dead_generation) continue;
                return slot.asInstance();
            }
            return null;
        }
    };

    /// Allocation statistics.
    pub fn stats(self: *SlabAllocator) Stats {
        const BrowserScope = @import("browser_scope.zig").BrowserScope;
        const scope: *BrowserScope = @fieldParentPtr("slab", self);
        const e = scope.existingHeapEngine() orelse return .{};
        const counts = e.instanceCounts();
        return .{
            .total_allocated = counts.issued,
            .total_freed = counts.issued - counts.live,
            .currently_allocated = counts.live,
            .peak_allocated = counts.peak,
            .total_capacity = counts.capacity,
        };
    }

    pub const Stats = struct {
        total_allocated: usize = 0,
        total_freed: usize = 0,
        currently_allocated: usize = 0,
        /// The most Instances live at once over the Browser's life.
        peak_allocated: usize = 0,
        /// Slots in the spans the Browser's Instances have taken: they never
        /// leave the Instance bucket. Since lane hard1 not the high-water
        /// mark of live Instances (`peak_allocated` is): a slot the
        /// quarantine holds through a task, or a bucket's magazine caches,
        /// is no live Instance but keeps its span's slot taken.
        total_capacity: usize = 0,
    };

    /// Slots per span of the Instance bucket.
    pub const slots_per_span: usize = heap.span_bytes / heap.instance_slot_bytes;

    /// The scope's end: the heap's reservation goes with every slot.
    pub fn deinit(self: *SlabAllocator) void {
        _ = self;
    }
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
    if (@sizeOf(Slot) != heap.instance_slot_bytes) @compileError("a slot is the heap's Instance slot");
    if (@offsetOf(Slot, "stamp") != heap.instance_fill_bytes) @compileError("the heap fills the Instance, never the stamp");
}
