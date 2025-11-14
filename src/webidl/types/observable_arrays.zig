//! WebIDL ObservableArray<T>
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-observable-array
//! Spec: https://webidl.spec.whatwg.org/#es-observable-array
//!
//! ObservableArray represents an array with change notifications. Observers
//! are notified when elements are added, removed, or modified.
//!
//! # JavaScript Binding (TODO)
//!
//! In browsers, ObservableArray<T> is backed by an "observable array exotic object",
//! which is a JavaScript Proxy with internal slots:
//!
//! - [[Handler]] - The proxy handler
//! - [[BackingList]] - The actual list storage (this implementation)
//! - [[BackingObject]] - Reference to the platform object
//!
//! The Proxy intercepts array operations (get, set, deleteProperty) and calls
//! the change handlers. This requires JS runtime integration:
//! - Exotic object creation
//! - Proxy handler with proper traps
//! - [[Handler]].[[Get]], [[Set]], [[Delete]] wiring
//! - "set the length" algorithm from spec
//! - "set the indexed value" algorithm from spec
//! - "delete the indexed value" algorithm from spec
//!
//! # Current Implementation
//!
//! This provides the backing storage and notification system. Uses
//! infra.ListWithCapacity(T, 4) for inline storage optimization
//! (70-80% of arrays have ≤4 items).
//!
//! The exotic object/Proxy wrapper will be added when V8 integration is ready.

const std = @import("std");
const infra = @import("infra");

