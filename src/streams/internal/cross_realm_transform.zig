//! Cross-realm transform streams for transfer
//!
//! Implements SetUpCrossRealmTransformReadable and SetUpCrossRealmTransformWritable
//! per WHATWG Streams Standard § 4.11.10 and § 4.11.11
//!
//! These functions create streams that communicate across realms via MessagePorts,
//! enabling ReadableStream and WritableStream transfer via postMessage().
//!
//! Spec: https://streams.spec.whatwg.org/#abstract-opdef-setupcrossrealmtransformreadable
//! Spec: https://streams.spec.whatwg.org/#abstract-opdef-setupcrossrealmtransformwritable

const std = @import("std");
const Allocator = std.mem.Allocator;
const common = @import("common");
const message_port = @import("message_port");
const JSValue = common.JSValue;
const MessagePort = message_port.MessagePort;

// Forward declarations - will be resolved at link time
// These reference the actual stream implementations
const ReadableStream = @import("readable_stream").ReadableStream;
const WritableStream = @import("writable_stream").WritableStream;
const ReadableStreamDefaultController = @import("readable_stream_default_controller").ReadableStreamDefaultController;
const WritableStreamDefaultController = @import("writable_stream_default_controller").WritableStreamDefaultController;

/// SetUpCrossRealmTransformReadable(stream, port)
///
/// Spec: § 4.11.10 SetUpCrossRealmTransformReadable
/// https://streams.spec.whatwg.org/#abstract-opdef-setupcrossrealmtransformreadable
///
/// Sets up a ReadableStream that receives chunks from a MessagePort.
/// The port is connected to a cross-realm WritableStream on the other side.
///
/// Message protocol:
/// - {type: "chunk", value: <chunk>} - Enqueue a chunk
/// - {type: "close", value: undefined} - Close the stream
/// - {type: "error", value: <error>} - Error the stream
/// - {type: "pull", value: undefined} - Backpressure signal (stream wants data)
pub fn setupCrossRealmTransformReadable(
    allocator: Allocator,
    stream: *ReadableStream,
    port: *MessagePort,
) !void {
    _ = allocator;
    _ = stream;
    _ = port;

    // TODO: Full implementation requires:
    // 1. InitializeReadableStream(stream)
    // 2. Create ReadableStreamDefaultController
    // 3. Set up message event handler on port
    // 4. Set up messageerror event handler on port
    // 5. Enable port's message queue
    // 6. Define pullAlgorithm that sends "pull" messages
    // 7. Define cancelAlgorithm that sends "error" messages
    // 8. SetUpReadableStreamDefaultController with those algorithms

    return error.NotImplemented;
}

/// SetUpCrossRealmTransformWritable(stream, port)
///
/// Spec: § 4.11.11 SetUpCrossRealmTransformWritable
/// https://streams.spec.whatwg.org/#abstract-opdef-setupcrossrealmtransformwritable
///
/// Sets up a WritableStream that sends chunks to a MessagePort.
/// The port is connected to a cross-realm ReadableStream on the other side.
///
/// Message protocol:
/// - {type: "chunk", value: <chunk>} - Send a chunk
/// - {type: "close", value: undefined} - Signal stream closure
/// - {type: "error", value: <error>} - Signal an error
/// - {type: "pull", value: undefined} - Backpressure signal (reader wants data)
pub fn setupCrossRealmTransformWritable(
    allocator: Allocator,
    stream: *WritableStream,
    port: *MessagePort,
) !void {
    _ = allocator;
    _ = stream;
    _ = port;

    // TODO: Full implementation requires:
    // 1. InitializeWritableStream(stream)
    // 2. Create WritableStreamDefaultController
    // 3. Create backpressure promise
    // 4. Set up message event handler on port (for "pull" and "error")
    // 5. Set up messageerror event handler on port
    // 6. Enable port's message queue
    // 7. Define writeAlgorithm that sends "chunk" messages
    // 8. Define closeAlgorithm that sends "close" messages
    // 9. Define abortAlgorithm that sends "error" messages
    // 10. SetUpWritableStreamDefaultController with those algorithms

    return error.NotImplemented;
}

// ============================================================================
// State Management for Cross-Realm Transforms
// ============================================================================

