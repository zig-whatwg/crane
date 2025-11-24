//! End-to-End Tests for BYOB (Bring-Your-Own-Buffer) Streams
//!
//! Tests the complete BYOB stream flow including:
//! - ReadableByteStreamController with V8 context
//! - Promise chaining for pull algorithms
//! - View construction for read fulfillment
//! - Event loop integration
//!
//! Spec: https://streams.spec.whatwg.org/#byob-readers

const std = @import("std");
const testing = std.testing;

// Import stream infrastructure
const streams_common = @import("streams_common");
const JSValue = streams_common.JSValue;
const Promise = streams_common.Promise;
const PullAlgorithm = streams_common.PullAlgorithm;
const CancelAlgorithm = streams_common.CancelAlgorithm;

const PullIntoDescriptorModule = @import("streams_pull_into_descriptor");
const PullIntoDescriptor = PullIntoDescriptorModule.PullIntoDescriptor;
const ArrayBuffer = PullIntoDescriptorModule.ArrayBuffer;
const ViewConstructor = PullIntoDescriptorModule.ViewConstructor;
const ReaderType = PullIntoDescriptorModule.ReaderType;

const ReadIntoRequestModule = @import("streams_read_into_request");
const ReadIntoRequest = ReadIntoRequestModule.ReadIntoRequest;

const event_loop = @import("streams_event_loop");
const TestEventLoop = @import("streams_test_event_loop").TestEventLoop;
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

// ============================================================================
// ArrayBuffer Tests
// ============================================================================

test "ArrayBuffer - basic initialization" {
    const allocator = testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 1024);
    defer buffer.deinit(allocator);

    try testing.expectEqual(@as(usize, 1024), buffer.byte_length);
    try testing.expect(!buffer.detached);
    try testing.expect(buffer.data.len == 1024);
}

test "ArrayBuffer - write and read data" {
    const allocator = testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 256);
    defer buffer.deinit(allocator);

    // Write test data
    for (buffer.data, 0..) |*byte, i| {
        byte.* = @intCast(i % 256);
    }

    // Verify data
    for (buffer.data, 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @intCast(i % 256)), byte);
    }
}

test "ArrayBuffer - transfer detaches original" {
    const allocator = testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 512);

    // Write some data
    @memset(buffer.data, 0xAB);

    // Transfer
    var transferred = try buffer.transfer();
    defer transferred.deinit(allocator);

    // Original should be detached
    try testing.expect(buffer.detached);
    try testing.expectEqual(@as(usize, 0), buffer.byte_length);

    // Transferred should have the data
    try testing.expect(!transferred.detached);
    try testing.expectEqual(@as(usize, 512), transferred.byte_length);
    try testing.expectEqual(@as(u8, 0xAB), transferred.data[0]);
}

// ============================================================================
// PullIntoDescriptor Tests
// ============================================================================

test "PullIntoDescriptor - initialization and state" {
    const allocator = testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 1024);
    defer buffer.deinit(allocator);

    const descriptor = PullIntoDescriptor.init(
        &buffer,
        1024,
        0,
        1024,
        256, // minimum fill
        1, // element size (Uint8Array)
        .uint8_array,
        .byob,
    );

    try testing.expectEqual(@as(u64, 1024), descriptor.buffer_byte_length);
    try testing.expectEqual(@as(u64, 0), descriptor.byte_offset);
    try testing.expectEqual(@as(u64, 1024), descriptor.byte_length);
    try testing.expectEqual(@as(u64, 0), descriptor.bytes_filled);
    try testing.expectEqual(@as(u64, 256), descriptor.minimum_fill);
    try testing.expectEqual(@as(u64, 1), descriptor.element_size);
    try testing.expectEqual(ViewConstructor.uint8_array, descriptor.view_constructor);
    try testing.expectEqual(ReaderType.byob, descriptor.reader_type);
}

