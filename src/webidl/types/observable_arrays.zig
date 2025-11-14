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










