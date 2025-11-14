//! Tests migrated from src/streams/internal/message_port.zig
//! Per WHATWG specifications

const std = @import("std");

const streams = @import("streams");

test "MessagePort - create and entangle" {
    const allocator = std.testing.allocator;

    const ports = try createMessagePortPair(allocator);
    defer ports[0].deinit();
    defer ports[1].deinit();

    try std.testing.expect(ports[0].entangled_port == ports[1]);
    try std.testing.expect(ports[1].entangled_port == ports[0]);
    try std.testing.expectEqual(false, ports[0].closed);
    try std.testing.expectEqual(false, ports[1].closed);
}
test "MessagePort - post and receive message" {
    const allocator = std.testing.allocator;

    const ports = try createMessagePortPair(allocator);
    defer ports[0].deinit();
    defer ports[1].deinit();

    // Enable queue on port2
    ports[1].enableQueue();

    // Set up message handler
    const State = struct {
        var received: bool = false;
        var received_type: []const u8 = undefined;
        var received_value: JSValue = undefined;

        fn handler(port: *MessagePort, msg: *Message) void {
            _ = port;
            received = true;
            received_type = msg.type;
            received_value = msg.value;
        }
    };
    ports[1].onmessage = State.handler;

    // Post message from port1 to port2
    try ports[0].postMessage("chunk", JSValue{ .number = 42 });

    // Message should be received
    try std.testing.expect(State.received);
    try std.testing.expectEqualStrings("chunk", State.received_type);
    try std.testing.expectEqual(JSValue{ .number = 42 }, State.received_value);
}
test "MessagePort - message queuing when disabled" {
    const allocator = std.testing.allocator;

    const ports = try createMessagePortPair(allocator);
    defer ports[0].deinit();
    defer ports[1].deinit();

    // Don't enable queue yet

    // Post message
    try ports[0].postMessage("chunk", JSValue{ .number = 1 });
    try ports[0].postMessage("chunk", JSValue{ .number = 2 });

    // Messages should be queued
    try std.testing.expectEqual(@as(usize, 2), ports[1].message_queue.len);

    // Enable queue and set handler
    const State = struct {
        var count: usize = 0;

        fn handler(port: *MessagePort, msg: *Message) void {
            _ = port;
            _ = msg;
            count += 1;
        }
    };
    ports[1].onmessage = State.handler;
    ports[1].enableQueue();

    // Dispatch queued messages
    try ports[1].dispatchQueuedMessages();

    // Both messages should have been dispatched
    try std.testing.expectEqual(@as(usize, 2), State.count);
    try std.testing.expectEqual(@as(usize, 0), ports[1].message_queue.len);
}
test "MessagePort - disentangle" {
    const allocator = std.testing.allocator;

    const ports = try createMessagePortPair(allocator);
    defer ports[0].deinit();
    defer ports[1].deinit();

    // Disentangle port1
    ports[0].disentangle();

    try std.testing.expect(ports[0].entangled_port == null);
    try std.testing.expect(ports[1].entangled_port == null);

    // Posting should fail
    try std.testing.expectError(error.NotEntangled, ports[0].postMessage("chunk", JSValue.undefined_value()));
}
test "MessagePort - close" {
    const allocator = std.testing.allocator;

    const ports = try createMessagePortPair(allocator);
    defer ports[0].deinit();
    defer ports[1].deinit();

    ports[0].close();

    try std.testing.expect(ports[0].closed);
    try std.testing.expect(ports[0].entangled_port == null);
    try std.testing.expect(ports[1].entangled_port == null);

    // Posting should fail
    try std.testing.expectError(error.PortClosed, ports[0].postMessage("chunk", JSValue.undefined_value()));
}
test "packAndPostMessage - convenience function" {
    const allocator = std.testing.allocator;

    const ports = try createMessagePortPair(allocator);
    defer ports[0].deinit();
    defer ports[1].deinit();

    ports[1].enableQueue();

    const State = struct {
        var received: bool = false;

        fn handler(port: *MessagePort, msg: *Message) void {
            _ = port;
            _ = msg;
            received = true;
        }
    };
    ports[1].onmessage = State.handler;

    try packAndPostMessage(ports[0], "pull", JSValue.undefined_value());

    try std.testing.expect(State.received);
}