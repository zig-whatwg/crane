//! InstanceRegistry - Generic registry pattern for mapping runtime instances to internal state
//!
//! This utility provides a type-safe, lazy-initialized registry pattern that maps
//! runtime.Instance pointers to internal state structures. This pattern is used
//! throughout the DOM implementation to handle inheritance hierarchies where each
//! class in the chain needs its own internal state.
//!
//! ## Usage
//!
//! ```zig
//! const InternalState = struct {
//!     allocator: std.mem.Allocator,
//!     // ... other fields
//! };
//!
//! const Registry = InstanceRegistry(InternalState);
//!
//! // In init:
//! try Registry.set(instance, internal);
//!
//! // In getters/methods:
//! const internal = Registry.get(instance) orelse return error.InvalidStateError;
//!
//! // In deinit:
//! Registry.remove(instance);
//! ```
//!
//! ## Benefits
//!
//! - ~30 lines of boilerplate removed per impl file
//! - Consistent lazy initialization across all impls
//! - Type-safe access to internal state
//! - Single point of maintenance for registry logic

const std = @import("std");

/// Generic instance registry that maps pointer addresses to internal state.
///
/// This is a comptime-generated type that provides lazy-initialized registry
/// functionality for any InternalState type. Each instantiation creates a
/// separate registry with its own storage.
///
/// Uses `*anyopaque` as the key type to work with any instance pointer type.
pub fn InstanceRegistry(comptime T: type) type {
    return struct {
        /// The underlying map storage - lazily initialized on first use.
        /// Uses usize as key since we store @intFromPtr(instance).
        /// What the map stores: the state plus who owns it.
        ///
        /// Ownership cannot be inferred from the pointer, and getting it wrong is
        /// either a double free or a leak, so it is recorded at registration.
        /// Named Slot rather than Entry because `Entry` is already this module's
        /// public iteration type.
        const Slot = struct {
            ptr: *T,
            /// The allocator that owns `ptr`, type-erased, or null when the caller
            /// owns it (`set`).
            ///
            /// Type-erased with a thunk rather than imported: `webidl` cannot import
            /// `runtime` - runtime imports webidl, so it would be a cycle - and
            /// `remove` must be able to free without knowing the arena's type.
            owner: ?*anyopaque = null,
            free_fn: ?*const fn (*anyopaque, *T) void = null,

            fn release(self: Slot) void {
                const owner = self.owner orelse return;
                const f = self.free_fn orelse return;
                f(owner, self.ptr);
            }
        };

        var map: ?std.AutoHashMap(usize, Slot) = null;

        /// Ensure the registry is initialized.
        /// This is called automatically by get/set/remove but can be called
        /// explicitly if needed.
        pub fn ensure() *std.AutoHashMap(usize, Slot) {
            if (map == null) {
                map = std.AutoHashMap(usize, Slot).init(std.heap.page_allocator);
            }
            return &map.?;
        }

        /// Get the internal state for an instance.
        /// Returns null if no state is registered for this instance.
        /// Accepts any pointer type - uses the pointer address as the key.
        pub fn get(instance: anytype) ?*T {
            const m = ensure();
            const entry = m.get(@intFromPtr(instance)) orelse return null;
            return entry.ptr;
        }

        /// Register internal state for an instance.
        /// Returns error.OutOfMemory if allocation fails.
        /// Accepts any pointer type - uses the pointer address as the key.
        ///
        /// The caller keeps ownership of `internal`; `remove` will not free it.
        /// Use `create` instead to have the registry own the allocation - that is
        /// the only way a discarded node's internal state comes back.
        pub fn set(instance: anytype, internal: *T) !void {
            const m = ensure();
            try m.put(@intFromPtr(instance), .{ .ptr = internal });
        }

        /// Allocate internal state from `arena` and register it, with the registry
        /// owning the block.
        ///
        /// Measured reason this exists: after state recycling landed, 904 bytes per
        /// discarded element were still held, all of it InternalState blocks that
        /// `remove` dropped from the map without returning to the arena. 17 of the
        /// 21 users allocate from the arena and 4 do not, so ownership has to be
        /// recorded rather than assumed - freeing a caller-owned block would be a
        /// double free, and assuming caller-owned keeps the leak.
        ///
        /// `arena` is duck-typed (anything with `create`/`destroy`) to keep this
        /// module free of a `runtime` import, which would be a dependency cycle.
        /// The block is zeroed, matching `ArenaAllocator.createRaw`.
        pub fn createIn(instance: anytype, arena: anytype) !*T {
            const Arena = @typeInfo(@TypeOf(arena)).pointer.child;

            const internal = try arena.create(T);
            errdefer arena.destroy(T, internal);

            const thunk = struct {
                fn free(owner: *anyopaque, ptr: *T) void {
                    const a: *Arena = @ptrCast(@alignCast(owner));
                    a.destroy(T, ptr);
                }
            }.free;

            const m = ensure();
            try m.put(@intFromPtr(instance), .{
                .ptr = internal,
                .owner = @ptrCast(arena),
                .free_fn = thunk,
            });
            return internal;
        }

        /// Remove the internal state registration for an instance.
        /// Does nothing if no state was registered.
        /// Accepts any pointer type - uses the pointer address as the key.
        pub fn remove(instance: anytype) void {
            const m = ensure();
            if (m.fetchRemove(@intFromPtr(instance))) |kv| {
                // Returns the block only if the registry allocated it. A
                // caller-owned block freed here would be a double free; an owned
                // block left here is the 904 bytes per element this exists to stop.
                kv.value.release();
            }
        }

        /// Check if an instance has registered state.
        /// Accepts any pointer type - uses the pointer address as the key.
        pub fn contains(instance: anytype) bool {
            const m = ensure();
            return m.contains(@intFromPtr(instance));
        }

        /// Get the number of registered instances.
        /// Useful for debugging and testing.
        pub fn count() usize {
            if (map) |m| {
                return m.count();
            }
            return 0;
        }

        /// Clear all registrations.
        /// WARNING: This does NOT deinit the internal states - only clears the registry.
        /// Use with caution, typically only for testing or shutdown.
        pub fn clear() void {
            if (map) |*m| {
                m.clearRetainingCapacity();
            }
        }

        /// Iterate over all registered internal states.
        /// Useful for cleanup operations.
        ///
        /// Yields `*Slot`, so callers reach the state through `.ptr`.
        pub fn valueIterator() ?std.AutoHashMap(usize, Slot).ValueIterator {
            if (map) |m| {
                return m.valueIterator();
            }
            return null;
        }

        /// Deinitialize the registry itself.
        /// WARNING: This frees the registry storage. Only call during final cleanup.
        pub fn deinitRegistry() void {
            if (map) |*m| {
                m.deinit();
                map = null;
            }
        }

        /// Deinit ALL internal states in the registry and clear it.
        /// This is used during final cleanup to free any resources owned by
        /// internal states (e.g., strings allocated by Node, Element, etc.)
        /// that were not cleaned up by normal tree traversal (orphaned nodes).
        pub fn deinitAllAndClear() void {
            if (map) |*m| {
                var iter = m.valueIterator();
                while (iter.next()) |slot| {
                    if (@hasDecl(T, "deinit")) {
                        slot.ptr.deinit();
                    }
                    // The blocks themselves are NOT returned to the arena here.
                    // This runs during final teardown, where the arena is about to
                    // be torn down wholesale, and pushing thousands of blocks onto
                    // free lists that are about to be discarded is pure cost.
                }
                m.clearRetainingCapacity();
            }
        }

        /// Entry type for iteration - contains both instance pointer and internal state
        pub const Entry = struct {
            instance: *anyopaque,
            internal: *T,
        };

        /// Iterator for the registry entries
        pub const Iterator = struct {
            inner: std.AutoHashMap(usize, Slot).Iterator,

            pub fn next(self: *Iterator) ?Entry {
                if (self.inner.next()) |kv| {
                    return Entry{
                        .instance = @ptrFromInt(kv.key_ptr.*),
                        .internal = kv.value_ptr.ptr,
                    };
                }
                return null;
            }
        };

        /// Get an iterator over all registry entries.
        /// This allows custom cleanup logic that needs access to both instance and internal state.
        pub fn iterator() ?Iterator {
            if (map) |*m| {
                return Iterator{ .inner = m.iterator() };
            }
            return null;
        }
    };
}

