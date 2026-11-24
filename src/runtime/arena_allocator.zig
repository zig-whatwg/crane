//! The state arena: where a Browser's platform objects take their State
//! blocks and the side blocks their impls keep (`runtime.arenaOf(instance)
//! .create/.destroy`) - now a VIEW of the Browser's heap (lane hard1,
//! allocator-hardening batch A; tmp/plans/allocator-hardening-design.md 4.1,
//! 7 item 3).
//!
//! One per Browser (runtime.BrowserScope.arena, docs/instances.md). Its
//! public API is what it was, so the arenaOf callers compile unchanged; what
//! it does is the span engine's (src/runtime/heap/):
//!
//! - a node's State goes to the NODE partition, keyed by its size class and
//!   its kind - element, character data or other - a comptime property of
//!   its State type (`targetOf`); every other State and side block to the
//!   OBJECTS partition. One free list no longer serves every interface: a
//!   freed div is never reissued as an Event (design 3.2);
//! - a free is routed by its ADDRESS (the free path is untyped:
//!   `Instance.deinit` has a vtable, not a type) and validated against the
//!   size it is given - class, alignment, owner, double free - in every
//!   build (design 3.3);
//! - a freed block is zeroed (poisoned in Debug and the bug-finding run),
//!   checked on its reissue, held until its task ends when the window
//!   agent's loop runs one, and its span decommitted once empty and idle.
//!
//! What it no longer has: the inline LIFO free lists (a raw link in a freed
//! block - one write after a free turned the next allocation into any
//! address), the bump path that never freed (`alloc`/`dupe`: lane leak3 moved
//! DOMException's strings off it), the uaf1 FIFO quarantine (the heap's
//! task-scoped one replaces it, design 3.5), and its own mutex (the objects
//! partition has one; the node partition needs none - one thread).
//!
//! Thread safety: the node partition is the window agent's thread's (an
//! owner check on every call); the objects partition takes its lock.

const std = @import("std");
const heap = @import("heap/root.zig");
const lifetime = @import("lifetime.zig");

pub const ClassScheme = heap.classes.ClassScheme;
pub const class_scheme = heap.classes.class_scheme;
pub const SizeClasses = heap.classes.SizeClasses;

