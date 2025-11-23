//! Integration tests for complete ReadableStream functional implementation
//!
//! Tests the full stream flow: constructor → enqueue → getReader → read → close
//!
//! Spec: https://streams.spec.whatwg.org/

const std = @import("std");
const testing = std.testing;

// Import required modules
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const event_loop_mod = @import("streams_event_loop");

// Test 1: Create stream → Enqueue data → Get reader → Read data → Close stream
// This tests the complete basic flow of a readable stream with manual enqueuing
test "ReadableStream - complete flow with manual enqueue" {
    const allocator = testing.allocator;

    // Set up runtime context with event loop
    var loop = event_loop_mod.TestEventLoop.init(allocator);
    defer loop.deinit();

    const ctx = runtime.Context{
        .allocator = allocator,
        .event_loop = @ptrCast(&loop),
    };

    // Create empty UnderlyingSource (no callbacks)
    const underlying_source = dictionaries.UnderlyingSource{
        .start = null,
        .pull = null,
        .cancel = null,
        .type = null,
        .autoAllocateChunkSize = null,
    };

    // Create empty QueuingStrategy
    const strategy = dictionaries.QueuingStrategy{
        .highWaterMark = null,
        .size = null,
    };

    // Step 1: Create stream
    const stream = try interfaces.ReadableStream.call_constructor(
        allocator,
        ctx,
        @ptrCast(&underlying_source),
        strategy,
    );
    defer interfaces.ReadableStream.deinit(stream);

    // Verify stream is not locked initially
    const locked_initial = try interfaces.ReadableStream.get_locked(stream);
    try testing.expect(!locked_initial);

    // Step 2: Get controller and enqueue data
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.TestSetupFailed;
    const controller = stream_internal.controller;

    // Enqueue three chunks
    const chunk1: []const u8 = "Hello";
    const chunk2: []const u8 = "World";
    const chunk3: []const u8 = "!";

    try interfaces.ReadableStreamDefaultController.call_enqueue(controller, @ptrCast(chunk1.ptr));
    try interfaces.ReadableStreamDefaultController.call_enqueue(controller, @ptrCast(chunk2.ptr));
    try interfaces.ReadableStreamDefaultController.call_enqueue(controller, @ptrCast(chunk3.ptr));

    // Step 3: Get reader
    const reader_options = dictionaries.ReadableStreamGetReaderOptions{
        .mode = null,
    };

    const reader_opaque = try interfaces.ReadableStream.call_getReader(stream, reader_options);
    const reader: *runtime.Instance = @ptrCast(@alignCast(reader_opaque));

    // Verify stream is now locked
    const locked_after_reader = try interfaces.ReadableStream.get_locked(stream);
    try testing.expect(locked_after_reader);

    // Step 4: Read all three chunks
    // Read chunk 1
    const read1_promise_opaque = try interfaces.ReadableStreamDefaultReader.call_read(reader);
    const read1_promise: *@import("streams_async_promise").AsyncPromise(@import("impls").ReadableStreamDefaultReader.ReadResult) = @ptrCast(@alignCast(read1_promise_opaque));

    // Run event loop to process async operations
    try loop.run();

    // Verify first chunk
    try testing.expect(read1_promise.state == .fulfilled);
    if (read1_promise.state == .fulfilled) {
        const result1 = read1_promise.value;
        try testing.expect(!result1.done);
        try testing.expect(result1.value != null);
    }
    read1_promise.deinit();

    // Read chunk 2
    const read2_promise_opaque = try interfaces.ReadableStreamDefaultReader.call_read(reader);
    const read2_promise: *@import("streams_async_promise").AsyncPromise(@import("impls").ReadableStreamDefaultReader.ReadResult) = @ptrCast(@alignCast(read2_promise_opaque));

    try loop.run();

    try testing.expect(read2_promise.state == .fulfilled);
    if (read2_promise.state == .fulfilled) {
        const result2 = read2_promise.value;
        try testing.expect(!result2.done);
        try testing.expect(result2.value != null);
    }
    read2_promise.deinit();

    // Read chunk 3
    const read3_promise_opaque = try interfaces.ReadableStreamDefaultReader.call_read(reader);
    const read3_promise: *@import("streams_async_promise").AsyncPromise(@import("impls").ReadableStreamDefaultReader.ReadResult) = @ptrCast(@alignCast(read3_promise_opaque));

    try loop.run();

    try testing.expect(read3_promise.state == .fulfilled);
    if (read3_promise.state == .fulfilled) {
        const result3 = read3_promise.value;
        try testing.expect(!result3.done);
        try testing.expect(result3.value != null);
    }
    read3_promise.deinit();

    // Step 5: Close the stream
    try interfaces.ReadableStreamDefaultController.call_close(controller);

    // Read after close should return done
    const read_done_promise_opaque = try interfaces.ReadableStreamDefaultReader.call_read(reader);
    const read_done_promise: *@import("streams_async_promise").AsyncPromise(@import("impls").ReadableStreamDefaultReader.ReadResult) = @ptrCast(@alignCast(read_done_promise_opaque));

    try loop.run();

    try testing.expect(read_done_promise.state == .fulfilled);
    if (read_done_promise.state == .fulfilled) {
        const result_done = read_done_promise.value;
        try testing.expect(result_done.done);
        try testing.expect(result_done.value == null);
    }
    read_done_promise.deinit();

    // Clean up reader
    try interfaces.ReadableStreamDefaultReader.call_releaseLock(reader);
    interfaces.ReadableStreamDefaultReader.deinit(reader);
}