// =============================================================================
// Tests
// =============================================================================

test "InstanceRegistry - basic get/set/remove" {
    const TestState = struct {
        value: u32,
    };

    const TestRegistry = InstanceRegistry(TestState);
    defer TestRegistry.deinitRegistry();

    // Create a mock instance (just need a valid pointer)
    var dummy_value: u8 = 0;
    const instance: *u8 = &dummy_value;

    // Initially empty
    try std.testing.expectEqual(@as(?*TestState, null), TestRegistry.get(instance));
    try std.testing.expect(!TestRegistry.contains(instance));

    // Set state
    var state = TestState{ .value = 42 };
    try TestRegistry.set(instance, &state);

    // Now can retrieve
    const retrieved = TestRegistry.get(instance);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(@as(u32, 42), retrieved.?.value);
    try std.testing.expect(TestRegistry.contains(instance));
    try std.testing.expectEqual(@as(usize, 1), TestRegistry.count());

    // Remove
    TestRegistry.remove(instance);
    try std.testing.expectEqual(@as(?*TestState, null), TestRegistry.get(instance));
    try std.testing.expect(!TestRegistry.contains(instance));
    try std.testing.expectEqual(@as(usize, 0), TestRegistry.count());
}

test "InstanceRegistry - multiple instances" {
    const TestState = struct {
        id: u32,
    };

    const TestRegistry = InstanceRegistry(TestState);
    defer TestRegistry.deinitRegistry();

    var dummy1: u8 = 1;
    var dummy2: u8 = 2;
    var dummy3: u8 = 3;

    var state1 = TestState{ .id = 1 };
    var state2 = TestState{ .id = 2 };
    var state3 = TestState{ .id = 3 };

    try TestRegistry.set(&dummy1, &state1);
    try TestRegistry.set(&dummy2, &state2);
    try TestRegistry.set(&dummy3, &state3);

    try std.testing.expectEqual(@as(usize, 3), TestRegistry.count());
    try std.testing.expectEqual(@as(u32, 1), TestRegistry.get(&dummy1).?.id);
    try std.testing.expectEqual(@as(u32, 2), TestRegistry.get(&dummy2).?.id);
    try std.testing.expectEqual(@as(u32, 3), TestRegistry.get(&dummy3).?.id);

    TestRegistry.remove(&dummy2);
    try std.testing.expectEqual(@as(usize, 2), TestRegistry.count());
    try std.testing.expectEqual(@as(?*TestState, null), TestRegistry.get(&dummy2));
}

test "InstanceRegistry - clear" {
    const TestState = struct {
        x: i32,
    };

    const TestRegistry = InstanceRegistry(TestState);
    defer TestRegistry.deinitRegistry();

    var dummy1: u8 = 1;
    var dummy2: u8 = 2;

    var state1 = TestState{ .x = 10 };
    var state2 = TestState{ .x = 20 };

    try TestRegistry.set(&dummy1, &state1);
    try TestRegistry.set(&dummy2, &state2);

    try std.testing.expectEqual(@as(usize, 2), TestRegistry.count());

    TestRegistry.clear();

    try std.testing.expectEqual(@as(usize, 0), TestRegistry.count());
    try std.testing.expectEqual(@as(?*TestState, null), TestRegistry.get(&dummy1));
    try std.testing.expectEqual(@as(?*TestState, null), TestRegistry.get(&dummy2));
}