/// The state arena: a Browser's State blocks, in its heap. Only ever a
/// field of a runtime.BrowserScope (it finds its heap through it).
pub const ArenaAllocator = struct {
    /// Whether a freed state block is overwritten with `poison_byte` (the
    /// heap's poisoning configuration: heap.Config.debug_default). Set once,
    /// where the Browser's scope is made, before its heap starts: on in a
    /// Debug build (runtime.BrowserScope.poisonsFreedStateByDefault: the
    /// unit tests and the bug-finding runner) and in any build whose
    /// Browser asked (BrowserConfig.poison_freed_state). Off in every
    /// release build by default: the heap zeroes instead.
    poison_freed: bool = false,

    /// Whether the Browser asked for the bug-finding run's detection
    /// (BrowserConfig.poison_freed_state): with `poison_freed`, the heap's
    /// bug-finding configuration (heap.Config.bug_finding) - an 8 MiB
    /// quarantine, inaccessible freed spans, allocation sites.
    quarantine_freed: bool = false,

    /// The byte a poisoning heap fills a freed block with
    /// (tests/test_runner/poisoning.zig's 0xdd).
    pub const poison_byte: u8 = heap.poison_byte;

    /// The size classes.
    const Classes = SizeClasses(class_scheme);

    fn engine(self: *ArenaAllocator) error{OutOfMemory}!*heap.Engine {
        const BrowserScope = @import("browser_scope.zig").BrowserScope;
        const scope: *BrowserScope = @alignCast(@fieldParentPtr("arena", self));
        return scope.heapEngine() catch return error.OutOfMemory;
    }

    /// The bytes a state of `size`/`alignment` holds once made: its class's
    /// block, or its run of spans. What a Browser's DOM memory counts for a
    /// node's state (dom.instance_bridge.storageBytes); unchanged by the
    /// move to the heap (the arena's classes are the heap's).
    pub fn heldBytes(size: usize, alignment: usize) usize {
        if (size == 0) return 0;
        const class = heap.classes.classOf(size, alignment) orelse {
            const bytes = heap.classes.requestBytes(size, alignment);
            return std.mem.alignForward(usize, bytes, heap.span_bytes);
        };
        return Classes.bytes(class);
    }

    /// The partition and kind a State of type `T` goes to: a node's State
    /// (runtime.lifetime.countedOf finds it) to the node partition, by the
    /// `heap_kind` its levels' InternalStates declare - Element's and
    /// CharacterData's (found through the generated State's fields, as
    /// countedOf finds `counted_node`, so nothing names an impl) - most
    /// derived first, `other` when none does (Document, DocumentFragment,
    /// ShadowRoot, Attr, DocumentType). Everything else to objects.
    pub fn targetOf(comptime T: type) heap.Target {
        comptime {
            if (@typeInfo(T) != .@"struct" or lifetime.countedOf(T) == null) return .objects;
            var Level: type = T;
            while (true) {
                if (@hasField(Level, "_embedded")) {
                    const Embedded = @FieldType(Level, "_embedded");
                    // hasdecl: a generated State level's InternalState kept by value - Element's (src/webidl/impls/Element.zig) and dom.character_data.Head declare heap_kind pub; every other one has none
                    if (@typeInfo(Embedded) == .@"struct" and @hasDecl(Embedded, "heap_kind")) return .{ .node = Embedded.heap_kind };
                }
                if (!@hasField(Level, "base")) break;
                const Base = @FieldType(Level, "base");
                if (Base == void) break;
                Level = Base;
            }
            return .{ .node = .other };
        }
    }

    /// Create a `T` - ZEROED: Zig does not apply struct defaults through an
    /// allocator, and every caller (Instance.init, OwnState.createIn,
    /// InstanceRegistry.createIn) relies on the zero.
    ///
    ///   const state = try runtime.arenaOf(instance).create(FullState);
    pub fn create(self: *ArenaAllocator, comptime T: type) !*T {
        if (@sizeOf(T) == 0) return @ptrFromInt(@alignOf(T));
        const e = try self.engine();
        const block = try e.alloc(comptime targetOf(T), @sizeOf(T), @alignOf(T), heap.Site.of(T), @returnAddress());
        return @ptrCast(@alignCast(block));
    }

    /// `create` for a size known only at runtime: an objects-partition
    /// block, zeroed.
    ///
    /// A zero-sized state is not exotic: any interface that keeps no
    /// internal state has one (`Geolocation`, `Clipboard`). Zig's allocator
    /// contract says what to hand back - a non-null, aligned pointer never
    /// dereferenced - and `destroyRaw` frees nothing for it.
    pub fn createRaw(self: *ArenaAllocator, size: usize, alignment: usize) ![*]u8 {
        if (size == 0) return @ptrFromInt(@max(alignment, 1));
        const e = try self.engine();
        return e.alloc(.objects, size, alignment, null, @returnAddress());
    }

    /// Hand a state block back. Callers have run the type's own cleanup
    /// first - this releases the block, not what it points to
    /// (`Instance.deinit`, `gc.releaseStorage`).
    pub fn destroy(self: *ArenaAllocator, comptime T: type, ptr: *T) void {
        if (@sizeOf(T) == 0) return;
        self.destroyRaw(@ptrCast(ptr), @sizeOf(T), @alignOf(T));
    }

    /// `destroy` for a size known only at runtime - the vtable's: routed by
    /// the block's address, validated against `size`/`alignment` (a free of
    /// another class, an interior pointer, another Browser's block or a
    /// double free is a panic in every build: design 3.3).
    pub fn destroyRaw(self: *ArenaAllocator, ptr: [*]u8, size: usize, alignment: usize) void {
        if (size == 0) return;
        const e = self.engine() catch @panic("ArenaAllocator.destroyRaw: a block freed through a scope that never had a heap");
        e.free(ptr, size, alignment);
    }

    /// The scope's end: nothing to free here - the heap's reservation goes,
    /// with every block in it, when the scope releases it last.
    pub fn deinit(self: *ArenaAllocator) void {
        _ = self;
    }

    /// Allocation statistics: the heap's State blocks, node and objects
    /// partitions - its Instance slots (the slab's) left out.
    pub fn stats(self: *ArenaAllocator) Stats {
        const BrowserScope = @import("browser_scope.zig").BrowserScope;
        const scope: *BrowserScope = @alignCast(@fieldParentPtr("arena", self));
        const e = scope.existingHeapEngine() orelse return .{};
        const s = e.stats();
        const slots = e.instanceCounts();
        const slot_request = heap.instance_fill_bytes;
        return .{
            .total_allocations = s.node.total_allocations + s.objects.total_allocations - slots.issued,
            .total_bytes_allocated = s.node.total_requested_bytes + s.objects.total_requested_bytes - slots.issued * slot_request,
            .bytes_in_use = s.node.requested_bytes + s.objects.requested_bytes -| slots.live * slot_request,
            .total_recycled = s.node.total_reissued + s.objects.total_reissued,
            .live_blocks = s.node.live_blocks + s.objects.live_blocks - slots.live,
        };
    }

    pub const Stats = struct {
        /// State blocks made over the heap's life.
        total_allocations: usize = 0,
        /// Their requests' bytes: cumulative, it only rises.
        total_bytes_allocated: usize = 0,
        /// The requests' bytes of the State blocks live now: the figure to
        /// read for retention.
        bytes_in_use: usize = 0,
        /// Blocks (Instance slots included) issued from a slot freed before.
        total_recycled: usize = 0,
        /// State blocks live now.
        live_blocks: usize = 0,
    };
};