// Test 2: Stream with desiredSize backpressure
test "ReadableStream - desiredSize backpressure signal" {
    const allocator = testing.allocator;

    var loop = event_loop_mod.TestEventLoop.init(allocator);
    defer loop.deinit();

    const ctx = runtime.Context{
        .allocator = allocator,
        .event_loop = @ptrCast(&loop),
    };

    const underlying_source = dictionaries.UnderlyingSource{
        .start = null,
        .pull = null,
        .cancel = null,
        .type = null,
        .autoAllocateChunkSize = null,
    };

    const strategy = dictionaries.QueuingStrategy{
        .highWaterMark = null, // Will default to 1
        .size = null,
    };

    const stream = try interfaces.ReadableStream.call_constructor(
        allocator,
        ctx,
        @ptrCast(&underlying_source),
        strategy,
    );
    defer interfaces.ReadableStream.deinit(stream);

    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.TestSetupFailed;
    const controller = stream_internal.controller;

    // Initially, desiredSize should be 1 (high water mark)
    const desired_size_initial = try interfaces.ReadableStreamDefaultController.get_desiredSize(controller);
    try testing.expectApproxEqAbs(@as(f64, 1.0), desired_size_initial, 0.01);

    // Enqueue one chunk
    const chunk: []const u8 = "data";
    try interfaces.ReadableStreamDefaultController.call_enqueue(controller, @ptrCast(chunk.ptr));

    // After enqueuing (size 1), desiredSize should be 0
    const desired_size_after = try interfaces.ReadableStreamDefaultController.get_desiredSize(controller);
    try testing.expectApproxEqAbs(@as(f64, 0.0), desired_size_after, 0.01);

    // Get reader and read the chunk
    const reader_options = dictionaries.ReadableStreamGetReaderOptions{ .mode = null };
    const reader_opaque = try interfaces.ReadableStream.call_getReader(stream, reader_options);
    const reader: *runtime.Instance = @ptrCast(@alignCast(reader_opaque));

    const read_promise_opaque = try interfaces.ReadableStreamDefaultReader.call_read(reader);
    const read_promise: *@import("streams_async_promise").AsyncPromise(@import("impls").ReadableStreamDefaultReader.ReadResult) = @ptrCast(@alignCast(read_promise_opaque));

    try loop.run();

    try testing.expect(read_promise.state == .fulfilled);
    read_promise.deinit();

    // After reading, desiredSize should be back to 1
    const desired_size_final = try interfaces.ReadableStreamDefaultController.get_desiredSize(controller);
    try testing.expectApproxEqAbs(@as(f64, 1.0), desired_size_final, 0.01);

    // Clean up
    try interfaces.ReadableStreamDefaultReader.call_releaseLock(reader);
    interfaces.ReadableStreamDefaultReader.deinit(reader);
}

