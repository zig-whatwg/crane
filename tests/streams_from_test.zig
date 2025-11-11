const std = @import("std");
const testing = std.testing;

// Import streams module and internals
const streams = @import("streams");
const common = @import("common");
const TestEventLoop = @import("test_event_loop").TestEventLoop;
const async_iterator = @import("async_iterator");
const JSValue = common.JSValue;
const ReadableStream = streams.ReadableStream;

/// Mock async iterator that yields a fixed set of values
const MockAsyncIterator = struct {
    values: []const u8,
    index: usize = 0,
    allocator: std.mem.Allocator,
    return_called: bool = false,

    fn init(allocator: std.mem.Allocator, values: []const u8) !*MockAsyncIterator {
        const self = try allocator.create(MockAsyncIterator);
        self.* = .{
            .values = values,
            .index = 0,
            .allocator = allocator,
            .return_called = false,
        };
        return self;
    }

    fn next(ctx: *anyopaque) common.Promise(common.IteratorResult) {
        const self: *MockAsyncIterator = @ptrCast(@alignCast(ctx));

        if (self.index < self.values.len) {
            const value = self.values[self.index];
            self.index += 1;
            return common.Promise(common.IteratorResult).fulfilled(.{
                .value = .{ .number = @floatFromInt(value) },
                .done = false,
            });
        } else {
            return common.Promise(common.IteratorResult).fulfilled(.{
                .value = .undefined,
                .done = true,
            });
        }
    }

    fn return_fn(ctx: *anyopaque, reason: ?common.JSValue) common.Promise(common.JSValue) {
        const self: *MockAsyncIterator = @ptrCast(@alignCast(ctx));
        _ = reason;
        self.return_called = true;
        return common.Promise(common.JSValue).fulfilled(.undefined);
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *MockAsyncIterator = @ptrCast(@alignCast(ctx));
        self.allocator.destroy(self);
    }

    fn toAsyncIterator(self: *MockAsyncIterator) common.AsyncIterator {
        return .{
            .ptr = self,
            .vtable = &.{
                .next = next,
                .return_fn = return_fn,
                .deinit = deinit,
            },
        };
    }
};

test "ReadableStream.from() - basic functionality with mock iterator" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create a mock iterator with values [1, 2, 3]
    const values = [_]u8{ 1, 2, 3 };
    const mock_iter = try MockAsyncIterator.init(allocator, &values);
    const iterator = mock_iter.toAsyncIterator();

    // For now, we can't test from() directly without a JSValue wrapper
    // But we can test that the iterator works
    const result1 = iterator.next();
    try testing.expect(result1.isFulfilled());
    try testing.expect(!result1.value.?.done);
    try testing.expectEqual(@as(f64, 1.0), result1.value.?.value.number);

    const result2 = iterator.next();
    try testing.expect(result2.isFulfilled());
    try testing.expect(!result2.value.?.done);
    try testing.expectEqual(@as(f64, 2.0), result2.value.?.value.number);

    const result3 = iterator.next();
    try testing.expect(result3.isFulfilled());
    try testing.expect(!result3.value.?.done);
    try testing.expectEqual(@as(f64, 3.0), result3.value.?.value.number);

    const result4 = iterator.next();
    try testing.expect(result4.isFulfilled());
    try testing.expect(result4.value.?.done);

    // Cleanup
    iterator.deinit();
}

test "ReadableStream.from() - iterator return() is called" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create a mock iterator
    const values = [_]u8{ 1, 2, 3, 4, 5 };
    const mock_iter = try MockAsyncIterator.init(allocator, &values);
    const iterator = mock_iter.toAsyncIterator();

    // Call return()
    try testing.expect(!mock_iter.return_called);
    _ = iterator.return_value(null);
    try testing.expect(mock_iter.return_called);

    // Cleanup
    iterator.deinit();
}

// Note: Full integration tests for ReadableStream.from() require:
// 1. JSValue wrapper for AsyncIterator
// 2. Full JavaScript runtime integration
// These tests verify the underlying iterator protocol works correctly.

// ============================================================================
// Comprehensive tests using ReadableStream.fromMockIterator()
// ============================================================================

