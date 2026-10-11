//! InstanceRegistry - an impl's internal state for each of its instances, in
//! the instance's Browser's side table (instances B1, docs/instances.md).
//!
//! An impl that keeps per-instance state outside the generated State (most
//! DOM types: Node, Element, HTMLElement, ...) registers it here, keyed by the
//! instance's address. The table is its Browser's - a side table of the
//! instance's `BrowserScope` (`BrowserScope.Table`), found from the instance's
//! address - so a Browser's entries are its own, its end takes them with it,
//! and another Browser's end never reaches them.
//!
//! ## Usage
//!
//! ```zig
//! const Registry = runtime.InstanceRegistry(.node, InternalState);
//!
//! // In init (the block from the instance's arena, owned by the registry):
//! const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
//!
//! // In getters/methods:
//! const internal = Registry.get(instance) orelse return error.InvalidStateError;
//!
//! // In deinit:
//! Registry.remove(instance);
//! ```
//!
//! Thread safety: none, as before the move - every type registered here is a
//! window's (DOM nodes and their companions), made and freed on its Browser's
//! window thread.

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const BrowserScope = @import("browser_scope.zig").BrowserScope;
const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;
const TombstoneGuard = @import("webidl").utils.tombstones.TombstoneGuard;

const log = std.log.scoped(.instance_registry);

