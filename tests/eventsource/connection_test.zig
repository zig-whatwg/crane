//! HTML 9.2.2–9.2.3 connection state transitions when queued tasks run.
const std = @import("std");
const Connection = @import("eventsource").Connection;

test "connection starts CONNECTING and an announcement opens it" {
    var connection: Connection = .{};
    try std.testing.expectEqual(Connection.State.connecting, connection.state);
    try std.testing.expect(connection.announce());
    try std.testing.expectEqual(Connection.State.open, connection.state);
}

test "reestablishment returns to CONNECTING before error and permits refetch" {
    var connection: Connection = .{};
    _ = connection.announce();
    try std.testing.expect(connection.reestablish());
    try std.testing.expectEqual(Connection.State.connecting, connection.state);
    try std.testing.expect(connection.canReconnect());
}

test "fatal failure closes once and forbids reconnect" {
    var connection: Connection = .{};
    try std.testing.expect(connection.fail());
    try std.testing.expectEqual(Connection.State.closed, connection.state);
    try std.testing.expect(!connection.fail());
    try std.testing.expect(!connection.canReconnect());
}

test "close suppresses pending open, error and reconnect tasks" {
    var connection: Connection = .{};
    connection.close();
    connection.close();
    try std.testing.expectEqual(Connection.State.closed, connection.state);
    try std.testing.expect(!connection.announce());
    try std.testing.expect(!connection.reestablish());
    try std.testing.expect(!connection.fail());
    try std.testing.expect(!connection.canReconnect());
}