test "PullIntoDescriptor - fill progress tracking" {
    const allocator = testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 1024);
    defer buffer.deinit(allocator);

    var descriptor = PullIntoDescriptor.init(
        &buffer,
        1024,
        0,
        1024,
        512, // minimum fill
        1,
        .uint8_array,
        .byob,
    );

    // Initially empty
    try testing.expect(!descriptor.isMinimumFillMet());
    try testing.expect(!descriptor.isFilled());
    try testing.expectEqual(@as(u64, 1024), descriptor.remainingBytes());

    // Partial fill (below minimum)
    descriptor.bytes_filled = 256;
    try testing.expect(!descriptor.isMinimumFillMet());
    try testing.expect(!descriptor.isFilled());
    try testing.expectEqual(@as(u64, 768), descriptor.remainingBytes());

    // At minimum fill
    descriptor.bytes_filled = 512;
    try testing.expect(descriptor.isMinimumFillMet());
    try testing.expect(!descriptor.isFilled());
    try testing.expectEqual(@as(u64, 512), descriptor.remainingBytes());

    // Completely filled
    descriptor.bytes_filled = 1024;
    try testing.expect(descriptor.isMinimumFillMet());
    try testing.expect(descriptor.isFilled());
    try testing.expectEqual(@as(u64, 0), descriptor.remainingBytes());
}

test "PullIntoDescriptor - element sizes for TypedArray types" {
    // Verify element sizes match JavaScript TypedArray specs
    try testing.expectEqual(@as(u64, 1), PullIntoDescriptor.getElementSize(.uint8_array));
    try testing.expectEqual(@as(u64, 1), PullIntoDescriptor.getElementSize(.int8_array));
    try testing.expectEqual(@as(u64, 2), PullIntoDescriptor.getElementSize(.uint16_array));
    try testing.expectEqual(@as(u64, 2), PullIntoDescriptor.getElementSize(.int16_array));
    try testing.expectEqual(@as(u64, 4), PullIntoDescriptor.getElementSize(.uint32_array));
    try testing.expectEqual(@as(u64, 4), PullIntoDescriptor.getElementSize(.int32_array));
    try testing.expectEqual(@as(u64, 4), PullIntoDescriptor.getElementSize(.float32_array));
    try testing.expectEqual(@as(u64, 8), PullIntoDescriptor.getElementSize(.float64_array));
    try testing.expectEqual(@as(u64, 8), PullIntoDescriptor.getElementSize(.bigint64_array));
    try testing.expectEqual(@as(u64, 8), PullIntoDescriptor.getElementSize(.biguint64_array));
    try testing.expectEqual(@as(u64, 1), PullIntoDescriptor.getElementSize(.data_view));
}

// ============================================================================
// ReadIntoRequest Tests
// ============================================================================

test "ReadIntoRequest - callback execution" {
    const allocator = testing.allocator;

    var chunk_received = false;
    var close_received = false;
    var error_received = false;

    const TestContext = struct {
        chunk_flag: *bool,
        close_flag: *bool,
        error_flag: *bool,
    };

    var ctx = TestContext{
        .chunk_flag = &chunk_received,
        .close_flag = &close_received,
        .error_flag = &error_received,
    };

    const chunkSteps = struct {
        fn call(context: ?*anyopaque, _: ReadIntoRequestModule.ArrayBufferView) void {
            const c: *TestContext = @ptrCast(@alignCast(context));
            c.chunk_flag.* = true;
        }
    }.call;

    const closeSteps = struct {
        fn call(context: ?*anyopaque) void {
            const c: *TestContext = @ptrCast(@alignCast(context));
            c.close_flag.* = true;
        }
    }.call;

    const errorSteps = struct {
        fn call(context: ?*anyopaque, _: ReadIntoRequestModule.Value) void {
            const c: *TestContext = @ptrCast(@alignCast(context));
            c.error_flag.* = true;
        }
    }.call;

    const request = ReadIntoRequest.init(
        allocator,
        chunkSteps,
        closeSteps,
        errorSteps,
        @ptrCast(&ctx),
    );

    // Test chunk steps
    var test_data = [_]u8{ 1, 2, 3 };
    const view = ReadIntoRequestModule.ArrayBufferView{
        .data = &test_data,
        .offset = 0,
        .length = 3,
    };
    request.executeChunkSteps(view);
    try testing.expect(chunk_received);
    try testing.expect(!close_received);
    try testing.expect(!error_received);

    // Test close steps
    request.executeCloseSteps();
    try testing.expect(close_received);

    // Test error steps
    request.executeErrorSteps(.undefined);
    try testing.expect(error_received);
}

// ============================================================================
// Event Loop Integration Tests
// ============================================================================