/// State for a cross-realm readable stream
/// Holds the port and controller references needed for message handling
const CrossRealmReadableState = struct {
    allocator: Allocator,
    controller: *ReadableStreamDefaultController,
    port: *MessagePort,

    pub fn init(
        allocator: Allocator,
        controller: *ReadableStreamDefaultController,
        port: *MessagePort,
    ) !*CrossRealmReadableState {
        const state = try allocator.create(CrossRealmReadableState);
        state.* = .{
            .allocator = allocator,
            .controller = controller,
            .port = port,
        };
        return state;
    }

    pub fn deinit(self: *CrossRealmReadableState) void {
        self.allocator.destroy(self);
    }

    /// Message handler for readable side
    /// Spec: § 4.11.10 step 3
    pub fn handleMessage(port: *MessagePort, msg: *message_port.Message) void {
        _ = port;
        _ = msg;
        // TODO: Handle "chunk", "close", and "error" messages
        // - "chunk": ReadableStreamDefaultControllerEnqueue(controller, value)
        // - "close": ReadableStreamDefaultControllerClose(controller), disentangle port
        // - "error": ReadableStreamDefaultControllerError(controller, value), disentangle port
    }

    /// Pull algorithm for readable side
    /// Spec: § 4.11.10 step 7
    pub fn pullAlgorithm(ctx: *anyopaque) common.Promise(void) {
        const self: *CrossRealmReadableState = @ptrCast(@alignCast(ctx));

        // Send "pull" message to signal backpressure
        message_port.packAndPostMessage(self.port, "pull", JSValue.undefined_value()) catch {
            // If posting fails, return rejected promise
            return common.Promise(void).rejected(JSValue{ .string = "Failed to send pull message" });
        };

        return common.Promise(void).fulfilled({});
    }

    /// Cancel algorithm for readable side
    /// Spec: § 4.11.10 step 8
    pub fn cancelAlgorithm(ctx: *anyopaque, reason: ?JSValue) common.Promise(void) {
        const self: *CrossRealmReadableState = @ptrCast(@alignCast(ctx));

        // Send "error" message with reason
        const error_value = reason orelse JSValue.undefined_value();
        message_port.packAndPostMessageHandlingError(self.port, "error", error_value);

        // Disentangle port
        self.port.disentangle();

        return common.Promise(void).fulfilled({});
    }
};

/// State for a cross-realm writable stream
/// Holds the port, controller, and backpressure promise for message handling
const CrossRealmWritableState = struct {
    allocator: Allocator,
    controller: *WritableStreamDefaultController,
    port: *MessagePort,
    backpressure_promise: ?*common.AsyncPromise(void),

    pub fn init(
        allocator: Allocator,
        controller: *WritableStreamDefaultController,
        port: *MessagePort,
    ) !*CrossRealmWritableState {
        const state = try allocator.create(CrossRealmWritableState);
        state.* = .{
            .allocator = allocator,
            .controller = controller,
            .port = port,
            .backpressure_promise = null,
        };
        return state;
    }

    pub fn deinit(self: *CrossRealmWritableState) void {
        self.allocator.destroy(self);
    }

    /// Message handler for writable side
    /// Spec: § 4.11.11 step 4
    pub fn handleMessage(port: *MessagePort, msg: *message_port.Message) void {
        _ = port;
        _ = msg;
        // TODO: Handle "pull" and "error" messages
        // - "pull": Resolve backpressure promise if set
        // - "error": WritableStreamDefaultControllerErrorIfNeeded(controller, value)
    }

    /// Write algorithm for writable side
    /// Spec: § 4.11.11 step 7
    pub fn writeAlgorithm(ctx: *anyopaque, chunk: JSValue) common.Promise(void) {
        const self: *CrossRealmWritableState = @ptrCast(@alignCast(ctx));

        // Send "chunk" message
        message_port.packAndPostMessage(self.port, "chunk", chunk) catch {
            return common.Promise(void).rejected(JSValue{ .string = "Failed to send chunk" });
        };

        // TODO: Create and return backpressure promise
        // For now, return immediately fulfilled
        return common.Promise(void).fulfilled({});
    }

    /// Close algorithm for writable side
    /// Spec: § 4.11.11 step 8
    pub fn closeAlgorithm(ctx: *anyopaque) common.Promise(void) {
        const self: *CrossRealmWritableState = @ptrCast(@alignCast(ctx));

        // Send "close" message
        message_port.packAndPostMessage(self.port, "close", JSValue.undefined_value()) catch {
            return common.Promise(void).rejected(JSValue{ .string = "Failed to send close" });
        };

        return common.Promise(void).fulfilled({});
    }

    /// Abort algorithm for writable side
    /// Spec: § 4.11.11 step 9
    pub fn abortAlgorithm(ctx: *anyopaque, reason: ?JSValue) common.Promise(void) {
        const self: *CrossRealmWritableState = @ptrCast(@alignCast(ctx));

        // Send "error" message with reason
        const error_value = reason orelse JSValue.undefined_value();
        message_port.packAndPostMessageHandlingError(self.port, "error", error_value);

        return common.Promise(void).fulfilled({});
    }
};

