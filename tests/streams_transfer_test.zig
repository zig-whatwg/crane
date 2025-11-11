//! Tests for ReadableStream and WritableStream transfer/serialization
//!
//! Spec: WHATWG Streams §4.2.5 and §5.2.5 Transfer
//! Tests the [[TransferSteps]] and [[TransferReceivingSteps]] for both stream types

const std = @import("std");
const testing = std.testing;

const streams = @import("streams");
const ReadableStream = streams.ReadableStream;
const WritableStream = streams.WritableStream;
const structured_clone = @import("structured_clone");
const TestEventLoop = @import("test_event_loop").TestEventLoop;

// ============================================================================
// ReadableStream Transfer Tests
// ============================================================================

test "ReadableStream.transferSteps - basic transfer serialization" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var stream = try ReadableStream.init(allocator);
    defer stream.deinit();

    // Transfer should succeed
    const serialized = try stream.transferSteps();
    defer serialized.deinit();

    // Verify we got serialized data
    try testing.expect(serialized.port_id != 0);
}

test "ReadableStream.transferSteps - locked stream throws DataCloneError" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var stream = try ReadableStream.init(allocator);
    defer stream.deinit();

    // Lock the stream by getting a reader
    var reader = try stream.call_getReader(null);
    defer reader.deinit();

    // Transfer should fail with DataCloneError
    try testing.expectError(error.DataCloneError, stream.transferSteps());
}

test "ReadableStream.transferReceivingSteps - deserialize and setup" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create serialized data (simulating received transfer)
    const serialized = try structured_clone.SerializedData.init(allocator, 123);
    defer serialized.deinit();

    var stream = try ReadableStream.init(allocator);
    defer stream.deinit();

    // This should set up the stream to receive from the port
    // Note: Full implementation would connect to the entangled port
    try testing.expectError(
        error.NotImplemented,
        stream.transferReceivingSteps(serialized)
    );
}

// ============================================================================
// WritableStream Transfer Tests
// ============================================================================

test "WritableStream.transferSteps - basic transfer serialization" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var stream = try WritableStream.init(allocator);
    defer stream.deinit();

    // Transfer should succeed
    const serialized = try stream.transferSteps();
    defer serialized.deinit();

    // Verify we got serialized data
    try testing.expect(serialized.port_id != 0);
}

test "WritableStream.transferSteps - locked stream throws DataCloneError" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    var stream = try WritableStream.init(allocator);
    defer stream.deinit();

    // Lock the stream by getting a writer
    var writer = try stream.call_getWriter();
    defer writer.deinit();

    // Transfer should fail with DataCloneError
    try testing.expectError(error.DataCloneError, stream.transferSteps());
}

test "WritableStream.transferReceivingSteps - deserialize and setup" {
    const allocator = testing.allocator;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create serialized data (simulating received transfer)
    const serialized = try structured_clone.SerializedData.init(allocator, 456);
    defer serialized.deinit();

    var stream = try WritableStream.init(allocator);
    defer stream.deinit();

    // This should set up the stream to send to the port
    // Note: Full implementation would connect to the entangled port
    try testing.expectError(
        error.NotImplemented,
        stream.transferReceivingSteps(serialized)
    );
}

// ============================================================================
// Integration Tests (would require full cross-realm setup)
// ============================================================================

// NOTE: Full integration tests would require:
// 1. Complete SetUpCrossRealmTransformReadable/Writable implementations
// 2. MessagePort message handling
// 3. Actual data transfer through ports
// 4. Cross-realm stream coordination
//
// These are marked as future work since they require the full
// cross-realm infrastructure to be connected.

test "transfer integration - placeholder" {
    // Future: Test actual data transfer through transferred streams
    // This would create a stream, transfer it, write to it in one realm,
    // and read from it in another realm
}
