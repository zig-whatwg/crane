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

test "ValueIterable - basic iteration" {
    const Context = struct {
        items: []const i32,
        index: usize,

        fn getIterator(ctx: *anyopaque) ValueIterable(i32).Iterator {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.index = 0;
            return .{
                .context = ctx,
                .next_fn = nextValue,
            };
        }

        fn nextValue(ctx: *anyopaque) ?i32 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.index >= self.items.len) return null;
            defer self.index += 1;
            return self.items[self.index];
        }
    };

    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var context = Context{ .items = &items, .index = 0 };

    var iterable = ValueIterable(i32).init(@ptrCast(&context), Context.getIterator);

    var iter = iterable.iterator();
    var sum: i32 = 0;
    while (iter.next()) |value| {
        sum += value;
    }

    try testing.expectEqual(@as(i32, 15), sum);
}

test "PairIterable - basic iteration" {
    const Context = struct {
        keys: []const []const u8,
        values: []const i32,
        index: usize,

        fn getIterator(ctx: *anyopaque) PairIterable([]const u8, i32).Iterator {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.index = 0;
            return .{
                .context = ctx,
                .next_fn = nextEntry,
            };
        }

        fn nextEntry(ctx: *anyopaque) ?PairIterable([]const u8, i32).Entry {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.index >= self.keys.len) return null;
            defer self.index += 1;
            return .{
                .key = self.keys[self.index],
                .value = self.values[self.index],
            };
        }
    };

    const keys = [_][]const u8{ "a", "b", "c" };
    const values = [_]i32{ 1, 2, 3 };
    var context = Context{ .keys = &keys, .values = &values, .index = 0 };

    var iterable = PairIterable([]const u8, i32).init(@ptrCast(&context), Context.getIterator);

    var iter = iterable.iterator();
    var count: usize = 0;
    while (iter.next()) |entry| {
        count += 1;
        _ = entry;
    }

    try testing.expectEqual(@as(usize, 3), count);
}

test "PairIterable - keys iterator" {
    const Context = struct {
        keys: []const []const u8,
        values: []const i32,
        index: usize,

        fn getIterator(ctx: *anyopaque) PairIterable([]const u8, i32).Iterator {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.index = 0;
            return .{
                .context = ctx,
                .next_fn = nextEntry,
            };
        }

        fn nextEntry(ctx: *anyopaque) ?PairIterable([]const u8, i32).Entry {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.index >= self.keys.len) return null;
            defer self.index += 1;
            return .{
                .key = self.keys[self.index],
                .value = self.values[self.index],
            };
        }
    };

    const keys = [_][]const u8{ "a", "b" };
    const values = [_]i32{ 1, 2 };
    var context = Context{ .keys = &keys, .values = &values, .index = 0 };

    var iterable = PairIterable([]const u8, i32).init(@ptrCast(&context), Context.getIterator);

    var iter = iterable.keys();
    var count: usize = 0;
    while (iter.next()) |key| {
        count += 1;
        _ = key;
    }

    try testing.expectEqual(@as(usize, 2), count);
}

test "PairIterable - values iterator" {
    const Context = struct {
        keys: []const []const u8,
        values: []const i32,
        index: usize,

        fn getIterator(ctx: *anyopaque) PairIterable([]const u8, i32).Iterator {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.index = 0;
            return .{
                .context = ctx,
                .next_fn = nextEntry,
            };
        }

        fn nextEntry(ctx: *anyopaque) ?PairIterable([]const u8, i32).Entry {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.index >= self.keys.len) return null;
            defer self.index += 1;
            return .{
                .key = self.keys[self.index],
                .value = self.values[self.index],
            };
        }
    };

    const keys = [_][]const u8{ "a", "b" };
    const values = [_]i32{ 10, 20 };
    var context = Context{ .keys = &keys, .values = &values, .index = 0 };

    var iterable = PairIterable([]const u8, i32).init(@ptrCast(&context), Context.getIterator);

    var iter = iterable.values();
    var sum: i32 = 0;
    while (iter.next()) |value| {
        sum += value;
    }

    try testing.expectEqual(@as(i32, 30), sum);
}

test "AsyncIterable - basic async iteration" {
    const Context = struct {
        items: []const i32,
        index: usize,

        fn getIterator(ctx: *anyopaque) AsyncIterable(i32).AsyncIterator {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.index = 0;
            return .{
                .context = ctx,
                .next_fn = nextValue,
            };
        }

        fn nextValue(ctx: *anyopaque) anyerror!?i32 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.index >= self.items.len) return null;
            defer self.index += 1;
            return self.items[self.index];
        }
    };

    const items = [_]i32{ 1, 2, 3 };
    var context = Context{ .items = &items, .index = 0 };

    var iterable = AsyncIterable(i32).init(@ptrCast(&context), Context.getIterator);

    var iter = iterable.asyncIterator();
    var sum: i32 = 0;
    while (try iter.next()) |value| {
        sum += value;
    }

    try testing.expectEqual(@as(i32, 6), sum);
}

test "AsyncIterable - error handling" {
    const Context = struct {
        should_error: bool,

        fn getIterator(ctx: *anyopaque) AsyncIterable(i32).AsyncIterator {
            return .{
                .context = ctx,
                .next_fn = nextValue,
            };
        }

        fn nextValue(ctx: *anyopaque) anyerror!?i32 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.should_error) return error.IterationFailed;
            return null;
        }
    };

    var context = Context{ .should_error = true };

    var iterable = AsyncIterable(i32).init(@ptrCast(&context), Context.getIterator);

    var iter = iterable.asyncIterator();

    try testing.expectError(error.IterationFailed, iter.next());
}