test "TestEventLoop - microtask scheduling" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var executed = false;

    const callback = struct {
        fn call(ctx: ?*anyopaque) void {
            const flag: *bool = @ptrCast(@alignCast(ctx));
            flag.* = true;
        }
    }.call;

    // Queue microtask
    loop.eventLoop().queueMicrotask(.{
        .callback = callback,
        .context = @ptrCast(&executed),
    });

    // Not executed yet
    try testing.expect(!executed);

    // Run microtasks
    loop.eventLoop().runMicrotasks();

    // Now executed
    try testing.expect(executed);
}

test "TestEventLoop - multiple microtasks execute in order" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var order: [3]u8 = .{ 0, 0, 0 };
    var index: usize = 0;

    const Context = struct {
        order: *[3]u8,
        index: *usize,
        value: u8,
    };

    const callback = struct {
        fn call(ctx: ?*anyopaque) void {
            const c: *Context = @ptrCast(@alignCast(ctx));
            c.order[c.index.*] = c.value;
            c.index.* += 1;
        }
    }.call;

    // Queue three microtasks
    var ctx1 = Context{ .order = &order, .index = &index, .value = 1 };
    var ctx2 = Context{ .order = &order, .index = &index, .value = 2 };
    var ctx3 = Context{ .order = &order, .index = &index, .value = 3 };

    loop.eventLoop().queueMicrotask(.{ .callback = callback, .context = @ptrCast(&ctx1) });
    loop.eventLoop().queueMicrotask(.{ .callback = callback, .context = @ptrCast(&ctx2) });
    loop.eventLoop().queueMicrotask(.{ .callback = callback, .context = @ptrCast(&ctx3) });

    // Run all
    loop.eventLoop().runMicrotasks();

    // Verify order
    try testing.expectEqual([3]u8{ 1, 2, 3 }, order);
}

// ============================================================================
// AsyncPromise Tests
// ============================================================================

test "AsyncPromise - basic fulfillment" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const promise = try AsyncPromise(u32).init(allocator, loop.eventLoop());
    defer promise.deinit();

    // Initially pending
    try testing.expect(promise.state == .pending);

    // Fulfill
    promise.fulfill(42);

    // Now fulfilled
    try testing.expect(promise.state == .fulfilled);
    try testing.expectEqual(@as(u32, 42), promise.state.fulfilled);
}

test "AsyncPromise - basic rejection" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const promise = try AsyncPromise(u32).init(allocator, loop.eventLoop());
    defer promise.deinit();

    // Initially pending
    try testing.expect(promise.state == .pending);

    // Reject
    const exception = @import("webidl").errors.Exception{
        .simple = .{ .type = .TypeError, .message = "Test error" },
    };
    promise.reject(exception);

    // Now rejected
    try testing.expect(promise.state == .rejected);
}

// ============================================================================
// Pull Algorithm Tests
// ============================================================================

test "PullAlgorithm - default returns fulfilled promise" {
    const default_pull = streams_common.defaultPullAlgorithm();
    defer default_pull.deinit();

    const result = default_pull.call();

    try testing.expect(result.isFulfilled());
}

test "CancelAlgorithm - default returns fulfilled promise" {
    const default_cancel = streams_common.defaultCancelAlgorithm();
    defer default_cancel.deinit();

    const result = default_cancel.call(null);

    try testing.expect(result.isFulfilled());
}

// ============================================================================
// Integration: Promise Chain Simulation
// ============================================================================

test "Promise chain - simulated pull sequence" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Simulate a pull algorithm that resolves asynchronously
    var pull_count: u32 = 0;

    const promise1 = try AsyncPromise(void).init(allocator, loop.eventLoop());
    defer promise1.deinit();

    // Simulate async pull completion
    const callback = struct {
        fn call(ctx: ?*anyopaque) void {
            const count: *u32 = @ptrCast(@alignCast(ctx));
            count.* += 1;
        }
    }.call;

    loop.eventLoop().queueMicrotask(.{
        .callback = callback,
        .context = @ptrCast(&pull_count),
    });

    // Fulfill promise
    promise1.fulfill({});

    // Run event loop
    loop.eventLoop().runMicrotasks();

    // Pull was counted
    try testing.expectEqual(@as(u32, 1), pull_count);
}