/// `T`'s registry, in its Browser's side table `tag` (one tag per `T`).
pub fn InstanceRegistry(comptime tag: BrowserScope.Table, comptime T: type) type {
    return struct {
        /// What the table stores: the state, and whether the registry owns
        /// its block (`createIn`) or the caller does (`set`).
        ///
        /// Ownership cannot be inferred from the pointer, and getting it wrong
        /// is either a double free or a leak, so it is recorded at
        /// registration.
        const Slot = struct {
            ptr: *T,
            /// The block came from the instance's arena and goes back there on
            /// `remove`.
            owned: bool = false,
        };

        /// One Browser's table of `T`.
        pub const Table = struct {
            map: std.AutoHashMap(usize, Slot),
            /// Every node a page makes is registered here and removed when
            /// the page ends, so the map sees a page's worth of removals per
            /// page and its tombstones would take every free slot: the guard
            /// rehashes before an insert when they could (tombstones.zig).
            guard: TombstoneGuard = .{},

            pub fn init(allocator: std.mem.Allocator) Table {
                return .{ .map = std.AutoHashMap(usize, Slot).init(allocator) };
            }

            /// With its Browser: the entries go. Their blocks are in the
            /// Browser's arena, which ends next; what an entry owns beyond its
            /// block its type's teardown sweep released (dom.teardown_sweeps).
            pub fn deinit(self: *Table) void {
                self.map.deinit();
            }
        };

        /// `instance`'s Browser's table, made on first use.
        fn tableFor(instance: *const Instance) !*Table {
            return BrowserScope.ofInstance(instance).table(tag, Table);
        }

        /// `instance`'s Browser's table, if one was made.
        fn tableOf(instance: *const Instance) ?*Table {
            return BrowserScope.ofInstance(instance).existingTable(tag, Table);
        }

        /// The block of `slot`, back to the arena of `instance`'s Browser if
        /// the registry owns it.
        fn release(instance: *const Instance, slot: Slot) void {
            if (slot.owned) BrowserScope.ofInstance(instance).arena.destroy(T, slot.ptr);
        }

        /// Get the internal state for an instance.
        /// Returns null if no state is registered for this instance.
        pub fn get(instance: *const Instance) ?*T {
            const table = tableOf(instance) orelse return null;
            const slot = table.map.get(@intFromPtr(instance)) orelse return null;
            return slot.ptr;
        }

        /// Take out the entry under `instance`'s address before an instance
        /// registers there, and free it. Returns whether there was one.
        ///
        /// Every registration happens once, in its instance's init, so an
        /// entry already under the key is a DEAD instance's: the slab
        /// reissued the address after a teardown that never reached this
        /// registry. Left in place it was overwritten and what it owned
        /// leaked - or, where a type fills its state lazily, the new instance
        /// took it for its own
        /// (docs/lessons/architecture-an-address-keyed-entry-a-teardown-misses-is-inherited.md).
        /// Its own deinit frees it, as the Browser's end would have.
        fn dropStale(table: *Table, instance: *const Instance) bool {
            const kv = table.map.fetchRemove(@intFromPtr(instance)) orelse return false;
            table.guard.noteRemoval(&table.map);
            if (@hasDecl(T, "deinit")) kv.value.ptr.deinit();
            release(instance, kv.value);
            return true;
        }

        /// `dropStale`, saying so: a teardown missed this registry. An error,
        /// so a unit test that meets one fails and a runner's log counts it.
        fn reportStale(table: *Table, instance: *const Instance) void {
            if (dropStale(table, instance)) log.err("stale {s} at a reissued address: a teardown missed it", .{@typeName(T)});
        }

        /// Register internal state for an instance. The caller keeps
        /// ownership of `internal`; `remove` will not free it. Use `createIn`
        /// to have the registry own the block - the only way a discarded
        /// node's internal state comes back.
        pub fn set(instance: *const Instance, internal: *T) !void {
            const table = try tableFor(instance);
            reportStale(table, instance);
            table.guard.beforeInsert(&table.map);
            try table.map.put(@intFromPtr(instance), .{ .ptr = internal });
        }

        /// Allocate internal state from `arena` - the instance's Browser's
        /// (runtime.arenaOf) - and register it, with the registry owning the
        /// block. The block is zeroed, matching `ArenaAllocator.createRaw`.
        ///
        /// Measured reason this exists: after state recycling landed, 904
        /// bytes per discarded element were still held, all of it
        /// InternalState blocks that `remove` dropped from the map without
        /// returning to the arena.
        pub fn createIn(instance: *const Instance, arena: *ArenaAllocator) !*T {
            std.debug.assert(arena == &BrowserScope.ofInstance(instance).arena);
            const table = try tableFor(instance);
            reportStale(table, instance);
            const internal = try arena.create(T);
            errdefer arena.destroy(T, internal);
            table.guard.beforeInsert(&table.map);
            try table.map.put(@intFromPtr(instance), .{ .ptr = internal, .owned = true });
            return internal;
        }

        /// Remove the internal state registration for an instance, returning
        /// its block to the arena if the registry owns it. Does nothing if no
        /// state was registered.
        pub fn remove(instance: *const Instance) void {
            const table = tableOf(instance) orelse return;
            const kv = table.map.fetchRemove(@intFromPtr(instance)) orelse return;
            table.guard.noteRemoval(&table.map);
            // A caller-owned block freed here would be a double free; an owned
            // block left here is the 904 bytes per element this exists to stop.
            release(instance, kv.value);
        }

        /// Check if an instance has registered state.
        pub fn contains(instance: *const Instance) bool {
            const table = tableOf(instance) orelse return false;
            return table.map.contains(@intFromPtr(instance));
        }

        /// How many of `scope`'s instances have registered state.
        pub fn count(scope: *BrowserScope) usize {
            const table = scope.existingTable(tag, Table) orelse return 0;
            return table.map.count();
        }

        /// Forget every one of `scope`'s entries, without their deinit.
        pub fn clear(scope: *BrowserScope) void {
            const table = scope.existingTable(tag, Table) orelse return;
            table.map.clearRetainingCapacity();
            table.guard.reset();
        }

        /// A teardown sweep's (dom.teardown_sweeps): deinit every one of
        /// `scope`'s remaining states and forget them. The blocks themselves
        /// are not returned: this runs at the Browser's end, where its arena
        /// is about to end wholesale.
        pub fn deinitAllAndClear(scope: *BrowserScope) void {
            const table = scope.existingTable(tag, Table) orelse return;
            var iter = table.map.valueIterator();
            while (iter.next()) |slot| {
                if (@hasDecl(T, "deinit")) slot.ptr.deinit();
            }
            table.map.clearRetainingCapacity();
            table.guard.reset();
        }

        /// Entry type for iteration - contains both instance pointer and internal state
        pub const Entry = struct {
            instance: *anyopaque,
            internal: *T,
        };

        /// Iterator for one Browser's entries.
        pub const Iterator = struct {
            inner: std.AutoHashMap(usize, Slot).Iterator,

            pub fn next(self: *Iterator) ?Entry {
                const kv = self.inner.next() orelse return null;
                return Entry{
                    .instance = @ptrFromInt(kv.key_ptr.*),
                    .internal = kv.value_ptr.ptr,
                };
            }
        };

        /// An iterator over `scope`'s entries, or null when it has none. No
        /// registration may happen while it is in use.
        pub fn iterator(scope: *BrowserScope) ?Iterator {
            const table = scope.existingTable(tag, Table) orelse return null;
            return Iterator{ .inner = table.map.iterator() };
        }
    };
}
