//! Tests for timer warning messages
//!
//! Verifies that time(), timeLog(), and timeEnd() properly warn for errors.

const std = @import("std");
const console_mod = @import("console");
const webidl = @import("webidl");
const infra = @import("infra");

test "time - warns when timer already exists" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.printFn = null;

    const label = try infra.string.utf8ToUtf16(allocator, "duplicate-timer");
    defer allocator.free(label);

    // Start timer first time (should succeed)
    try console_obj.call_time(label);
    try std.testing.expect(console_obj.timerTable.contains(label));

    // Start same timer again (should warn)
    try console_obj.call_time(label);

    // Verify warning was added to message buffer
    try std.testing.expect(console_obj.messageBuffer.size() > 0);

    const last_msg = console_obj.messageBuffer.get(console_obj.messageBuffer.size() - 1).?;
    try std.testing.expect(last_msg.args.len == 1);
    try std.testing.expect(last_msg.args[0] == .string);

    // Warning should mention timer already exists
    const warning = last_msg.args[0].string;
    try std.testing.expect(std.mem.indexOf(u8, warning, "already exists") != null);
    try std.testing.expect(std.mem.indexOf(u8, warning, "duplicate-timer") != null);
}

test "timeLog - warns when timer doesn't exist" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.printFn = null;

    const label = try infra.string.utf8ToUtf16(allocator, "missing-timer");
    defer allocator.free(label);

    // Try to log time for non-existent timer
    try console_obj.call_timeLog(label, &.{});

    // Verify warning was issued
    try std.testing.expect(console_obj.messageBuffer.size() > 0);

    const msg = console_obj.messageBuffer.get(0).?;
    const warning = msg.args[0].string;
    try std.testing.expect(std.mem.indexOf(u8, warning, "does not exist") != null);
    try std.testing.expect(std.mem.indexOf(u8, warning, "missing-timer") != null);
}

test "timeEnd - warns when timer doesn't exist" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.printFn = null;

    const label = try infra.string.utf8ToUtf16(allocator, "nonexistent-timer");
    defer allocator.free(label);

    // Try to end non-existent timer
    try console_obj.call_timeEnd(label);

    // Verify warning was issued
    try std.testing.expect(console_obj.messageBuffer.size() > 0);

    const msg = console_obj.messageBuffer.get(0).?;
    const warning = msg.args[0].string;
    try std.testing.expect(std.mem.indexOf(u8, warning, "does not exist") != null);
    try std.testing.expect(std.mem.indexOf(u8, warning, "nonexistent-timer") != null);
}

test "timeLog - formats duration correctly with data" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.printFn = null;

    const label = try infra.string.utf8ToUtf16(allocator, "test-timer");
    defer allocator.free(label);

    // Start timer
    try console_obj.call_time(label);

    // Sleep briefly (just to have some duration)
    std.time.sleep(1_000_000); // 1ms

    // Log with additional data
    const data = &[_]webidl.JSValue{
        .{ .string = "checkpoint" },
        .{ .number = 42.0 },
    };
    try console_obj.call_timeLog(label, data);

    // Verify message was buffered
    try std.testing.expect(console_obj.messageBuffer.size() > 0);

    const msg = console_obj.messageBuffer.get(0).?;
    // Should have duration + data (1 + 2 = 3 args)
    try std.testing.expectEqual(@as(usize, 3), msg.args.len);

    // First arg should be "label: X.XX ms"
    try std.testing.expect(msg.args[0] == .string);
    const first_arg = msg.args[0].string;
    try std.testing.expect(std.mem.indexOf(u8, first_arg, "test-timer") != null);
    try std.testing.expect(std.mem.indexOf(u8, first_arg, "ms") != null);
}

test "timeEnd - removes timer after logging" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.printFn = null;

    const label = try infra.string.utf8ToUtf16(allocator, "temp-timer");
    defer allocator.free(label);

    // Start and end timer
    try console_obj.call_time(label);
    try std.testing.expect(console_obj.timerTable.contains(label));

    try console_obj.call_timeEnd(label);

    // Verify timer was removed
    try std.testing.expect(!console_obj.timerTable.contains(label));

    // Verify message was logged
    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());
}