// Test 3: Error propagation
test "ReadableStream - error propagation" {
    const allocator = testing.allocator;

    var loop = event_loop_mod.TestEventLoop.init(allocator);
    defer loop.deinit();

    const ctx = runtime.Context{
        .allocator = allocator,
        .event_loop = @ptrCast(&loop),
    };

    const underlying_source = dictionaries.UnderlyingSource{
        .start = null,
        .pull = null,
        .cancel = null,
        .type = null,
        .autoAllocateChunkSize = null,
    };

    const strategy = dictionaries.QueuingStrategy{
        .highWaterMark = null,
        .size = null,
    };

    const stream = try interfaces.ReadableStream.call_constructor(
        allocator,
        ctx,
        @ptrCast(&underlying_source),
        strategy,
    );
    defer interfaces.ReadableStream.deinit(stream);

    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.TestSetupFailed;
    const controller = stream_internal.controller;

    // Get reader before error
    const reader_options = dictionaries.ReadableStreamGetReaderOptions{ .mode = null };
    const reader_opaque = try interfaces.ReadableStream.call_getReader(stream, reader_options);
    const reader: *runtime.Instance = @ptrCast(@alignCast(reader_opaque));

    // Start a read that will be pending
    const read_promise_opaque = try interfaces.ReadableStreamDefaultReader.call_read(reader);
    const read_promise: *@import("streams_async_promise").AsyncPromise(@import("impls").ReadableStreamDefaultReader.ReadResult) = @ptrCast(@alignCast(read_promise_opaque));

    // Error the stream
    const error_reason: []const u8 = "Test error";
    try interfaces.ReadableStreamDefaultController.call_error(controller, @ptrCast(error_reason.ptr));

    // Verify stream is now errored
    try testing.expectEqual(@as(@import("impls").ReadableStream.StreamState, .errored), stream_internal.state);

    // Run event loop - the pending read should be rejected
    try loop.run();

    // Verify the read was rejected
    try testing.expect(read_promise.state == .rejected);
    read_promise.deinit();

    // Subsequent reads should also be rejected
    const read2_promise_opaque = try interfaces.ReadableStreamDefaultReader.call_read(reader);
    const read2_promise: *@import("streams_async_promise").AsyncPromise(@import("impls").ReadableStreamDefaultReader.ReadResult) = @ptrCast(@alignCast(read2_promise_opaque));

    try loop.run();

    try testing.expect(read2_promise.state == .rejected);
    read2_promise.deinit();

    // Clean up
    try interfaces.ReadableStreamDefaultReader.call_releaseLock(reader);
    interfaces.ReadableStreamDefaultReader.deinit(reader);
}

// Test 4: Cancel stream
test "ReadableStream - cancel operation" {
    const allocator = testing.allocator;

    var loop = event_loop_mod.TestEventLoop.init(allocator);
    defer loop.deinit();

    const ctx = runtime.Context{
        .allocator = allocator,
        .event_loop = @ptrCast(&loop),
    };

    const underlying_source = dictionaries.UnderlyingSource{
        .start = null,
        .pull = null,
        .cancel = null,
        .type = null,
        .autoAllocateChunkSize = null,
    };

    const strategy = dictionaries.QueuingStrategy{
        .highWaterMark = null,
        .size = null,
    };

    const stream = try interfaces.ReadableStream.call_constructor(
        allocator,
        ctx,
        @ptrCast(&underlying_source),
        strategy,
    );
    defer interfaces.ReadableStream.deinit(stream);

    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.TestSetupFailed;

    // Verify stream starts readable
    try testing.expectEqual(@as(@import("impls").ReadableStream.StreamState, .readable), stream_internal.state);

    // Cancel the stream
    const cancel_reason: []const u8 = "User cancelled";
    const cancel_promise_opaque = try interfaces.ReadableStream.call_cancel(stream, @ptrCast(cancel_reason.ptr));
    const cancel_promise: *@import("streams_async_promise").AsyncPromise(void) = @ptrCast(@alignCast(cancel_promise_opaque));

    // Run event loop
    try loop.run();

    // Verify cancel succeeded
    try testing.expect(cancel_promise.state == .fulfilled);
    cancel_promise.deinit();

    // Verify stream is now closed
    try testing.expectEqual(@as(@import("impls").ReadableStream.StreamState, .closed), stream_internal.state);

    // Verify stream is disturbed
    try testing.expect(stream_internal.disturbed);
}

// Test 5: Cannot enqueue or close after close requested
test "ReadableStream - cannot enqueue after close" {
    const allocator = testing.allocator;

    var loop = event_loop_mod.TestEventLoop.init(allocator);
    defer loop.deinit();

    const ctx = runtime.Context{
        .allocator = allocator,
        .event_loop = @ptrCast(&loop),
    };

    const underlying_source = dictionaries.UnderlyingSource{
        .start = null,
        .pull = null,
        .cancel = null,
        .type = null,
        .autoAllocateChunkSize = null,
    };

    const strategy = dictionaries.QueuingStrategy{
        .highWaterMark = null,
        .size = null,
    };

    const stream = try interfaces.ReadableStream.call_constructor(
        allocator,
        ctx,
        @ptrCast(&underlying_source),
        strategy,
    );
    defer interfaces.ReadableStream.deinit(stream);

    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.TestSetupFailed;
    const controller = stream_internal.controller;

    // Close the controller
    try interfaces.ReadableStreamDefaultController.call_close(controller);

    // Try to enqueue after close - should fail
    const chunk: []const u8 = "data";
    const enqueue_result = interfaces.ReadableStreamDefaultController.call_enqueue(controller, @ptrCast(chunk.ptr));
    try testing.expectError(error.TypeError, enqueue_result);

    // Try to close again - should fail
    const close_result = interfaces.ReadableStreamDefaultController.call_close(controller);
    try testing.expectError(error.TypeError, close_result);
}