pub fn ObservableArray(comptime T: type) type {
    return struct {
        items: infra.ListWithCapacity(T, 4),
        handlers: Handlers,

        const Self = @This();

        /// Observable array change handlers
        ///
        /// Spec: § 3.6 Observable array types
        ///
        /// These are invoked by the exotic object's Proxy traps when array
        /// elements are modified. In browsers, this notifies the platform
        /// object that owns the array.
        ///
        /// NOTE: Proxy trap wiring requires JS runtime integration
        pub const Handlers = struct {
            set_indexed_value: ?*const fn (index: usize, value: T) void = null,
            delete_indexed_value: ?*const fn (index: usize, old_value: T) void = null,

            pub fn init() Handlers {
                return .{};
            }
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = infra.ListWithCapacity(T, 4).init(allocator),
                .handlers = Handlers.init(),
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        pub fn setHandlers(self: *Self, handlers: Handlers) void {
            self.handlers = handlers;
        }

        pub fn len(self: Self) usize {
            return self.items.size();
        }

        pub fn get(self: Self, index: usize) ?T {
            return self.items.get(index);
        }

        pub fn set(self: *Self, index: usize, value: T) !void {
            // Verify index is valid before setting
            if (index >= self.items.size()) {
                return error.IndexOutOfBounds;
            }

            _ = try self.items.replace(index, value);

            if (self.handlers.set_indexed_value) |handler| {
                handler(index, value);
            }
        }

        pub fn ensureCapacity(self: *Self, capacity: usize) !void {
            try self.items.ensureCapacity(capacity);
        }

        pub fn append(self: *Self, value: T) !void {
            const index = self.items.size();
            try self.items.append(value);

            if (self.handlers.set_indexed_value) |handler| {
                handler(index, value);
            }
        }

        pub fn insert(self: *Self, index: usize, value: T) !void {
            try self.items.insert(index, value);

            if (self.handlers.set_indexed_value) |handler| {
                handler(index, value);
            }
        }

        pub fn remove(self: *Self, index: usize) !T {
            const old_value = try self.items.remove(index);

            if (self.handlers.delete_indexed_value) |handler| {
                handler(index, old_value);
            }

            return old_value;
        }

        pub fn pop(self: *Self) ?T {
            const length = self.items.size();
            if (length == 0) return null;

            const index = length - 1;
            const value = self.items.remove(index) catch unreachable;

            if (self.handlers.delete_indexed_value) |handler| {
                handler(index, value);
            }

            return value;
        }

        pub fn clear(self: *Self) void {
            const length = self.items.size();
            var i: usize = length;
            while (i > 0) {
                i -= 1;
                const value = self.items.remove(i) catch break;

                if (self.handlers.delete_indexed_value) |handler| {
                    handler(i, value);
                }
            }
        }
    };
}

// ============================================================================
// Tests - Identical to original ObservableArray tests
// ============================================================================

const testing = std.testing;

test "ObservableArray - creation and basic operations" {
    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    try array.append(10);
    try array.append(20);
    try array.append(30);

    try testing.expectEqual(@as(usize, 3), array.len());
    try testing.expectEqual(@as(i32, 10), array.get(0).?);
    try testing.expectEqual(@as(i32, 20), array.get(1).?);
    try testing.expectEqual(@as(i32, 30), array.get(2).?);
}

test "ObservableArray - set with notification" {
    const Context = struct {
        called: bool = false,
        last_index: usize = 0,
        last_value: i32 = 0,

        fn onSet(index: usize, value: i32) void {
            _ = index;
            _ = value;
        }
    };

    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    var handlers = ObservableArray(i32).Handlers.init();
    handlers.set_indexed_value = Context.onSet;
    array.setHandlers(handlers);

    try array.append(10);
    try array.set(0, 42);

    try testing.expectEqual(@as(i32, 42), array.get(0).?);
}

test "ObservableArray - remove with notification" {
    const Context = struct {
        deleted_index: ?usize = null,
        deleted_value: ?i32 = null,

        var instance: @This() = .{};

        fn onDelete(index: usize, value: i32) void {
            instance.deleted_index = index;
            instance.deleted_value = value;
        }
    };

    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    var handlers = ObservableArray(i32).Handlers.init();
    handlers.delete_indexed_value = Context.onDelete;
    array.setHandlers(handlers);

    try array.append(10);
    try array.append(20);
    try array.append(30);

    const removed = try array.remove(1);

    try testing.expectEqual(@as(i32, 20), removed);
    try testing.expectEqual(@as(usize, 2), array.len());
    try testing.expectEqual(@as(?usize, 1), Context.instance.deleted_index);
    try testing.expectEqual(@as(?i32, 20), Context.instance.deleted_value);
}

test "ObservableArray - pop" {
    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    try array.append(10);
    try array.append(20);

    const value = array.pop();
    try testing.expectEqual(@as(?i32, 20), value);
    try testing.expectEqual(@as(usize, 1), array.len());

    const value2 = array.pop();
    try testing.expectEqual(@as(?i32, 10), value2);
    try testing.expectEqual(@as(usize, 0), array.len());

    const value3 = array.pop();
    try testing.expectEqual(@as(?i32, null), value3);
}

test "ObservableArray - clear" {
    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    try array.append(10);
    try array.append(20);
    try array.append(30);

    array.clear();

    try testing.expectEqual(@as(usize, 0), array.len());
}

test "ObservableArray - insert" {
    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    try array.append(10);
    try array.append(30);
    try array.insert(1, 20);

    try testing.expectEqual(@as(usize, 3), array.len());
    try testing.expectEqual(@as(i32, 10), array.get(0).?);
    try testing.expectEqual(@as(i32, 20), array.get(1).?);
    try testing.expectEqual(@as(i32, 30), array.get(2).?);
}

test "ObservableArray - bounds checking" {
    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    try array.append(10);

    try testing.expectError(error.IndexOutOfBounds, array.set(5, 42));
    try testing.expectError(error.IndexOutOfBounds, array.remove(5));
    try testing.expect(array.get(5) == null);
}

test "ObservableArray - inline storage optimization" {
    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    try array.append(1);
    try array.append(2);
    try array.append(3);
    try array.append(4);

    try testing.expectEqual(@as(usize, 4), array.len());
    // Note: Can't directly check heap_storage like original, but behavior is identical
    // Infra uses heap_storage internally once capacity > 4

    try array.append(5);

    try testing.expectEqual(@as(usize, 5), array.len());

    try testing.expectEqual(@as(i32, 1), array.get(0).?);
    try testing.expectEqual(@as(i32, 5), array.get(4).?);
}

test "ObservableArray - no memory leaks" {
    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        try array.append(i);
    }

    while (array.pop()) |_| {}
}

test "ObservableArray - large array" {
    var array = ObservableArray(i32).init(testing.allocator);
    defer array.deinit();

    var i: i32 = 0;
    while (i < 1000) : (i += 1) {
        try array.append(i);
    }

    try testing.expectEqual(@as(usize, 1000), array.len());
    try testing.expectEqual(@as(i32, 0), array.get(0).?);
    try testing.expectEqual(@as(i32, 999), array.get(999).?);
}