test "ReadableStream.fromMockIterator() - basic iteration with 3 values" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const values = [_]JSValue{
        JSValue{ .number = 1 },
        JSValue{ .number = 2 },
        JSValue{ .number = 3 },
    };

    var mock = try async_iterator.MockAsyncIterator.init(allocator, &values);
    defer mock.deinit();

    var stream = try ReadableStream.fromMockIterator(allocator, loop.eventLoop(), mock);
    defer stream.deinit();

    var reader = try stream.call_getReader(null);
    defer reader.deinit();

    // Read first value
    {
        const result = try reader.call_read();
        try testing.expectEqual(false, result.done);
        try testing.expectEqual(JSValue{ .number = 1 }, result.value);
    }

    // Read second value
    {
        const result = try reader.call_read();
        try testing.expectEqual(false, result.done);
        try testing.expectEqual(JSValue{ .number = 2 }, result.value);
    }

    // Read third value
    {
        const result = try reader.call_read();
        try testing.expectEqual(false, result.done);
        try testing.expectEqual(JSValue{ .number = 3 }, result.value);
    }

    // Stream should be closed
    {
        const result = try reader.call_read();
        try testing.expectEqual(true, result.done);
    }
}

test "ReadableStream.fromMockIterator() - empty iterator" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const values = [_]JSValue{};

    var mock = try async_iterator.MockAsyncIterator.init(allocator, &values);
    defer mock.deinit();

    var stream = try ReadableStream.fromMockIterator(allocator, loop.eventLoop(), mock);
    defer stream.deinit();

    var reader = try stream.call_getReader(null);
    defer reader.deinit();

    // Stream should be immediately closed
    const result = try reader.call_read();
    try testing.expectEqual(true, result.done);
}

test "ReadableStream.fromMockIterator() - single value" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const values = [_]JSValue{
        JSValue{ .string = "hello" },
    };

    var mock = try async_iterator.MockAsyncIterator.init(allocator, &values);
    defer mock.deinit();

    var stream = try ReadableStream.fromMockIterator(allocator, loop.eventLoop(), mock);
    defer stream.deinit();

    var reader = try stream.call_getReader(null);
    defer reader.deinit();

    // Read the single value
    {
        const result = try reader.call_read();
        try testing.expectEqual(false, result.done);
        try testing.expectEqualStrings("hello", result.value.string);
    }

    // Stream should be closed
    {
        const result = try reader.call_read();
        try testing.expectEqual(true, result.done);
    }
}

test "ReadableStream.fromMockIterator() - cancel calls iterator.return()" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const values = [_]JSValue{
        JSValue{ .number = 1 },
        JSValue{ .number = 2 },
        JSValue{ .number = 3 },
    };

    var mock = try async_iterator.MockAsyncIterator.init(allocator, &values);
    defer mock.deinit();

    var stream = try ReadableStream.fromMockIterator(allocator, loop.eventLoop(), mock);
    defer stream.deinit();

    var reader = try stream.call_getReader(null);
    defer reader.deinit();

    // Read first value
    _ = try reader.call_read();

    // Cancel the stream
    const cancelPromise = try stream.cancelInternal(null);
    try testing.expectEqual(.fulfilled, cancelPromise.state);

    // Iterator should be marked as done
    try testing.expectEqual(values.len, mock.index);
}

test "ReadableStream.fromMockIterator() - stream state lifecycle" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const values = [_]JSValue{
        JSValue{ .number = 1 },
    };

    var mock = try async_iterator.MockAsyncIterator.init(allocator, &values);
    defer mock.deinit();

    var stream = try ReadableStream.fromMockIterator(allocator, loop.eventLoop(), mock);
    defer stream.deinit();

    // Initially readable
    try testing.expectEqual(.readable, stream.state);
    try testing.expectEqual(false, stream.disturbed);

    var reader = try stream.call_getReader(null);
    defer reader.deinit();

    // Disturbed after getting reader
    try testing.expectEqual(true, stream.disturbed);

    // Read value
    _ = try reader.call_read();

    // Read done
    _ = try reader.call_read();

    // Stream is closed
    try testing.expectEqual(.closed, stream.state);
}