// ============================================================================
// Tests
// ============================================================================

test "CrossRealmReadableState - init and deinit" {
    const allocator = std.testing.allocator;

    // Mock controller (we don't actually use it in this test)
    var mock_controller: ReadableStreamDefaultController = undefined;

    const port = try MessagePort.init(allocator);
    defer port.deinit();

    const state = try CrossRealmReadableState.init(allocator, &mock_controller, port);
    defer state.deinit();

    try std.testing.expect(state.controller == &mock_controller);
    try std.testing.expect(state.port == port);
}

test "CrossRealmWritableState - init and deinit" {
    const allocator = std.testing.allocator;

    // Mock controller
    var mock_controller: WritableStreamDefaultController = undefined;

    const port = try MessagePort.init(allocator);
    defer port.deinit();

    const state = try CrossRealmWritableState.init(allocator, &mock_controller, port);
    defer state.deinit();

    try std.testing.expect(state.controller == &mock_controller);
    try std.testing.expect(state.port == port);
    try std.testing.expect(state.backpressure_promise == null);
}

test "CrossRealmReadableState - pullAlgorithm sends pull message" {
    const allocator = std.testing.allocator;

    var mock_controller: ReadableStreamDefaultController = undefined;

    const ports = try message_port.createMessagePortPair(allocator);
    defer ports[0].deinit();
    defer ports[1].deinit();

    const state = try CrossRealmReadableState.init(allocator, &mock_controller, ports[0]);
    defer state.deinit();

    // Enable queue on receiving port
    ports[1].enableQueue();

    // Set up message handler to verify "pull" was sent
    const TestState = struct {
        var received_pull: bool = false;

        fn handler(port: *MessagePort, msg: *message_port.Message) void {
            _ = port;
            if (std.mem.eql(u8, msg.type, "pull")) {
                received_pull = true;
            }
        }
    };
    ports[1].onmessage = TestState.handler;

    // Call pullAlgorithm
    const promise = CrossRealmReadableState.pullAlgorithm(state);
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expect(TestState.received_pull);
}

test "CrossRealmWritableState - writeAlgorithm sends chunk message" {
    const allocator = std.testing.allocator;

    var mock_controller: WritableStreamDefaultController = undefined;

    const ports = try message_port.createMessagePortPair(allocator);
    defer ports[0].deinit();
    defer ports[1].deinit();

    const state = try CrossRealmWritableState.init(allocator, &mock_controller, ports[0]);
    defer state.deinit();

    // Enable queue on receiving port
    ports[1].enableQueue();

    // Set up message handler to verify "chunk" was sent
    const TestState = struct {
        var received_chunk: bool = false;
        var chunk_value: JSValue = undefined;

        fn handler(port: *MessagePort, msg: *message_port.Message) void {
            _ = port;
            if (std.mem.eql(u8, msg.type, "chunk")) {
                received_chunk = true;
                chunk_value = msg.value;
            }
        }
    };
    ports[1].onmessage = TestState.handler;

    // Call writeAlgorithm
    const chunk = JSValue{ .number = 42 };
    const promise = CrossRealmWritableState.writeAlgorithm(state, chunk);
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expect(TestState.received_chunk);
    try std.testing.expectEqual(JSValue{ .number = 42 }, TestState.chunk_value);
}
