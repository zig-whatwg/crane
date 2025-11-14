//! WebIDL Iterable and Async Iterable Declarations
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-iterable
//!       https://webidl.spec.whatwg.org/#idl-async-iterable
//!
//! Iterable declarations allow interfaces to be iterated over using for-of loops.
//! Async iterables support asynchronous iteration with for-await-of loops.

const std = @import("std");
const primitives = @import("primitives.zig");

pub fn ValueIterable(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Iterator = struct {
            context: *anyopaque,
            next_fn: *const fn (*anyopaque) ?T,

            pub fn next(self: *Iterator) ?T {
                return self.next_fn(self.context);
            }
        };

        context: *anyopaque,
        iterator_fn: *const fn (*anyopaque) Iterator,

        pub fn init(context: *anyopaque, iterator_fn: *const fn (*anyopaque) Iterator) Self {
            return .{
                .context = context,
                .iterator_fn = iterator_fn,
            };
        }

        pub fn iterator(self: *Self) Iterator {
            return self.iterator_fn(self.context);
        }
    };
}

pub fn PairIterable(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Entry = struct {
            key: K,
            value: V,
        };

        pub const Iterator = struct {
            context: *anyopaque,
            next_fn: *const fn (*anyopaque) ?Entry,

            pub fn next(self: *Iterator) ?Entry {
                return self.next_fn(self.context);
            }
        };

        context: *anyopaque,
        iterator_fn: *const fn (*anyopaque) Iterator,

        pub fn init(context: *anyopaque, iterator_fn: *const fn (*anyopaque) Iterator) Self {
            return .{
                .context = context,
                .iterator_fn = iterator_fn,
            };
        }

        pub fn iterator(self: *Self) Iterator {
            return self.iterator_fn(self.context);
        }

        pub fn keys(self: *Self) KeyIterator {
            return .{ .inner = self.iterator() };
        }

        pub fn values(self: *Self) ValueIterator {
            return .{ .inner = self.iterator() };
        }

        pub const KeyIterator = struct {
            inner: Iterator,

            pub fn next(self: *KeyIterator) ?K {
                const entry = self.inner.next() orelse return null;
                return entry.key;
            }
        };

        pub const ValueIterator = struct {
            inner: Iterator,

            pub fn next(self: *ValueIterator) ?V {
                const entry = self.inner.next() orelse return null;
                return entry.value;
            }
        };
    };
}

pub fn AsyncIterable(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const AsyncIterator = struct {
            context: *anyopaque,
            next_fn: *const fn (*anyopaque) anyerror!?T,

            pub fn next(self: *AsyncIterator) !?T {
                return self.next_fn(self.context);
            }
        };

        context: *anyopaque,
        iterator_fn: *const fn (*anyopaque) AsyncIterator,

        pub fn init(context: *anyopaque, iterator_fn: *const fn (*anyopaque) AsyncIterator) Self {
            return .{
                .context = context,
                .iterator_fn = iterator_fn,
            };
        }

        pub fn asyncIterator(self: *Self) AsyncIterator {
            return self.iterator_fn(self.context);
        }
    };
}

const testing = std.testing;






